#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <time.h>
#include <dirent.h>

typedef struct {
    unsigned long long total;
    unsigned long long idle;
} CPUStat;

typedef enum {
    GPU_NONE,
    GPU_NVIDIA,
    GPU_SYSFS,
    GPU_XE
} GPUType;

static GPUType gpu_type = GPU_NONE;
static int active_gpu_card_index = -1;

#define XE_MAX_GTS 8
static char xe_gt_idle_path[XE_MAX_GTS][288];
static int xe_gt_count = 0;
static unsigned long long xe_prev_idle_ms[XE_MAX_GTS];
static double xe_prev_sample_time = 0.0;
static int xe_primed = 0;

typedef struct {
    double load;
    double memory_used_gb;
    double temp_c;
    int has_load;
    int has_memory;
    int has_temp;
    const char *label;
} GPUMetrics;

/* ---------------- CPU ---------------- */

static int read_cpu_stat(CPUStat *stat) {
    FILE *fp = fopen("/proc/stat", "r");
    if (!fp) return 0;

    unsigned long long user, nice, system, idle, iowait, irq, softirq, steal;

    if (fscanf(fp, "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
               &user, &nice, &system, &idle, &iowait, &irq, &softirq, &steal) != 8) {
        fclose(fp);
        return 0;
    }
    fclose(fp);

    stat->idle = idle + iowait;
    stat->total = user + nice + system + idle + iowait + irq + softirq + steal;
    return 1;
}

static double calculate_cpu_usage(const CPUStat *old_stat, const CPUStat *new_stat) {
    unsigned long long delta_total = new_stat->total - old_stat->total;
    unsigned long long delta_idle  = new_stat->idle  - old_stat->idle;

    if (delta_total == 0) return 0.0;
    return 100.0 * (1.0 - (double)delta_idle / delta_total);
}

static double get_cpu_clock_ghz() {
    FILE *fp = fopen("/proc/cpuinfo", "r");
    if (!fp) return 0.0;

    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "cpu MHz", 7) == 0) {
            char *colon = strchr(line, ':');
            if (colon) {
                double mhz = atof(colon + 1);
                fclose(fp);
                return mhz / 1000.0;
            }
        }
    }
    fclose(fp);
    return 0.0;
}

static int get_cpu_threads() {
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 0;
}

static int read_double_from_file(const char *path, double *out) {
    FILE *fp = fopen(path, "r");
    if (!fp) return 0;
    int ok = fscanf(fp, "%lf", out) == 1;
    fclose(fp);
    return ok;
}

static int get_cpu_temp(double *temp_c) {
    char path[256], name_path[256], name_buf[64];
    
    for (int hwmon = 0; hwmon < 32; hwmon++) {
        snprintf(name_path, sizeof(name_path), "/sys/class/hwmon/hwmon%d/name", hwmon);
        FILE *fp = fopen(name_path, "r");
        if (!fp) continue;
        
        int read_ok = (fgets(name_buf, sizeof(name_buf), fp) != NULL);
        fclose(fp);
        
        if (read_ok && (strstr(name_buf, "k10temp") || strstr(name_buf, "coretemp") || 
                        strstr(name_buf, "zenpower") || strstr(name_buf, "cpu_thermal"))) {
            snprintf(path, sizeof(path), "/sys/class/hwmon/hwmon%d/temp1_input", hwmon);
            double temp_milli = 0.0;
            if (read_double_from_file(path, &temp_milli)) {
                *temp_c = temp_milli / 1000.0;
                return 1;
            }
        }
    }
    
    char type_path[256], type_buf[64];
    for (int zone = 0; zone < 16; zone++) {
        snprintf(type_path, sizeof(type_path), "/sys/class/thermal/thermal_zone%d/type", zone);
        FILE *fp = fopen(type_path, "r");
        if (!fp) continue;
        
        int read_ok = (fgets(type_buf, sizeof(type_buf), fp) != NULL);
        fclose(fp);
        
        if (read_ok && (strstr(type_buf, "x86_pkg_temp") || strstr(type_buf, "coretemp") || strstr(type_buf, "cpu_thermal"))) {
            snprintf(path, sizeof(path), "/sys/class/thermal/thermal_zone%d/temp", zone);
            double temp_milli = 0.0;
            if (read_double_from_file(path, &temp_milli)) {
                *temp_c = temp_milli / 1000.0;
                return 1;
            }
        }
    }
    return 0;
}

/* ---------------- RAM ---------------- */

static int get_ram_info(double *total_gb, double *used_gb, double *free_gb, double *usage_percent) {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) return 0;

    char key[32], unit[16];
    unsigned long long value, total = 0, available = 0;

    while (fscanf(fp, "%31s %llu %15s\n", key, &value, unit) == 3) {
        if (strcmp(key, "MemTotal:") == 0) total = value;
        else if (strcmp(key, "MemAvailable:") == 0) available = value;
        if (total && available) break;
    }
    fclose(fp);

    if (total == 0) return 0;

    *total_gb = (double)total / 1024.0 / 1024.0;
    *free_gb = (double)available / 1024.0 / 1024.0;
    *used_gb = *total_gb - *free_gb;
    *usage_percent = 100.0 * (1.0 - (double)available / total);
    return 1;
}

/* ---------------- GPU ---------------- */

static double monotonic_seconds() {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0.0;
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static int detect_xe_gts(int card_index) {
    int count = 0;
    for (int tile = 0; tile < 4 && count < XE_MAX_GTS; tile++) {
        for (int gt = 0; gt < 4 && count < XE_MAX_GTS; gt++) {
            char path[288];
            snprintf(path, sizeof(path),
                     "/sys/class/drm/card%d/device/tile%d/gt%d/gtidle/idle_residency_ms",
                     card_index, tile, gt);
            if (access(path, R_OK) == 0) {
                snprintf(xe_gt_idle_path[count], sizeof(xe_gt_idle_path[count]), "%s", path);
                count++;
            }
        }
    }
    return count;
}

static int xe_read_load(double *out) {
    double now = monotonic_seconds();
    unsigned long long idle_ms[XE_MAX_GTS];

    for (int i = 0; i < xe_gt_count; i++) {
        double v = 0.0;
        if (!read_double_from_file(xe_gt_idle_path[i], &v)) return 0;
        idle_ms[i] = (unsigned long long)v;
    }

    if (!xe_primed) {
        memcpy(xe_prev_idle_ms, idle_ms, sizeof(idle_ms[0]) * xe_gt_count);
        xe_prev_sample_time = now;
        xe_primed = 1;
        return 0;
    }

    double wall_s = now - xe_prev_sample_time;
    if (wall_s < 0.05) return 0;

    double busiest = 0.0;
    for (int i = 0; i < xe_gt_count; i++) {
        unsigned long long prev = xe_prev_idle_ms[i];
        if (idle_ms[i] < prev) continue;

        double idle_s = (double)(idle_ms[i] - prev) / 1000.0;
        double busy = (1.0 - idle_s / wall_s) * 100.0;
        if (busy > busiest) busiest = busy;
    }

    memcpy(xe_prev_idle_ms, idle_ms, sizeof(idle_ms[0]) * xe_gt_count);
    xe_prev_sample_time = now;

    if (busiest < 0.0) busiest = 0.0;
    if (busiest > 100.0) busiest = 100.0;
    *out = busiest;
    return 1;
}

static int xe_read_memory_gb(double *out) {
    DIR *proc = opendir("/proc");
    if (!proc) return 0;

    long long seen_ids[4096];
    int seen_count = 0;
    unsigned long long total_kib = 0;
    int found_any = 0;

    struct dirent *pe;
    while ((pe = readdir(proc)) != NULL) {
        if (pe->d_name[0] < '0' || pe->d_name[0] > '9') continue;

        char fdinfo_dir[300];
        snprintf(fdinfo_dir, sizeof(fdinfo_dir), "/proc/%s/fdinfo", pe->d_name);
        DIR *fdd = opendir(fdinfo_dir);
        if (!fdd) continue;

        struct dirent *fe;
        while ((fe = readdir(fdd)) != NULL) {
            if (fe->d_name[0] == '.') continue;

            char fpath[600];
            snprintf(fpath, sizeof(fpath), "%s/%s", fdinfo_dir, fe->d_name);
            FILE *fp = fopen(fpath, "r");
            if (!fp) continue;

            char line[256];
            int is_xe = 0;
            long long client_id = -1;
            unsigned long long resident_kib = 0;

            while (fgets(line, sizeof(line), fp)) {
                if (strncmp(line, "drm-driver:", 11) == 0) {
                    if (strstr(line, "xe")) is_xe = 1;
                    else break;
                } else if (strncmp(line, "drm-client-id:", 14) == 0) {
                    client_id = atoll(line + 14);
                } else if (strncmp(line, "drm-resident-", 13) == 0) {
                    char *colon = strchr(line, ':');
                    if (colon) resident_kib += strtoull(colon + 1, NULL, 10);
                }
            }
            fclose(fp);

            if (!is_xe || client_id < 0) continue;

            int duplicate = 0;
            for (int i = 0; i < seen_count; i++) {
                if (seen_ids[i] == client_id) { duplicate = 1; break; }
            }
            if (duplicate) continue;

            if (seen_count < (int)(sizeof(seen_ids) / sizeof(seen_ids[0]))) {
                seen_ids[seen_count++] = client_id;
            }
            total_kib += resident_kib;
            found_any = 1;
        }
        closedir(fdd);
    }
    closedir(proc);

    if (!found_any) return 0;
    *out = (double)total_kib / 1024.0 / 1024.0;
    return 1;
}

static void detect_gpu() {
    if (access("/usr/bin/nvidia-smi", X_OK) == 0 || access("/bin/nvidia-smi", X_OK) == 0) {
        gpu_type = GPU_NVIDIA;
        return;
    }

    char path[256];
    for (int i = 0; i < 8; i++) {
        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/gpu_busy_percent", i);
        if (access(path, R_OK) == 0) {
            gpu_type = GPU_SYSFS;
            active_gpu_card_index = i;

            char vram_path[256];
            snprintf(vram_path, sizeof(vram_path), "/sys/class/drm/card%d/device/mem_info_vram_used", i);
            if (access(vram_path, R_OK) == 0) {
                break;
            }
        }
    }

    if (gpu_type == GPU_NONE) {
        for (int i = 0; i < 8; i++) {
            int gts = detect_xe_gts(i);
            if (gts > 0) {
                gpu_type = GPU_XE;
                active_gpu_card_index = i;
                xe_gt_count = gts;
                break;
            }
        }
    }
}

static int read_gpu_temp_sysfs(int card_index, double *out) {
    char path[256];
    for (int hw = 0; hw < 8; hw++) {
        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/hwmon/hwmon%d/temp1_input", card_index, hw);
        if (access(path, R_OK) == 0 && read_double_from_file(path, out)) return 1;
    }
    return 0;
}

static GPUMetrics get_gpu_metrics() {
    GPUMetrics m = {0};
    m.label = "GPU";

    if (gpu_type == GPU_NVIDIA) {
        FILE *fp = popen("nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader,nounits | head -n1", "r");
        if (!fp) return m;

        double util = 0.0, mem_mb = 0.0, temp = 0.0;
        int parsed = fscanf(fp, " %lf , %lf , %lf", &util, &mem_mb, &temp);
        pclose(fp);

        m.label = "NVIDIA GPU";
        if (parsed >= 1) { m.load = util; m.has_load = 1; }
        if (parsed >= 2) { m.memory_used_gb = mem_mb / 1024.0; m.has_memory = 1; }
        if (parsed >= 3) { m.temp_c = temp; m.has_temp = 1; }
        return m;
    }

    if (gpu_type == GPU_SYSFS && active_gpu_card_index >= 0) {
        char path[256];
        double val = 0.0;

        m.label = "AMD/Intel GPU";

        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/gpu_busy_percent", active_gpu_card_index);
        if (read_double_from_file(path, &val)) {
            m.load = val;
            m.has_load = 1;
        }

        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/mem_info_vram_used", active_gpu_card_index);
        if (read_double_from_file(path, &val)) {
            m.memory_used_gb = val / (1024.0 * 1024.0 * 1024.0);
            m.has_memory = 1;
        }

        if (read_gpu_temp_sysfs(active_gpu_card_index, &val)) {
            m.temp_c = val / 1000.0;
            m.has_temp = 1;
        }
    }

    if (gpu_type == GPU_XE && active_gpu_card_index >= 0) {
        double val = 0.0;

        m.label = "Intel GPU";

        if (xe_read_load(&val)) {
            m.load = val;
            m.has_load = 1;
        }

        if (xe_read_memory_gb(&val)) {
            m.memory_used_gb = val;
            m.has_memory = 1;
        }
    }

    return m;
}

/* ---------------- JSON OUTPUT ---------------- */

static void print_number_or_null(double value, int has_value, int decimals) {
    if (!has_value || isnan(value) || isinf(value)) {
        printf("null");
    } else {
        if (decimals == 2) printf("%.2f", value);
        else if (decimals == 1) printf("%.1f", value);
        else printf("%.0f", value);
    }
}

static void print_json(double cpu_load, double clock_ghz, int threads, double cpu_temp_c, int has_cpu_temp,
                       double ram_total_gb, double ram_used_gb, double ram_free_gb, double ram_usage,
                       GPUMetrics gpu) {
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    char updated_at[32];
    strftime(updated_at, sizeof(updated_at), "%H:%M:%S", t);

    printf("{");
    printf("\"cpuLoad\":%.1f,", cpu_load);
    printf("\"clockGHz\":%.2f,", clock_ghz);
    printf("\"threads\":%d,", threads);
    printf("\"cpuTempC\":"); print_number_or_null(cpu_temp_c, has_cpu_temp, 1); printf(",");
    
    printf("\"ramTotalGB\":%.2f,", ram_total_gb);
    printf("\"ramUsedGB\":%.2f,", ram_used_gb);
    printf("\"ramFreeGB\":%.2f,", ram_free_gb);
    printf("\"ramUsage\":%.1f,", ram_usage);

    printf("\"gpuLoad\":"); print_number_or_null(gpu.load, gpu.has_load, 1); printf(",");
    printf("\"gpuMemoryUsedGB\":"); print_number_or_null(gpu.memory_used_gb, gpu.has_memory, 2); printf(",");
    printf("\"gpuTempC\":"); print_number_or_null(gpu.temp_c, gpu.has_temp, 1); printf(",");
    printf("\"gpuLabel\":\"%s\",", gpu.label);
    
    printf("\"updatedAt\":\"%s\"", updated_at);
    printf("}\n");
    fflush(stdout);
}

static void collect_and_print(const CPUStat *old_stat, const CPUStat *new_stat) {
    double cpu = calculate_cpu_usage(old_stat, new_stat);
    double clock_ghz = get_cpu_clock_ghz();
    int threads = get_cpu_threads();

    double cpu_temp_c = 0.0;
    int has_cpu_temp = get_cpu_temp(&cpu_temp_c);

    double ram_total_gb = 0.0, ram_used_gb = 0.0, ram_free_gb = 0.0, ram_usage = 0.0;
    get_ram_info(&ram_total_gb, &ram_used_gb, &ram_free_gb, &ram_usage);

    GPUMetrics gpu = get_gpu_metrics();

    print_json(cpu, clock_ghz, threads, cpu_temp_c, has_cpu_temp,
               ram_total_gb, ram_used_gb, ram_free_gb, ram_usage, gpu);
}

/* ---------------- MAIN ---------------- */

int main(int argc, char **argv) {
    int once = (argc > 1 && strcmp(argv[1], "--once") == 0);

    detect_gpu();

    if (gpu_type == GPU_XE) {
        double discard = 0.0;
        xe_read_load(&discard);
    }

    CPUStat old_stat = {0}, new_stat = {0};

    if (!read_cpu_stat(&old_stat)) return 1;

    if (once) {
        usleep(500000);
        if (!read_cpu_stat(&new_stat)) return 1;
        collect_and_print(&old_stat, &new_stat);
        return 0;
    }

    while (1) {
        sleep(5);
        if (!read_cpu_stat(&new_stat)) continue;
        collect_and_print(&old_stat, &new_stat);
        old_stat = new_stat;
    }

    return 0;
}