# Hyprland Configuration Documentation

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

Welcome to the complete guide for the Hyprland window manager configuration used in **Arch Eclipse**. This documentation covers everything you need to understand and customize this advanced Linux desktop setup.

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Architecture Overview](#architecture-overview)
3. [Detailed Configuration Guides](#detailed-configuration-guides)
4. [Keybindings Reference](#keybindings-reference)
5. [Customization Tips](#customization-tips)
6. [Troubleshooting](#troubleshooting)

## Quick Start Guide

### What is Hyprland?

Hyprland is a modern, dynamic tiling window manager for Wayland. Unlike traditional stacking window managers (like on Windows or macOS), it automatically arranges your application windows in a grid-like layout, maximizing your screen space.

### Getting Started

### Requirements

1. Arch Linux (Other Arch-based distributions may work, with varying degrees of success)
2. Hyprland (Make sure hyprland works properly before installing the dots)
3. Necessary packages (do not worry they will be installed automatically)

### Installation Guide

0. **Install Arch Linux**: Check the [official Arch Linux wiki](https://wiki.archlinux.org/title/Installation_guide)
1. **Install Hyprland**: Check the [official Hyprland wiki](https://wiki.hypr.land/Getting-Started/Installation/)
2. **Install Arch Eclipse**: Run the installation script from the [official repository](https://github.com/AymanLyesri/ArchEclipse)
   ```bash
   python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/ArchEclipse/refs/heads/master/.config/hypr/maintenance/install.py)
   ```
3. **Start Hyprland**: After installation and system reboot, make sure you have selected the Hyprland (uwsm-managed) session from your login manager.
4. **Use the default hotkeys**: See [Keybindings Reference](#keybindings-reference)

### Update Guide

**Update Arch Eclipse** To update the config and its related pkgs. Simply run archeclipse in the terminal:

```bash
archeclipse
```

### Essential First Steps

When you first log in:

- Press `SUPER` (Windows key) + `Return` (Enter key) to open a terminal
- Press `SUPER` + arrow keys to navigate between windows
- Press `SUPER` + `1-0` to switch between workspaces
- Press `SUPER` + `SHIFT` + `Escape` to lock your screen

## Architecture Overview

This configuration is built on a **Lua-based modular system**. Here's how it works:

```
hyprland.lua (Main Entry Point)
├── Loads config modules from config/
├── animations.lua (visual effects)
├── bind.lua (keyboard shortcuts)
├── decoration.lua (visual styling)
├── device.lua (hardware settings)
├── env.lua (environment variables)
├── exec.lua (execution scripts & autostart)
├── general.lua (general settings & gaps)
├── gesture.lua (touchpad gestures)
├── input.lua (keyboard/mouse/touchpad)
├── layerrule.lua (UI layer styling)
├── layouts.lua (window arrangement)
├── misc.lua (miscellaneous options)
├── monitor.lua (display setup)
├── windowrule.lua (per-app configuration)
├── workspace.lua (workspace initialization)
├── defaults/ (preset configurations)
├── custom/ (user custom modules)
└── shaders/ (GLSL shader files)
```

### About Hyprland Lua

> **Hyprland 0.55+ (May 2026):** Lua configuration is now the **default and recommended** format.
> The old `hyprland.conf` (Hyprlang) still works for a few more releases, but migration to Lua is encouraged.
> This entire documentation covers the Lua config format used by Arch Eclipse.

Sample config: https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua

This configuration uses Lua:

- `hl.config()` - Configure Hyprland options
- `hl.bind()` - Define keybindings
- `hl.gesture()` - Configure touchpad gestures
- `hl.monitor()` - Setup displays
- `hl.window_rule()` - Per-app window configuration
- `hl.workspace_rule()` - Workspace initialization
- `hl.dsp.*` - Dispatcher commands (window/focus/workspace actions)

### Why Lua?

Lua configuration is:

- **More readable** than traditional conf files
- **More powerful** with full programming capabilities
- **Easier to maintain** with modular structure
- **Customizable** - you can add logic and variables

## Detailed Configuration Guides

For detailed information about each component, refer to:

1. [Animations Guide](./01_ANIMATIONS.md)
2. [Keybindings Guide](./02_KEYBINDINGS.md)
3. [Window Management Guide](./03_WINDOW_MANAGEMENT.md)
4. [Display Configuration Guide](./04_DISPLAYS.md)
5. [Input Devices Guide](./05_INPUT_DEVICES.md)
6. [Visual Styling Guide](./06_VISUAL_STYLING.md)
7. [Gestures Guide](./07_GESTURES.md)
8. [Advanced Customization](./08_ADVANCED.md)

## Keybindings Reference

### Quick Reference Table

| Action                   | Shortcut                                | Description                     |
| ------------------------ | --------------------------------------- | ------------------------------- |
| **Window Management**    |                                         |                                 |
| Fullscreen toggle        | `SUPER` + `F`                           | Make window fullscreen          |
| Close window             | `SUPER` + `Q`                           | Close active window             |
| Float toggle             | `SUPER` + `Space`                       | Toggle floating mode            |
| Pin window               | `SUPER` + `CTRL` + `Space`              | Pin to all workspaces           |
| **Launch Applications**  |                                         |                                 |
| Terminal                 | `SUPER` + `Return`                      | Open Kitty terminal             |
| Floating terminal        | `SUPER` + `CTRL` + `Return`             | Open floating terminal          |
| App launcher             | `SUPER` + `SUPER_L`                     | Search and launch apps          |
| **Media Controls**       |                                         |                                 |
| Volume up                | `ALT` + `F12` or `XF86AudioRaiseVolume` | Increase volume                 |
| Volume down              | `ALT` + `F11` or `XF86AudioLowerVolume` | Decrease volume                 |
| Mute                     | `XF86AudioMute`                         | Toggle mute                     |
| Brightness up            | `ALT` + `F3` or `XF86MonBrightnessUp`   | Increase brightness             |
| Brightness down          | `ALT` + `F2` or `XF86MonBrightnessDown` | Decrease brightness             |
| **Navigation**           |                                         |                                 |
| Focus left/right/up/down | `SUPER` + Arrow keys                    | Move focus between windows      |
| Focus (Dvorak)           | `SUPER` + `H/N/C/T`                     | Dvorak-compatible focus         |
| **Workspaces**           |                                         |                                 |
| Switch workspace         | `SUPER` + `1-0`                         | Jump to workspace 1-10          |
| Previous workspace       | `SUPER` + `Tab`                         | Go to last active workspace     |
| Next/previous workspace  | `SUPER` + Mouse wheel                   | Cycle through workspaces        |
| **Special Features**     |                                         |                                 |
| Special workspace toggle | `SUPER` + `S`                           | Toggle hidden workspace         |
| Move to special          | `SUPER` + `CTRL` + `S`                  | Move window to hidden workspace |
| Lock screen              | `SUPER` + `SHIFT` + `Escape`            | Lock with password              |
| Suspend                  | `SUPER` + `CTRL` + `Escape`             | Sleep mode                      |
| **Screenshots**          |                                         |                                 |
| Screenshot               | `SUPER` + `SHIFT` + `S`                 | Screenshot current workspace    |
| Screenshot area          | `SUPER` + `CTRL` + `SHIFT` + `S`        | Screenshot selection            |
| Screen record            | `SUPER` + `SHIFT` + `R`                 | Record current workspace        |
| Record area              | `SUPER` + `CTRL` + `SHIFT` + `R`        | Record selection                |

For more detailed information, see [Keybindings Guide](./02_KEYBINDINGS.md)

## Customization Tips

### Adding a New Keybinding

Edit `config/bind.lua` and add:

```lua
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("your-command-here"))
```

### Changing Window Layout

In `config/layouts.lua`, change the default layout:

```lua
layout = "master"  -- Switch to Master layout
-- or
layout = "dwindle"  -- Tiling layout (default)
```

### Customizing Colors

Edit `config/decoration.lua` to change:

- Border colors
- Window opacity
- Blur effect strength

### Adding Custom Scripts

Place your scripts in `~/.config/hypr/scripts/` and call them:

```lua
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/my-script.sh"))
```

## Troubleshooting

### Configuration won't load

Since config is now pure Lua, check syntax with Lua:

```bash
# Check if Lua can parse the file
luac -p ~/.config/hypr/hyprland.lua

# Or use syntax checker
# If command not found, install the luacheck package: sudo pacman -S luacheck
luacheck ~/.config/hypr/hyprland.lua

# Hyprland checker
hyprctl configerrors
```

Hyprland shows parsing errors as on-screen notifications when you reload. Check logs:

- View detailed logs: `journalctl -xen` or `hyprctl rollinglog`
- Reload to see errors: `hyprctl reload`

### Keybindings not working

- Check if modifier key is correct (`SUPER`, `ALT`, `CTRL`, `SHIFT`)
- Verify the key name exists: `wev` tool shows key codes
- Test with simpler binding first

### Screen flickering

- Check Hyprland version compatibility
- Try disabling blur in `config/decoration.lua`
- Update GPU drivers

### Can't find configuration files

- Hyprland configs should be in `~/.config/hypr/`
- Check with: `echo $HOME/.config/hypr`
- Ensure files have `.lua` extension

For more help, visit:

- **Arch Eclipse GitHub:** https://github.com/AymanLyesri/ArchEclipse
- **Arch Eclipse Discord:** https://discord.gg/fMGt4vH6s5
- **Official Hyprland Wiki:** https://wiki.hypr.land/
- **Hyprland GitHub:** https://github.com/hyprwm/Hyprland
- **Hyprland Forum:** https://forum.hypr.land/

**Arch Eclipse Project Creator:** AymanLyesri
