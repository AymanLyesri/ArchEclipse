# 📋 Clipboard Monitor System

## 🎯 Overview

The clipboard monitor system provides automatic notifications when you copy text or images to your clipboard in Hyprland. This refactored implementation **completely eliminates duplicate notifications** through robust singleton protection.

## 🔧 Architecture

### Components

1. **`clipboard-monitor.sh`** - Core monitor script that shows notifications
2. **`start-clipboard-monitor.sh`** - Singleton launcher with multi-layer protection
3. **`check-clipboard-monitor.sh`** - Health check and diagnostic tool

### How It Works

```
Hyprland Startup (exec.conf)
         ↓
start-clipboard-monitor.sh
         ↓
   [Multi-Layer Protection]
   ├─ Check existing processes
   ├─ Atomic lock acquisition
   ├─ PID file validation
   └─ Race condition prevention
         ↓
   wl-paste --watch
         ↓
clipboard-monitor.sh
         ↓
   notify-send (single notification!)
```

## ✅ Features

### Singleton Protection Layers

1. **Process Detection**: Checks if a managed instance is already running
2. **Atomic Locking**: Uses `mkdir` for atomic lock acquisition
3. **PID Validation**: Verifies running processes against stored PID
4. **Race Prevention**: Verification delays to catch race conditions
5. **Aggressive Cleanup**: Kills all unmanaged wl-paste clipboard processes

### Logging

- **Startup Log**: `/tmp/clipboard-monitor-startup.log` - Shows initialization steps
- **Activity Log**: `/tmp/clip-count.log` - Records clipboard operations
- Both logs are automatically managed and rotated

## 🚀 Usage

### Automatic Startup

The monitor starts automatically when you log in to Hyprland via `configs/exec.conf`:

```bash
exec-once = $scriptsDir/start-clipboard-monitor.sh
```

### Manual Control

**Start/Restart:**
```bash
~/.config/hypr/scripts/start-clipboard-monitor.sh
```

**Check Status:**
```bash
~/.config/hypr/scripts/check-clipboard-monitor.sh
```

**Stop:**
```bash
pkill -f "wl-paste.*clipboard"
rm -f /tmp/clipboard-monitor.pid
rmdir /tmp/clipboard-monitor.lock.d 2>/dev/null
```

## 🔍 Diagnostics

### Health Check Output

```
✅ STATUS: HEALTHY - Exactly 1 process running
```

The check script shows:
- Number of running processes
- PID file status
- Lock directory status
- Recent startup logs
- Recent clipboard activity

### Common Issues

#### Multiple Notifications (SOLVED)

**Symptom**: Notification appears 2-3 times when copying
**Cause**: Multiple wl-paste processes running
**Solution**: 
```bash
pkill -9 -f "wl-paste.*clipboard"
~/.config/hypr/scripts/start-clipboard-monitor.sh
```

#### No Notifications

**Symptom**: Nothing happens when copying
**Cause**: Monitor not running
**Solution**:
```bash
~/.config/hypr/scripts/start-clipboard-monitor.sh
```

Check logs:
```bash
tail -f /tmp/clipboard-monitor-startup.log
```

## 🛠️ Multimonitor Compatibility

The clipboard monitor is **completely independent** of monitor configuration:
- Works with any number of monitors
- No per-monitor instances needed
- Clipboard is managed at the Wayland compositor level
- Hotplug events don't affect the monitor

## 📊 Technical Details

### Protection Against Edge Cases

1. **Boot/Login**: Single instance via `exec-once` in Hyprland config
2. **Manual Restart**: Detects existing managed process and exits gracefully
3. **Crash Recovery**: Stale PID files are detected and cleaned
4. **Race Conditions**: Lock acquisition + verification delays prevent conflicts
5. **Orphaned Processes**: Aggressive cleanup kills unmanaged instances

### File Locations

```
/home/alphonse/.config/hypr/
├── scripts/
│   ├── clipboard-monitor.sh          # Core notification logic
│   ├── start-clipboard-monitor.sh    # Singleton launcher
│   └── check-clipboard-monitor.sh    # Health check tool
├── configs/
│   └── exec.conf                      # Startup configuration
└── CLIPBOARD-MONITOR-README.md       # This file

/tmp/
├── clipboard-monitor.pid             # Current process PID
├── clipboard-monitor.lock.d/         # Atomic lock directory
├── clipboard-monitor-startup.log     # Initialization log
└── clip-count.log                    # Activity log
```

## 🔄 Migration from Old System

### What Changed

**Before** (MULTIPLE IMPLEMENTATIONS):
- Inline bash commands in exec.conf
- Lock file mechanism (insufficient)
- PID file check (incomplete)
- Multiple partial fixes across commits

**After** (UNIFIED SYSTEM):
- Single entry point: `start-clipboard-monitor.sh`
- Multi-layer protection
- Comprehensive logging
- Health check tooling

### Clean Slate

All previous partial fixes have been removed. The system now has:
- ✅ One script to start
- ✅ One entry point in config
- ✅ One running process
- ✅ Zero duplicate notifications

## 🎉 Benefits

1. **No More Duplicates**: Guaranteed single notification per copy
2. **Reliable Startup**: Works correctly on every boot/login
3. **Easy Debugging**: Clear logs and status checking
4. **Maintainable**: Simple, well-documented architecture
5. **Robust**: Handles edge cases and race conditions

## 📝 Maintenance

### Logs Cleanup

Logs are automatically overwritten on each startup. Manual cleanup:
```bash
rm /tmp/clipboard-monitor-*.log /tmp/clip-count.log
```

### Verification After Updates

After system updates or Hyprland restarts:
```bash
~/.config/hypr/scripts/check-clipboard-monitor.sh
```

Should show: `✅ STATUS: HEALTHY - Exactly 1 process running`

---

**Last Updated**: 2025-10-01  
**Status**: Production Ready ✅  
**Bug**: Duplicate Notifications - **RESOLVED** ✅
