# Bugs Fixed (Fork)

This document tracks bugs found and fixed in this fork that may exist in upstream.

## 1. Hyprpaper Memory Leak (Fixed: 2025-01-02)

**Problem:** Each wallpaper change or monitor hotplug event spawned a new `hyprpaper` instance without killing the previous one. This caused:
- Massive VRAM consumption (observed: 15 instances using 3.87 GiB of 4 GiB VRAM)
- System slowdown due to GPU memory exhaustion
- Accumulated zombie processes over time

**Root Cause:**
- `hyprpaper/load.sh` started `hyprpaper &` without killing existing instances
- `hyprpaper/reload.sh` only killed `auto.sh`, not `hyprpaper`

**Files Fixed:**
- `hyprpaper/load.sh`: Added `killall hyprpaper` before starting new instance
- `hyprpaper/reload.sh`: Added `killall hyprpaper` alongside `killall auto.sh`

**Detection:** Run `pgrep -c hyprpaper` - should return `1`. If more, run:
```bash
pkill -9 hyprpaper && ~/.config/hypr/hyprpaper/reload.sh
```

**VRAM Monitoring:**
```bash
# Check VRAM usage (AMD GPU)
cat /sys/class/drm/card1/device/mem_info_vram_used | awk '{printf "%.2f GiB\n", $1/1024/1024/1024}'

# Check total VRAM
cat /sys/class/drm/card1/device/mem_info_vram_total | awk '{printf "%.2f GiB\n", $1/1024/1024/1024}'
```

---

## 2. AGS Multi-Monitor Bar Not Appearing (Fixed: 2026-01-04)

**Problem:** When multiple monitors are connected, AGS only creates bars for the first monitor. The second monitor has no bar even though AGS detects both monitors.

**Symptoms:**
- `hyprctl layers` shows bar only on first monitor (eDP-1)
- AGS log shows "TOTAL MONITORS DETECTED: 2" but only processes first monitor
- Second monitor (DP-3) has no bar layer surface

**Root Causes (3 issues):**

### 2.1 `getMonitorName()` returning undefined for second monitor
- Original code used `monitor.get_model()` + complex hyprctl matching
- GTK4's `Gdk.Monitor.get_connector()` directly returns connector name (eDP-1, DP-3)
- Fix: Use `get_connector()` as primary method with fallback to old method

### 2.2 Errors in first monitor blocking second monitor
- Original code used `.map()` without error handling
- Notification widget errors (`notificationIcon is null`) caused exception
- Exception stopped iteration before processing second monitor
- Fix: Use `.forEach()` with try-catch wrapper

### 2.3 No support for monitor hotplug
- Original code only called `perMonitorDisplay()` once at startup
- Monitors connected after AGS start never got widgets
- Fix: Listen to `notify::monitors` signal and create widgets for new monitors

**Files Fixed:**
- `.config/ags/app.ts`: Added GLib import, monitor tracking Set, error handling, hotplug detection
- `.config/ags/utils/monitor.ts`: Use `get_connector()` as primary method

**Code Changes in `app.ts`:**
```typescript
// Track initialized monitors to avoid duplicates
const initializedMonitors = new Set<string>();

// Process each monitor with error handling
monitors.forEach((monitor) => {
  try {
    createWidgetsForMonitor(monitor);
  } catch (e) {
    print("\t ERROR creating widgets for monitor: " + monitor.get_connector() + " - " + e);
  }
});

// Setup hotplug detection
app.connect("notify::monitors", () => {
  GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
    monitors.forEach((monitor) => createWidgetsForMonitor(monitor));
    return GLib.SOURCE_REMOVE;
  });
});
```

**Code Changes in `utils/monitor.ts`:**
```typescript
export function getMonitorName(display: Gdk.Display, monitor: Gdk.Monitor) {
  // GTK4 provides get_connector() which returns Wayland connector name directly
  const connector = monitor.get_connector();
  if (connector) return connector;

  // Fallback to old method
  const model = monitor.get_model() || monitor.get_description();
  return getConnectorFromHyprland(model as any);
}
```

**Verification:**
```bash
# Check bars on all monitors
hyprctl layers | grep -E "Monitor|bar"

# Should show bar layer for each monitor:
# Monitor eDP-1:
#     Layer ...: namespace: bar
# Monitor DP-3:
#     Layer ...: namespace: bar
```

---

## 3. NotificationIcon Null Reference Error (Fixed: 2026-01-04)

**Problem:** AGS crashes when rendering notifications that have no icon, preventing UserPanel, WallpaperSwitcher, and other widgets from being created.

**Symptoms:**
- `ags toggle user-panel-eDP-1` returns "no window registered with name"
- AGS log shows: `TypeError: can't access property "endsWith", notificationIcon is null`
- UserPanel and WallpaperSwitcher don't appear in widget creation logs
- Only Bar, BarHover, NotificationPopups, and AppLauncher are created

**Root Cause:**
In `Notification.tsx`, the code checked for `.endsWith(".webp")` BEFORE checking if the icon was null:

```typescript
// BROKEN: null check comes AFTER .endsWith() call
const notificationIcon = n.image || n.app_icon || n.desktopEntry;

if (notificationIcon.endsWith(".webp")) {  // <-- Crashes if null
  // ...
}

if (!notificationIcon)  // <-- Too late, already crashed
  return <image class="icon" iconName={"dialog-information-symbolic"} />;
```

**Fix:** Move the null check BEFORE any method calls on the variable:

```typescript
// FIXED: null check comes FIRST
const notificationIcon = n.image || n.app_icon || n.desktopEntry;

if (!notificationIcon)
  return <image class="icon" iconName={"dialog-information-symbolic"} />;

if (notificationIcon.endsWith(".webp")) {  // <-- Safe, notificationIcon is not null
  // ...
}
```

**Files Fixed:**
- `.config/ags/widgets/rightPanel/components/Notification.tsx`

**Verification:**
```bash
# After fix, all widgets should be created:
cat /tmp/ags.log | grep -E "(UserPanel|WallpaperSwitcher):"
# Should show:
#     UserPanel: XX.XXX ms
#     WallpaperSwitcher: XX.XXX ms

# UserPanel toggle should work:
ags toggle user-panel-eDP-1  # No error
```

---

## 4. REAPER XWayland Window Creation Bug (Fixed: 2026-01-07)

**Problem:** REAPER occasionally starts as a zombie process - audio engine runs (microphone feedback works) but GUI window never creates. This is an XWayland timing issue.

**Symptoms:**
- `pgrep reaper` shows process running
- Audio works (mic feedback audible)
- `hyprctl clients | grep -i reaper` shows no window
- Must manually kill and restart REAPER

**Solution:** Custom launcher script with window detection and auto-restart.

**Files Created:**
- `~/.config/hypr/scripts/launch-reaper.sh`

**Script Features:**
1. Kills any existing REAPER zombie processes before launch
2. Monitors for window creation with 5-second timeout
3. Auto-retries up to 3 times if window doesn't appear
4. Sends notification on final failure

**Usage:**
```bash
# Use instead of `reaper` command
~/.config/hypr/scripts/launch-reaper.sh

# Or create desktop entry override
```

**Verification:**
```bash
# Check REAPER window exists
hyprctl clients -j | jq '.[] | select(.class == "REAPER")'
```

**Desktop Entry Override (Optional):**
Create `~/.local/share/applications/reaper.desktop` to override system entry:
```ini
[Desktop Entry]
Name=REAPER
Exec=/home/alphonse/.config/hypr/scripts/launch-reaper.sh
Type=Application
Icon=cockos-reaper
Categories=Audio;AudioVideo;
```
