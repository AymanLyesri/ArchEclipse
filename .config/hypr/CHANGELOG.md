# Changelog

## [Unreleased]

### Added

- Comprehensive multi-monitor support with automatic device detection
- `multi-monitor-manager.sh` script for intelligent monitor management
- Automatic device type detection (laptop/desktop)
- Intelligent lid event handling for laptops
- Automatic resolution configuration for secondary monitors
- Enhanced keybinds for moving workspaces between monitors
- `lid-handler.sh` script for automatic lid events
- `monitor-setup.sh` script for common quick configurations
- `monitor-hotplug.sh` script for automatic monitor hotplug detection
- `move-window-monitor.sh` script for dynamic window movement between monitors
- systemd service `hyprland-lid-handler.service` for automatic event handling
- systemd service `hyprland-monitor-hotplug.service` for monitor hotplug detection
- `multi-monitor-keybinds.conf` configuration file with specialized keybinds
- Complete documentation in `README-MultiMonitor.md`

### Changed

- Updated `hyprland.conf` to include multi-monitor configuration
- Modified `configs/exec.conf` for startup auto-configuration
- Enhanced `configs/monitors.conf` with automatic generation

### Fixed

- Fixed keybind syntax errors in multi-monitor configuration
- Corrected dispatcher commands for window and workspace movement
- Fixed AGS bar not appearing on external monitors
- Fixed pkill command to avoid killing other applications (like Windsurf)
- Added automatic AGS restart when monitor configuration changes
- Added automatic monitor hotplug detection for seamless AGS bar management
- Fixed window movement keybinds to work dynamically with any monitor configuration

### Features

- **Automatic Detection**: Identifies laptops vs desktops automatically
- **Smart Lid Management**: When lid closes with AC power and external monitor connected:
  - Disables internal monitor
  - Moves all workspaces to external monitor
  - Prevents system suspension
- **Workspace Redistribution**: Automatically distributes workspaces across monitors
- **Resolution Configuration**: Easy interface for configuring secondary monitor resolutions
- **Advanced Keybinds**: 
  - `Super + Alt + →/←`: Move current workspace between monitors
  - `Super + Shift + Alt + →/←`: Move active window between monitors
  - `Super + Ctrl + Alt + →/←`: Focus between monitors
  - `Super + Shift + M`: Open interactive multi-monitor manager
  - `Super + Shift + P`: Mirror mode for presentations
  - `Super + Shift + I`: Toggle internal monitor

## [2025-09-06]

### Added

- Initial implementation of multi-monitor support for ArchEclipse Rice
- Complete system for automatic monitor detection and configuration
- Intelligent laptop event handling (lid close/open)
- Management and automated configuration scripts
- Specialized keybindings for multi-monitor workflows
- Complete system documentation
