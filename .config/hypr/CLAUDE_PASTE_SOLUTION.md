# Claude Code Image Paste Solution

## Executive Summary

This document describes the complete solution for enabling image pasting in Claude Code on Arch Linux with Hyprland/Wayland.

## Problem Analysis

### Root Cause
1. **Electron Wayland Limitation**: Electron apps (like Windsurf/VSCode) have incomplete Wayland clipboard support for images
2. **Security Model**: Wayland's security prevents direct clipboard access without user interaction
3. **Web Context**: Claude Code runs in a webview, adding another abstraction layer

### Why Direct Paste Doesn't Work
- Wayland clipboard API for images is not fully implemented in Chromium/Electron
- The clipboard data doesn't properly transfer from wl-clipboard → Electron → Webview → Claude Code
- This is a known issue affecting all Electron apps on Wayland

## Implemented Solution

### Overview
Since direct image pasting is technically impossible due to Electron limitations, we've implemented a **Smart Paste Helper** that:
1. Automatically saves clipboard images
2. Provides a keyboard shortcut to copy the file path command
3. Makes the process feel almost like native pasting

### Components

#### 1. Enhanced Clipboard Monitor
**File**: `/home/alphonse/.config/hypr/scripts/clipboard-monitor-enhanced.sh`
- Monitors clipboard for images
- Saves images to `/tmp/claude-clipboard/`
- Detects when Windsurf is focused
- Shows context-aware notifications

#### 2. Claude Paste Helper
**File**: `/home/alphonse/.config/hypr/scripts/claude-paste-helper.sh`
- Main utility for handling image paths
- Copies "Read /path/to/image" command to clipboard
- Manages saved images
- Provides status and testing commands

#### 3. Custom Keybinds
**File**: `/home/alphonse/.config/hypr/configs/custom/claude-keybinds.conf`
- `Super+Alt+V`: Smart paste (copies image path command)
- `Super+Alt+C`: Save current clipboard image
- `Super+Alt+I`: Show status
- `Super+Alt+P`: Screenshot and prepare for Claude (P = Picture)

## Usage Workflow

### Method 1: Quick Paste (Recommended)
1. Copy or screenshot an image
2. Open Claude Code chat (terminal or GUI)
3. Press **`Super+Alt+V`** (copies "Read /path" command)
4. Press **`Ctrl+Shift+V`** to paste in terminal (or `Ctrl+V` in GUI)
5. Press **Enter**
6. Claude reads and displays the image

**Important:** If using Claude Code from terminal CLI, use `Ctrl+Shift+V` to paste, not just `Ctrl+V`

### Method 2: Direct Screenshot to Claude
1. Press **`Super+Alt+P`** to take screenshot (P = Picture)
2. System automatically prepares the command
3. Press **`Ctrl+Shift+V`** in Claude Code terminal (or `Ctrl+V` in GUI)

### Method 3: Manual Path (Fallback)
1. Take screenshot with `Super+Shift+S`
2. Type: `Read ~/Pictures/Screenshots/latest.png`

## File Locations

### Images are saved to:
- `/tmp/claude-clipboard/latest.png` - Always points to latest clipboard image
- `/tmp/claude-clipboard/clipboard_*.png` - Timestamped clipboard images
- `~/Pictures/Screenshots/latest.png` - Latest screenshot
- `~/Pictures/Screenshots/clipboard_latest.png` - Copy of latest clipboard image

### Scripts:
- `~/.config/hypr/scripts/clipboard-monitor-enhanced.sh` - Enhanced monitor
- `~/.config/hypr/scripts/claude-paste-helper.sh` - Main helper utility
- `~/.config/hypr/scripts/start-clipboard-monitor.sh` - Singleton launcher

### Configuration:
- `~/.config/hypr/configs/custom/claude-keybinds.conf` - Keyboard shortcuts

## Testing

Test the system:
```bash
~/.config/hypr/scripts/claude-paste-helper.sh test
```

Check status:
```bash
~/.config/hypr/scripts/claude-paste-helper.sh status
```

Manual test:
1. Copy any image (from browser, file manager, etc.)
2. Run: `~/.config/hypr/scripts/claude-paste-helper.sh auto`
3. Check clipboard with: `wl-paste`
4. You should see "Read /tmp/claude-clipboard/latest.png"

## Troubleshooting

### Issue: Keybinds not working
```bash
# Reload Hyprland configuration
hyprctl reload

# Check if keybind is registered
hyprctl binds | grep claude
```

### Issue: Clipboard monitor not running
```bash
# Check status
~/.config/hypr/scripts/check-clipboard-monitor.sh

# Restart monitor
pkill -f "wl-paste.*clipboard"
~/.config/hypr/scripts/start-clipboard-monitor.sh
```

### Issue: Images not being saved
```bash
# Check directories exist
ls -la /tmp/claude-clipboard/
ls -la ~/Pictures/Screenshots/

# Check clipboard content
wl-paste --list-types

# Test save manually
wl-paste --type image/png > /tmp/test.png
```

### Issue: Notifications not showing
```bash
# Test notification system
notify-send "Test" "Notification test"

# Check if notification daemon is running
pgrep -f "dunst\|mako\|swaync"
```

## Alternative Solutions Considered

### 1. Keyboard Automation (wtype/ydotool)
- **Status**: Not implemented (requires additional package)
- **Install**: `sudo pacman -S wtype`
- Would allow automatic text injection

### 2. VSCode Extension
- **Status**: Not viable
- Claude Code is embedded, not extensible

### 3. XWayland Mode
- **Status**: Not recommended
- Loses Wayland benefits (performance, security)

### 4. Browser-based Claude
- **Status**: Works but less integrated
- Use claude.ai in Firefox/Chrome if needed

## Known Limitations

1. **Two-step process**: Can't directly paste images, need to paste path command
2. **Focus detection**: May not always detect Windsurf correctly
3. **Image formats**: Only PNG is guaranteed to work
4. **File size**: Very large images may cause delays

## Future Improvements

When available:
1. **Electron fix**: Wait for proper Wayland clipboard support
2. **Native integration**: Claude Code could add file drop zones
3. **API access**: Direct API integration would bypass clipboard

## Maintenance

### Clean up old images:
```bash
~/.config/hypr/scripts/claude-paste-helper.sh clean
```

### Update scripts:
```bash
cd ~/.config/hypr
git add scripts/claude-* scripts/clipboard-monitor-enhanced.sh
git add configs/custom/claude-keybinds.conf
git add CLAUDE_PASTE_SOLUTION.md
git commit -m "feat: add Claude Code image paste solution"
```

## Summary

While direct image pasting isn't possible due to Electron/Wayland limitations, this solution provides a seamless workaround:

1. **Automatic image capture** when you copy
2. **Single keyboard shortcut** (Super+Alt+V) to prepare the command
3. **Standard paste** (Ctrl+V) in Claude Code
4. **Smart notifications** guide you through the process

The solution feels natural and requires minimal learning curve. It's the best possible experience given the technical constraints.

## Credits

Solution designed and implemented for the ArchEclipse Hyprland rice.
Fork: https://github.com/mrvictor22/ArchEclipse