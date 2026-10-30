// sysmonitor.rs — merged system-resources + bandwidth monitor (replaces the two C loops): one
// std-only binary streaming `SYS {...}` every 5s and `BW [...]` every 3s, byte-compatible.

use std::fs;
use std::io::Write;
use std::process::Command;
use std::time::{Duration, Instant};

const SYS_INTERVAL: Duration = Duration::from_secs(5);
const SYS_FIRST_DELAY: Duration = Duration::from_millis(300);
const BW_INTERVAL: Duration = Duration::from_secs(3);
const BW_PERSIST_SECS: f64 = 30.0;
const MAX_GPUS: usize = 8;

// ---------------- small helpers ----------------

fn read_file(path: &str) -> Option<String> {
    fs::read_to_string(path).ok()
}

fn read_f64(path: &str) -> Option<f64> {
    read_file(path)?.trim().parse::<f64>().ok()
}

// ---------------- CPU ----------------

#[derive(Clone, Copy, Default)]
struct CpuStat {
    total: u64,
    idle: u64,
}

fn read_cpu_stat() -> Option<CpuStat> {
    let text = read_file("/proc/stat")?;
    let mut it = text
        .strip_prefix("cpu")?
        .split_whitespace()
        .filter_map(|w| w.parse::<u64>().ok());
    let (user, nice, system, idle, iowait, irq, softirq, steal) = (
        it.next()?,
        it.next()?,
        it.next()?,
        it.next()?,
        it.next()?,
        it.next()?,
        it.next()?,
        it.next()?,
    );
    Some(CpuStat {
        idle: idle.saturating_add(iowait),
        total: user
            .saturating_add(nice)
            .saturating_add(system)
            .saturating_add(idle)
            .saturating_add(iowait)
            .saturating_add(irq)
            .saturating_add(softirq)
            .saturating_add(steal),
    })
}

fn cpu_usage(old: CpuStat, new: CpuStat) -> f64 {
    let dt = new.total.saturating_sub(old.total);
    if dt == 0 {
        return 0.0;
    }
    100.0 * (1.0 - new.idle.saturating_sub(old.idle) as f64 / dt as f64)
}

fn cpu_clock_ghz() -> f64 {
    let text = match read_file("/proc/cpuinfo") {
        Some(t) => t,
        None => return 0.0,
    };
    for line in text.lines() {
        if line.starts_with("cpu MHz") {
            if let Some(colon) = line.find(':') {
                if let Ok(mhz) = line[colon + 1..].trim().parse::<f64>() {
                    return mhz / 1000.0;
                }
            }
        }
    }
    0.0
}

fn cpu_threads() -> u32 {
    std::thread::available_parallelism()
        .map(|n| n.get() as u32)
        .unwrap_or(0)
}

// Keep JSON-safe: drop quotes, backslashes and control chars; trim.
fn sanitize_label(src: &str) -> String {
    let mut out = String::with_capacity(src.len());
    for c in src.trim().chars() {
        if c == '"' || c == '\\' || c.is_control() {
            continue;
        }
        out.push(c);
    }
    out.trim().to_string()
}

fn collapse_spaces(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut sp = false;
    for c in s.chars() {
        if c == ' ' {
            if !sp && !out.is_empty() {
                out.push(' ');
                sp = true;
            }
        } else {
            out.push(c);
            sp = false;
        }
    }
    out.trim_end().to_string()
}

// Strip Intel (R)/(TM) markers (any case).
fn strip_tm_marks(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = String::with_capacity(s.len());
    let mut i = 0;
    while i < b.len() {
        let rest = &b[i..];
        if rest.len() >= 3
            && rest[0] == b'('
            && (rest[1] == b'R' || rest[1] == b'r')
            && rest[2] == b')'
        {
            i += 3;
            continue;
        }
        if rest.len() >= 4
            && rest[0] == b'('
            && (rest[1] == b'T' || rest[1] == b't')
            && (rest[2] == b'M' || rest[2] == b'm')
            && rest[3] == b')'
        {
            i += 4;
            continue;
        }
        // Advance by one char (labels are sanitized ASCII-ish; fall back
        // to byte copy for anything unexpected).
        let ch_len = s[i..].chars().next().map(|c| c.len_utf8()).unwrap_or(1);
        out.push_str(&s[i..i + ch_len]);
        i += ch_len;
    }
    out
}

// "AMD Ryzen 5 5600 6-Core Processor" -> "Ryzen 5 5600"
// "Intel(R) Core(TM) i5-12400F" -> "Core i5-12400F"
fn shorten_cpu_label(label: &str) -> String {
    const PREFIXES: &[&str] = &["AMD ", "Intel(R) ", "Intel ", "GenuineIntel ", "AuthenticAMD "];
    let mut s = strip_tm_marks(label);
    loop {
        let mut changed = false;
        for p in PREFIXES {
            if let Some(rest) = s.strip_prefix(p) {
                s = rest.to_string();
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
    if let Some(idx) = s.find(" CPU @ ") {
        s.truncate(idx);
    } else if let Some(idx) = s.find(" @ ") {
        s.truncate(idx);
    }
    for suffix in [" Processor", " CPU"] {
        if s.len() > suffix.len() + 6 && s.ends_with(suffix) {
            s.truncate(s.len() - suffix.len());
        }
    }
    // Trailing " N-Core" / " NN-Core" / " N-Thread".
    if let Some(sp) = s.rfind(' ') {
        let tail = &s[sp + 1..];
        let digits = tail.chars().take_while(|c| c.is_ascii_digit()).count();
        if digits > 0 {
            let rest = &tail[digits..];
            if rest == "-Core" || rest == "-Thread" {
                s.truncate(sp);
            }
        }
    }
    collapse_spaces(&s)
}

fn cpu_label() -> String {
    let mut raw = String::new();
    if let Some(text) = read_file("/proc/cpuinfo") {
        for line in text.lines() {
            if line.starts_with("model name") {
                if let Some(colon) = line.find(':') {
                    raw = sanitize_label(&line[colon + 1..]);
                    break;
                }
            }
        }
        // ARM / some SoCs expose Hardware instead of model name.
        if raw.is_empty() {
            for line in text.lines() {
                if line.starts_with("Hardware") {
                    if let Some(colon) = line.find(':') {
                        raw = sanitize_label(&line[colon + 1..]);
                        break;
                    }
                }
            }
        }
    }
    if raw.is_empty() {
        return "CPU".to_string();
    }
    let short = shorten_cpu_label(&raw);
    if short.is_empty() {
        "CPU".to_string()
    } else {
        short
    }
}

fn cpu_temp_c() -> Option<f64> {
    const NAMES: &[&str] = &["k10temp", "coretemp", "zenpower", "cpu_thermal"];
    for hwmon in 0..32 {
        let name_path = format!("/sys/class/hwmon/hwmon{}/name", hwmon);
        if let Some(name) = read_file(&name_path) {
            if NAMES.iter().any(|n| name.contains(n)) {
                let path = format!("/sys/class/hwmon/hwmon{}/temp1_input", hwmon);
                if let Some(milli) = read_f64(&path) {
                    return Some(milli / 1000.0);
                }
            }
        }
    }
    const TYPES: &[&str] = &["x86_pkg_temp", "coretemp", "cpu_thermal"];
    for zone in 0..16 {
        let type_path = format!("/sys/class/thermal/thermal_zone{}/type", zone);
        if let Some(typ) = read_file(&type_path) {
            if TYPES.iter().any(|n| typ.contains(n)) {
                let path = format!("/sys/class/thermal/thermal_zone{}/temp", zone);
                if let Some(milli) = read_f64(&path) {
                    return Some(milli / 1000.0);
                }
            }
        }
    }
    None
}

// ---------------- RAM ----------------

fn ram_info() -> (f64, f64, f64, f64) {
    let (mut total, mut avail) = (0u64, 0u64);
    if let Some(text) = read_file("/proc/meminfo") {
        for line in text.lines() {
            let mut w = line.split_whitespace();
            match (w.next(), w.next()) {
                (Some("MemTotal:"), Some(v)) => total = v.parse().unwrap_or(0),
                (Some("MemAvailable:"), Some(v)) => avail = v.parse().unwrap_or(0),
                _ => {}
            }
            if total > 0 && avail > 0 {
                break;
            }
        }
    }
    if total == 0 {
        return (0.0, 0.0, 0.0, 0.0);
    }
    let total_gb = total as f64 / 1024.0 / 1024.0;
    let free_gb = avail as f64 / 1024.0 / 1024.0;
    (total_gb, total_gb - free_gb, free_gb, 100.0 * (1.0 - avail as f64 / total as f64))
}

// ---------------- GPU ----------------

#[derive(Default)]
struct GpuInfo {
    label: String,
    driver: String,
    load: Option<f64>,
    mem_used_gb: Option<f64>,
    mem_total_gb: Option<f64>,
    temp_c: Option<f64>,
}

fn nvidia_present() -> bool {
    for p in ["/usr/bin/nvidia-smi", "/bin/nvidia-smi"] {
        if let Ok(md) = fs::metadata(p) {
            if !md.permissions().readonly() {
                // metadata alone can't prove +x; try access via Command probe.
            }
        }
        // std has no access(2); spawn `test -x` (once at boot only).
        if Command::new("test").arg("-x").arg(p).status().map(|s| s.success()).unwrap_or(false) {
            return true;
        }
    }
    false
}

fn sysfs_cards() -> Vec<u32> {
    let mut cards = Vec::new();
    for i in 0..8u32 {
        if cards.len() >= MAX_GPUS {
            break;
        }
        let path = format!("/sys/class/drm/card{}/device/gpu_busy_percent", i);
        if fs::metadata(&path).is_ok() {
            cards.push(i);
        }
    }
    cards
}

fn uevent_driver(card: u32) -> Option<String> {
    let text = read_file(&format!("/sys/class/drm/card{}/device/uevent", card))?;
    for line in text.lines() {
        if let Some(driver) = line.strip_prefix("DRIVER=") {
            return Some(driver.trim().to_string());
        }
    }
    None
}

// "NVIDIA GeForce RTX 4080" -> "RTX 4080" (vendor lives in driver).
fn shorten_gpu_label(label: &str) -> String {
    const PREFIXES: &[&str] = &["NVIDIA ", "GeForce ", "AMD ", "Intel(R) ", "Intel ", "Radeon(TM) "];
    let mut s = label.to_string();
    loop {
        let mut changed = false;
        for p in PREFIXES {
            if let Some(rest) = s.strip_prefix(p) {
                s = rest.to_string();
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
    s
}

fn collect_nvidia(gpus: &mut Vec<GpuInfo>) {
    let out = match Command::new("nvidia-smi")
        .args([
            "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu",
            "--format=csv,noheader,nounits",
        ])
        .output()
    {
        Ok(o) if o.status.success() => o,
        _ => return,
    };
    let text = String::from_utf8_lossy(&out.stdout);
    for line in text.lines() {
        if gpus.len() >= MAX_GPUS {
            break;
        }
        let fields: Vec<&str> = line.splitn(5, ',').collect();
        if fields.is_empty() {
            continue;
        }
        let mut g = GpuInfo::default();
        g.label = shorten_gpu_label(&sanitize_label(fields[0]));
        let metric = |i: usize| {
            fields
                .get(i)
                .and_then(|f| f.trim().parse::<f64>().ok())
        };
        g.load = metric(1);
        g.mem_used_gb = metric(2).map(|v| v / 1024.0);
        g.mem_total_gb = metric(3).map(|v| v / 1024.0);
        g.temp_c = metric(4);
        // Same gate as the C loop: unnamed or load-less rows are dropped.
        if g.label.is_empty() || g.load.is_none() {
            continue;
        }
        g.driver = "nvidia".to_string();
        gpus.push(g);
    }
}

fn gpu_temp_sysfs(card: u32) -> Option<f64> {
    for hw in 0..8u32 {
        let path = format!("/sys/class/drm/card{}/device/hwmon/hwmon{}/temp1_input", card, hw);
        if let Some(milli) = read_f64(&path) {
            return Some(milli);
        }
    }
    None
}

fn collect_sysfs(gpus: &mut Vec<GpuInfo>, cards: &[u32]) {
    for &card in cards {
        if gpus.len() >= MAX_GPUS {
            break;
        }
        let mut g = GpuInfo::default();
        g.driver = uevent_driver(card).unwrap_or_else(|| "unknown".to_string());
        g.label = match g.driver.as_str() {
            "amdgpu" | "radeon" => "AMD GPU".to_string(),
            "i915" | "xe" => "Intel GPU".to_string(),
            _ => "GPU".to_string(),
        };
        let base = format!("/sys/class/drm/card{}/device", card);
        g.load = read_f64(&format!("{}/gpu_busy_percent", base));
        g.mem_used_gb = read_f64(&format!("{}/mem_info_vram_used", base)).map(|v| v / 1024.0 / 1024.0 / 1024.0);
        g.mem_total_gb = read_f64(&format!("{}/mem_info_vram_total", base)).map(|v| v / 1024.0 / 1024.0 / 1024.0);
        g.temp_c = gpu_temp_sysfs(card).map(|v| v / 1000.0);
        gpus.push(g);
    }
}

// std has no localtime; one `date` call per SYS tick (5s) keeps HH:MM:SS
// identical to the C loop (same libc/TZ rules) for a negligible spawn.
fn updated_at() -> String {
    Command::new("date")
        .arg("+%H:%M:%S")
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_default()
}

fn opt1(v: Option<f64>) -> String {
    match v {
        Some(x) if x.is_finite() => format!("{:.1}", x),
        _ => "null".to_string(),
    }
}

fn opt2(v: Option<f64>) -> String {
    match v {
        Some(x) if x.is_finite() => format!("{:.2}", x),
        _ => "null".to_string(),
    }
}

fn print_sys(old: CpuStat, new: CpuStat, label: &str, has_nvidia: bool, cards: &[u32]) {
    let cpu = cpu_usage(old, new);
    let clock = cpu_clock_ghz();
    let threads = cpu_threads();
    let temp = cpu_temp_c();
    let (ram_total, ram_used, ram_free, ram_usage) = ram_info();
    let mut gpus = Vec::new();
    if has_nvidia {
        collect_nvidia(&mut gpus);
    }
    collect_sysfs(&mut gpus, cards);
    let mut gpu_json = String::new();
    for (i, g) in gpus.iter().enumerate() {
        if i > 0 {
            gpu_json.push(',');
        }
        gpu_json.push_str(&format!(
            "{{\"label\":\"{}\",\"driver\":\"{}\",\"load\":{},\"memoryUsedGB\":{},\"memoryTotalGB\":{},\"tempC\":{}}}",
            g.label,
            g.driver,
            opt1(g.load),
            opt2(g.mem_used_gb),
            opt2(g.mem_total_gb),
            opt1(g.temp_c)
        ));
    }
    println!(
        "SYS {{\"cpuLabel\":\"{}\",\"cpuLoad\":{:.1},\"clockGHz\":{:.2},\"threads\":{},\"cpuTempC\":{},\"ramTotalGB\":{:.2},\"ramUsedGB\":{:.2},\"ramFreeGB\":{:.2},\"ramUsage\":{:.1},\"gpus\":[{}],\"updatedAt\":\"{}\"}}",
        label,
        cpu,
        clock,
        threads,
        opt1(temp),
        ram_total,
        ram_used,
        ram_free,
        ram_usage,
        gpu_json,
        updated_at()
    );
}

// ---------------- bandwidth ----------------

fn default_iface() -> Option<String> {
    let text = read_file("/proc/net/route")?;
    for line in text.lines().skip(1) {
        let mut w = line.split_whitespace();
        if let (Some(iface), Some(dest)) = (w.next(), w.next()) {
            if u32::from_str_radix(dest, 16).ok() == Some(0) {
                return Some(iface.to_string());
            }
        }
    }
    None
}

fn iface_bytes(iface: &str) -> Option<(u64, u64)> {
    let text = read_file("/proc/net/dev")?;
    for line in text.lines().skip(2) {
        let colon = line.find(':')?;
        if line[..colon].trim() != iface {
            continue;
        }
        let nums: Vec<u64> = line[colon + 1..]
            .split_whitespace()
            .filter_map(|w| w.parse().ok())
            .collect();
        if nums.len() >= 9 {
            return Some((nums[0], nums[8]));
        }
        return None;
    }
    None
}

fn today_str() -> String {
    Command::new("date")
        .arg("+%Y-%m-%d")
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_default()
}

fn log_path() -> Option<String> {
    let home = std::env::var("HOME").ok()?;
    Some(format!("{}/.cache/quickshell/logs/bandwidth.log", home))
}

// Returns (today_rx, today_tx) for the current date; missing file => (0,0).
fn read_today(path: &str, today: &str) -> (u64, u64) {
    let text = match read_file(path) {
        Some(t) => t,
        None => return (0, 0),
    };
    for line in text.lines() {
        let mut w = line.split_whitespace();
        if let (Some(date), Some(tx), Some(rx)) = (w.next(), w.next(), w.next()) {
            if date == today {
                return (rx.parse().unwrap_or(0), tx.parse().unwrap_or(0));
            }
        }
    }
    (0, 0)
}

// Rewrite the log keeping other dates, appending "today tx rx" (same
// tmp+rename shape as the C loop). Fatal on IO failure, like the C loop.
fn persist_today(path: &str, today: &str, tx: u64, rx: u64) {
    if let Some(parent) = std::path::Path::new(path).parent() {
        if fs::create_dir_all(parent).is_err() {
            eprintln!("Error: Failed to create log directory");
            std::process::exit(1);
        }
    }
    let tmp = format!("{}.tmp", path);
    let mut out = String::new();
    if let Some(text) = read_file(path) {
        for line in text.lines() {
            if line.split_whitespace().next() != Some(today) {
                out.push_str(line);
                out.push('\n');
            }
        }
    }
    out.push_str(&format!("{} {} {}\n", today, tx, rx));
    if fs::write(&tmp, out).is_err() {
        eprintln!("Error: Failed to create temp file");
        std::process::exit(1);
    }
    if fs::rename(&tmp, path).is_err() {
        let _ = fs::remove_file(&tmp);
        eprintln!("Error: Failed to update log file");
        std::process::exit(1);
    }
}

// ---------------- main ----------------

fn die(msg: &str, code: i32) -> ! {
    eprintln!("Error: {}", msg);
    std::process::exit(code);
}

fn main() {
    let once = std::env::args().nth(1).as_deref() == Some("--once");

    let label = cpu_label();
    let has_nvidia = nvidia_present();
    let cards = sysfs_cards();

    let mut old_cpu = read_cpu_stat().unwrap_or_default();
    let iface = match default_iface() {
        Some(i) => i,
        None => die("No default route found", 1),
    };
    if std::env::var("HOME").is_err() {
        die("HOME environment variable not set", 1);
    }
    let log = log_path().unwrap();
    let today = today_str();
    let (mut today_rx, mut today_tx) = read_today(&log, &today);
    let mut old_bw = match iface_bytes(&iface) {
        Some(b) => b,
        None => die("Unable to open /proc/net/dev", 1),
    };
    let boot = Instant::now();
    let mut last_tick = boot;
    let mut persist_elapsed = 30.0f64;

    if once {
        std::thread::sleep(Duration::from_millis(500));
        let new_cpu = read_cpu_stat().unwrap_or(old_cpu);
        print_sys(old_cpu, new_cpu, &label, has_nvidia, &cards);
        return;
    }

    // Collect+n-print shared by --once and streaming (avoids duplicating
    // the nvidia/sysfs detection, which is boot-only in the C loop too).
    std::thread::sleep(SYS_FIRST_DELAY);

    let mut sys_next = boot + SYS_FIRST_DELAY;
    let mut bw_next = boot + BW_INTERVAL;
    // The C bandwidth loop prints its first line only after one full
    // interval; the sys loop prints right away (short delta window).
    let mut first = true;

    loop {
        let now = Instant::now();
        let mut wait = Duration::from_secs(60);
        if sys_next > now {
            wait = wait.min(sys_next - now);
        }
        if bw_next > now {
            wait = wait.min(bw_next - now);
        }
        if !wait.is_zero() {
            std::thread::sleep(wait);
        }
        let now = Instant::now();

        if now >= sys_next || first {
            first = false;
            match read_cpu_stat() {
                Some(new_cpu) => {
                    print_sys(old_cpu, new_cpu, &label, has_nvidia, &cards);
                    old_cpu = new_cpu;
                }
                None => eprintln!("Warning: /proc/stat unreadable, skipping sample"),
            }
            sys_next = Instant::now() + SYS_INTERVAL;
        }

        if now >= bw_next {
            let t2 = Instant::now();
            let dt = (t2 - last_tick).as_secs_f64();
            last_tick = t2;
            let (rx, tx) = match iface_bytes(&iface) {
                Some(b) => b,
                None => die("Interface not found in /proc/net/dev", 1),
            };
            let d_rx = rx.saturating_sub(old_bw.0);
            let d_tx = tx.saturating_sub(old_bw.1);
            let speed_rx = if dt > 0.0 { (d_rx as f64 / dt) as u64 } else { 0 };
            let speed_tx = if dt > 0.0 { (d_tx as f64 / dt) as u64 } else { 0 };
            today_rx = today_rx.saturating_add(d_rx);
            today_tx = today_tx.saturating_add(d_tx);
            persist_elapsed += dt;
            if persist_elapsed >= BW_PERSIST_SECS {
                persist_today(&log, &today, today_tx, today_rx);
                persist_elapsed = 0.0;
            }
            println!("BW [{},{},{},{}]", speed_tx, speed_rx, today_tx, today_rx);
            let _ = std::io::stdout().flush();
            old_bw = (rx, tx);
            bw_next = Instant::now() + BW_INTERVAL;
        }
    }
}
