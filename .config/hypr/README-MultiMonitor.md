# Multi-Monitor Support for ArchEclipse Hyprland Rice

## 🖥️ Overview

This branch adds comprehensive multi-monitor support to the ArchEclipse Hyprland configuration, featuring:

- **Automatic device detection** (laptop vs desktop)
- **Intelligent lid handling** for laptops with external monitors
- **Dynamic workspace management** across monitors
- **Easy resolution configuration** for secondary monitors
- **Enhanced keybindings** for multi-monitor workflows

## 🚀 Features

### 🔍 Automatic Detection
- Detects if you're using a laptop or desktop
- Automatically configures monitors on startup
- Handles AC power and lid state detection

### 💻 Laptop-Specific Features
- **Smart lid behavior**: When lid is closed with AC power and external monitor connected:
  - Internal monitor is disabled
  - All workspaces move to external monitor
  - System doesn't suspend
- **Automatic re-enabling** when lid is opened

### ⌨️ Enhanced Keybindings

#### Monitor Management
- `Super + Shift + M`: Open multi-monitor manager (interactive)
- `Super + Ctrl + Shift + M`: Auto-configure monitors
- `Super + Alt + Shift + M`: Redistribute workspaces across monitors
- `Super + Shift + F12`: Show current monitor status
- `Super + Shift + B`: Restart AGS bars for multi-monitor fixes

#### Workspace Movement
- `Super + Alt + →/←` or `Super + Alt + n/h`: Move current workspace to next/previous monitor
- `Super + Shift + Alt + →/←` or `Super + Shift + Alt + n/h`: Move active window to next/previous monitor
- `Super + Ctrl + Alt + →/←` or `Super + Ctrl + Alt + n/h`: Focus next/previous monitor

#### Quick Monitor Setups
- `Super + Shift + I`: Toggle internal monitor on/off
- `Super + Shift + E`: Auto-detect and setup external monitors
- `Super + Shift + P`: Mirror mode (presentation)
- `Super + Shift + X`: Extend mode (default multi-monitor)

#### Advanced Workspace Management
- `Super + Ctrl + Shift + S`: Swap workspaces between monitors
- `Super + grave`: Quick switch between monitors with workspace focus

## 📁 Files Added/Modified

### New Scripts
- `scripts/multi-monitor-manager.sh`: Main multi-monitor management script
- `scripts/lid-handler.sh`: Handles lid events automatically
- `scripts/monitor-setup.sh`: Quick setup script for common scenarios
- `scripts/monitor-hotplug.sh`: Automatic monitor hotplug detection and AGS restart
- `scripts/move-window-monitor.sh`: Dynamic window movement between monitors

### New Configuration Files
- `configs/multi-monitor-keybinds.conf`: All multi-monitor keybindings
- `.config/systemd/user/hyprland-lid-handler.service`: Systemd service for lid events
- `.config/systemd/user/hyprland-monitor-hotplug.service`: Systemd service for monitor hotplug detection

### Modified Files
- `hyprland.conf`: Added multi-monitor configuration source
- `configs/exec.conf`: Added auto-configuration on startup
- `configs/monitors.conf`: Auto-generated monitor configuration

## 🛠️ Usage

### Interactive Configuration
```bash
# Run the interactive multi-monitor manager
~/.config/hypr/scripts/multi-monitor-manager.sh
```

### Quick Setups
```bash
# Auto-configure all monitors
~/.config/hypr/scripts/monitor-setup.sh auto

# Laptop screen only
~/.config/hypr/scripts/monitor-setup.sh laptop-only

# External monitor only
~/.config/hypr/scripts/monitor-setup.sh external-only

# Dual monitor extended
~/.config/hypr/scripts/monitor-setup.sh dual-extend

# Mirror mode for presentations
~/.config/hypr/scripts/monitor-setup.sh dual-mirror
```

### Command Line Options
```bash
# Show current status
./multi-monitor-manager.sh status

# Auto-configure monitors
./multi-monitor-manager.sh auto

# Handle lid event (used by systemd service)
./multi-monitor-manager.sh lid

# Setup lid behavior and auto-configure
./multi-monitor-manager.sh setup

# Redistribute workspaces
./multi-monitor-manager.sh redistribute
```

## 🔧 Configuration

### Monitor Resolution Configuration
The system automatically detects available resolutions. For manual configuration:

1. Use the interactive manager: `Super + Shift + M`
2. Select option 2 for specific monitor configuration
3. Choose your monitor and desired resolution

### Lid Behavior Customization
The lid handler is configured to:
- Ignore lid events when external monitor is connected and AC power is available
- Move all workspaces to external monitor when lid closes
- Re-enable internal monitor when lid opens

### Workspace Distribution
By default, workspaces are distributed as:
- Workspaces 1-5: Internal monitor (laptop) or primary monitor (desktop)
- Workspaces 6-10: External monitor

## 🐛 Troubleshooting

### Lid Events Not Working
1. Check if the systemd service is running:
   ```bash
   systemctl --user status hyprland-lid-handler.service
   ```

2. Enable the service if not running:
   ```bash
   systemctl --user enable --now hyprland-lid-handler.service
   ```

### Monitor Not Detected
1. Check available monitors:
   ```bash
   hyprctl monitors
   ```

2. Run auto-configuration:
   ```bash
   ~/.config/hypr/scripts/multi-monitor-manager.sh auto
   ```

### Resolution Issues
1. Check available modes for your monitor:
   ```bash
   hyprctl monitors -j | jq '.[].availableModes'
   ```

2. Use the interactive configuration to set specific resolution

## 📊 Current Setup Detection

Your current setup:
- **Device Type**: Laptop (Lenovo with eDP-1 internal display)
- **Internal Monitor**: eDP-1 (1920x1200@60Hz)
- **External Monitor**: HDMI-A-1 (ASUS VG27AQ1A, 3840x2160@60Hz)
- **Configuration**: Dual monitor extended mode

## 🎯 Keybinding Quick Reference

| Action | Keybinding | Description |
|--------|------------|-------------|
| Open Manager | `Super + Shift + M` | Interactive multi-monitor manager |
| Auto Configure | `Super + Ctrl + Shift + M` | Auto-detect and configure monitors |
| Move Window Right | `Super + Ctrl + Shift + →` | Move active window to next monitor |
| Move Window Left | `Super + Ctrl + Shift + ←` | Move active window to previous monitor |
| Focus Monitor | `Super + Ctrl + Alt + →/←` | Switch focus between monitors |
| Toggle Internal | `Super + Shift + I` | Enable/disable laptop screen |
| Mirror Mode | `Super + Shift + P` | Enable presentation mirror mode |
| Restart AGS | `Super + Shift + B` | Restart AGS bars for multi-monitor |
| Status | `Super + Shift + F12` | Show current monitor configuration |

## 🔄 Automatic Features

- **Startup**: Monitors are auto-configured when Hyprland starts
- **Lid Events**: Automatically handled via systemd service
- **Hot Plugging**: Monitors are reconfigured when connected/disconnected
- **AGS Bar Management**: Automatically restarts AGS when monitor configuration changes
- **Workspace Management**: Workspaces automatically redistribute when monitor configuration changes
