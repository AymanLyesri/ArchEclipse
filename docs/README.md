# Hyprland Configuration Documentation

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Complete Beginner's Guide to Hyprland

Welcome! This documentation provides comprehensive tutorials and guides for understanding and customizing the Hyprland window manager configuration used in Arch Eclipse.

---

> **Hyprland 0.55+ (May 2026):** Lua configuration is now the **default and recommended** format.
> The old `hyprland.conf` (Hyprlang) still works for a few more releases, but migration to Lua is encouraged.
> This entire documentation covers the Lua config format used by Arch Eclipse.

## Quick Start (5 Minutes)

### What is Hyprland?

Hyprland is a modern **tiling window manager** - it automatically organizes your windows in a grid instead of letting them overlap randomly.

### Requirements

1. Arch Linux (Other Arch-based distributions may work, with varying degrees of success)
2. Hyprland (Make sure hyprland works properly before installing the dots)
3. Necessary packages (do not worry they will be installed automatically)

### Installation Guide

0. **Install Arch Linux**: Check the [official Arch Linux wiki](https://wiki.archlinux.org/title/Installation_guide)
1. **Install Hyprland**: Check the [official Hyprland wiki](https://wiki.hypr.land/Getting-Started/Installation/)
2. **Install Arch Eclipse**: Run the official installation script from the [repository](https://github.com/AymanLyesri/ArchEclipse)
   ```bash
   python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/ArchEclipse/refs/heads/master/.config/hypr/maintenance/install.py)
   ```
3. **Start Hyprland**: After installation and system reboot, make sure you have selected the Hyprland (uwsm-managed) session from your login manager.
4. **Use the default hotkeys**: See [Most Important Keybindings](#most-important-keybindings)

That's it! You're using Hyprland with Arch Eclipse configuration.

### Update Guide

**Update Arch Eclipse** To update the config and its related pkgs. Simply run archeclipse in the terminal:

```bash
archeclipse
```

### Most Important Keybindings

```
SUPER + Return    = Open terminal
SUPER + Q         = Close window
SUPER + F         = Fullscreen
SUPER + 1-9       = Switch workspace
SUPER + Space     = Float window (allow overlap)
SUPER + Tab       = Last workspace
SUPER + Left/Right/Up/Down = Focus different window
```

---

### About Arch Eclipse

This is the Hyprland configuration from the **Arch Eclipse** project by **AymanLyesri**.

**Features include:**

- Dynamic wallpapers and color schemes
- Advanced GTK4 widgets (Ags)
- Application launcher with clipboard history
- Right and left panels with customizable widgets
- Wallpaper switcher
- Keystroke visualizer
- Chat bot and booru viewer
- Dynamic color schemes based on wallpaper

**Learn more:** [Arch Eclipse GitHub](https://github.com/AymanLyesri/ArchEclipse)

---

## Documentation Structure

Choose what you want to learn:

### **For Complete Beginners**

1. **[00_DOCUMENTATION.md](./00_DOCUMENTATION.md)** - Start here!
   - What is Hyprland
   - Quick reference tables
   - Basic troubleshooting
   - Link to official Arch Eclipse repository

### **Essential Guides** (Read in order)

2. **[01_ANIMATIONS.md](./01_ANIMATIONS.md)**
   - Understanding window animations
   - Smooth transitions
   - Performance optimization

3. **[02_KEYBINDINGS.md](./02_KEYBINDINGS.md)**
   - All keyboard shortcuts
   - How to add custom keybindings
   - Keybinding troubleshooting

4. **[03_WINDOW_MANAGEMENT.md](./03_WINDOW_MANAGEMENT.md)**
   - Tiling vs floating windows
   - Window rules (automatic configuration per app)
   - Workspaces

5. **[04_DISPLAYS.md](./04_DISPLAYS.md)**
   - Multi-monitor setup
   - Resolution and refresh rate
   - Display positioning

6. **[05_INPUT_DEVICES.md](./05_INPUT_DEVICES.md)**
   - Keyboard configuration
   - Mouse and touchpad settings
   - Keyboard layout switching

7. **[06_VISUAL_STYLING.md](./06_VISUAL_STYLING.md)**
   - Colors and borders
   - Blur and shadow effects
   - Custom themes

8. **[07_GESTURES.md](./07_GESTURES.md)**
   - Touchpad gestures
   - 3-finger and 4-finger swipes
   - Gesture troubleshooting

### **Advanced Topics**

9. **[08_ADVANCED.md](./08_ADVANCED.md)**
   - Lua scripting
   - Custom modules
   - Performance tuning
   - Event handling

---

## Configuration File Structure

```
~/.config/hypr/
├── hyprland.lua              ← Main entry point
├── config/
│   ├── animations.lua        ← Animation effects
│   ├── bind.lua              ← Keyboard shortcuts
│   ├── decoration.lua        ← Colors & effects
│   ├── device.lua            ← Input devices
│   ├── env.lua               ← Environment variables
│   ├── exec.lua              ← Startup scripts
│   ├── general.lua           ← General settings
│   ├── gesture.lua           ← Touchpad gestures
│   ├── input.lua             ← Keyboard/mouse config
│   ├── layerrule.lua         ← UI layer styling
│   ├── layouts.lua           ← Window tiling layouts
│   ├── misc.lua              ← Miscellaneous options
│   ├── monitor.lua           ← Display setup
│   ├── windowrule.lua        ← Per-app configuration
│   ├── workspace.lua         ← Workspace setup
│   ├── defaults/             ← Preset configurations
│   ├── custom/               ← User custom modules
│   └── shaders/              ← GLSL shader files
├── hyprlock.conf             ← Lock screen styling
├── hyprpaper.conf            ← Wallpaper settings
└── scripts/                  ← Custom scripts
```

---

## Common Tasks

### "How do I..."

**...add a custom keybinding?**
→ See [02_KEYBINDINGS.md - Customize Keybindings](./02_KEYBINDINGS.md#how-to-customize-keybindings)

**...change the wallpaper?**
→ See [04_DISPLAYS.md - Wallpaper Integration](./04_DISPLAYS.md#wallpaper-integration)

**...make windows float?**
→ See [03_WINDOW_MANAGEMENT.md - Floating State](./03_WINDOW_MANAGEMENT.md#floating)

**...use multiple monitors?**
→ See [04_DISPLAYS.md - Multiple Monitor Setup](./04_DISPLAYS.md#multiple-monitor-example)

**...change my keyboard layout?**
→ See [05_INPUT_DEVICES.md - Keyboard Layout](./05_INPUT_DEVICES.md#keyboard-layouts)

**...customize colors?**
→ See [06_VISUAL_STYLING.md - Colors](./06_VISUAL_STYLING.md#borders-and-colors)

**...use touchpad gestures?**
→ See [07_GESTURES.md](./07_GESTURES.md)

**...improve performance?**
→ See [06_VISUAL_STYLING.md - Performance](./06_VISUAL_STYLING.md#performance-optimization)

---

## Key Concepts Explained

### **Modifier Keys**

- `SUPER` = Windows key (your main modifier)
- `ALT` = Alt key
- `CTRL` = Control key
- `SHIFT` = Shift key

### **Workspaces**

Like virtual desktops - switch between them with `SUPER + 1-9`. Each workspace can have different windows.

### **Tiling vs Floating**

- **Tiled**: Windows auto-arrange in grid (default)
- **Floating**: Windows can overlap (like traditional desktop)
- Toggle: `SUPER + Space`

### **Window Rules**

Automatic configuration per app. Example: "Always open Firefox in workspace 2, always float calculator"

---

## Troubleshooting Quick Links

| Problem                      | Solution                                                                            |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| Config won't load            | [00_DOCUMENTATION - Troubleshooting](./00_DOCUMENTATION.md#troubleshooting)         |
| Keybindings don't work       | [02_KEYBINDINGS - Troubleshooting](./02_KEYBINDINGS.md#troubleshooting-keybindings) |
| Blur is slow                 | [06_VISUAL_STYLING - Performance](./06_VISUAL_STYLING.md#performance-optimization)  |
| Multiple monitors confusing  | [04_DISPLAYS - Monitor Setup](./04_DISPLAYS.md)                                     |
| Touchpad not working         | [05_INPUT_DEVICES - Troubleshooting](./05_INPUT_DEVICES.md#troubleshooting)         |
| Gestures not detected        | [07_GESTURES - Troubleshooting](./07_GESTURES.md#troubleshooting)                   |
| Window opened in wrong place | [03_WINDOW_MANAGEMENT - Troubleshooting](./03_WINDOW_MANAGEMENT.md#troubleshooting) |

---

## Configuration Presets

Ready-made configurations for different use cases:

### **Professional Setup** (Minimal distractions)

See: [03_WINDOW_MANAGEMENT.md - Professional Setup](./03_WINDOW_MANAGEMENT.md#professional-setup)

### **Gaming Setup** (Maximum performance)

See: [03_WINDOW_MANAGEMENT.md - Gaming Setup](./03_WINDOW_MANAGEMENT.md#gaming-setup)

### **Cozy Setup** (Maximum aesthetics)

See: [03_WINDOW_MANAGEMENT.md - Cozy Setup](./03_WINDOW_MANAGEMENT.md#cozy-setup)

---

## Learning Path

**Week 1**: Get comfortable with basics

- Read: DOCUMENTATION.md, 02_KEYBINDINGS.md
- Practice: Navigate, open/close apps, switch workspaces

**Week 2**: Customize for your needs

- Read: 03_WINDOW_MANAGEMENT.md, 04_DISPLAYS.md, 06_VISUAL_STYLING.md
- Practice: Customize keybindings, adjust colors

**Week 3**: Master advanced features

- Read: 07_GESTURES.md, 05_INPUT_DEVICES.md
- Practice: Set up touchpad, configure multiple displays

**Week 4**: Power user territory

- Read: 08_ADVANCED.md
- Practice: Create custom scripts, optimize performance

---

## External Resources

- **Official Hyprland Wiki**: https://wiki.hypr.land/
- **Hyprland GitHub**: https://github.com/hyprwm/Hyprland
- **Hyprland Forum**: https://forum.hypr.land/
- **Reddit**: https://www.reddit.com/r/hyprland/

---

## Getting Help

### Before asking for help:

1. **Check the troubleshooting section** in relevant guide
2. **Search the Hyprland wiki**: https://wiki.hypr.land/
3. **Check syntax**: `luac -p ~/.config/hypr/hyprland.lua` or `luacheck ~/.config/hypr/hyprland.lua`
4. **Check logs**: `journalctl -xen` or `hyprctl rollinglog`

### When reporting issues:

Include:

- Your Hyprland version: `hyprctl version` or `hyprctl systeminfo`
- Relevant config section
- Error message from `luac -p ~/.config/hypr/hyprland.lua` or `luacheck ~/.config/hypr/hyprland.lua` or `hyprctl configerrors`
- What you were trying to do

---

## Tips for Success

- **Start simple**: Don't change everything at once
- **Test changes**: After editing, press `SUPER` + `CTRL` + `R` to reload config
- **Use keybindings**: Learning keybindings is faster than menus
- **Back up config**: Copy `~/.config/hypr` before major changes
- **Join community**: Ask questions, share your setup

---

## Next Steps

1. **Just starting?** → Read [00_DOCUMENTATION.md](./00_DOCUMENTATION.md)
2. **Want to customize?** → Start with [02_KEYBINDINGS.md](./02_KEYBINDINGS.md)
3. **Getting technical?** → Jump to [08_ADVANCED.md](./08_ADVANCED.md)
4. **Lost?** → Check [Troubleshooting Quick Links](#troubleshooting-quick-links) above

---

Enjoy your Hyprland journey!

**For Arch Eclipse specific issues:** [GitHub Issues](https://github.com/AymanLyesri/ArchEclipse/issues)

**For Hyprland general questions:** [Hyprland Community](https://forum.hypr.land/)

**Original Project:** [Arch Eclipse Repository](https://github.com/AymanLyesri/ArchEclipse)

**Project Creator:** **AymanLyesri**
