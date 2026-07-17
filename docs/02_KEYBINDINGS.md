# 02 - Keybindings Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Understanding Keybindings in Hyprland

This guide explains how to use, understand, and customize the keyboard shortcuts in this Hyprland configuration.

## Basic Modifier Keys

These keys are held down while pressing another key:

| Key           | Symbol  | Name    | Keyboard Position |
|---------------|---------|---------|-------------------|
| Windows/Super | `SUPER` | Super   | Bottom corners    |
| Alt           | `ALT`   | Alt     | Bottom row        |
| Control       | `CTRL`  | Control | Bottom corners    |
| Shift         | `SHIFT` | Shift   | Sides             |

## Window Management Keybindings

### Navigate Between Windows

```
Focus direction with arrow keys:
┌─────────────────┐
|  SUPER + UP     |  (Focus window above)
|  SUPER + LEFT   |  (Focus window left)
|  SUPER + RIGHT  |  (Focus window right)
|  SUPER + DOWN   |  (Focus window below)
└─────────────────┘

Alternative with Dvorak layout (home row):
SUPER + H/N/C/T (left/right/up/down)
```

### Resize Windows

Press and hold `SUPER + SHIFT` + arrow keys:

```
Grow/Shrink horizontally: SUPER + SHIFT + LEFT/RIGHT
Grow/Shrink vertically:   SUPER + SHIFT + UP/DOWN

Alternative (Dvorak): 
SUPER + SHIFT + H/N/C/T
```

### Move Windows Around

Press `SUPER + CTRL` + arrow keys:

```
Move left:  SUPER + CTRL + LEFT (or SUPER + CTRL + H)
Move right: SUPER + CTRL + RIGHT (or SUPER + CTRL + N)
Move up:    SUPER + CTRL + UP (or SUPER + CTRL + C)
Move down:  SUPER + CTRL + DOWN (or SUPER + CTRL + T)
```

### Window Modes

| Action       | Keybinding                 | What It Does                     |
|--------------|----------------------------|----------------------------------|
| Fullscreen   | `SUPER` + `F`              | Window takes entire screen       |
| Float toggle | `SUPER` + `Space`          | Window can overlap others        |
| Pin window   | `SUPER` + `CTRL` + `Space` | Window visible on all workspaces |
| Close window | `SUPER` + `Q`              | Close active window              |

## Workspace Navigation

### Switch Between Workspaces

```
Workspace 1-9:    SUPER + 1/2/3/4/5/6/7/8/9/0
Previous workspace: SUPER + TAB
Next/Prev workspace: SUPER + Mouse Wheel Up/Down
```

### Move Windows to Other Workspaces

```
Move to workspace 1-9: SUPER + CTRL + 1/2/.../0
```

**Example**: Open Firefox → `SUPER + CTRL + 3` moves it to workspace 3

### Special Workspace (Scratchpad)

The special workspace is hidden by default, great for temporary windows:

```
Toggle special workspace: SUPER + S
Move window to special:   SUPER + CTRL + S
```

**Use case**: Open a floating terminal, move to special workspace, have it available anywhere

## Launching Applications

| Action                | Keybinding                  | Opens                         |
|-----------------------|-----------------------------|-------------------------------|
| Terminal              | `SUPER` + `Return`          | Kitty terminal                |
| Floating terminal     | `SUPER` + `CTRL` + `Return` | Floating terminal window      |
| App launcher          | `SUPER`                     | Application search/launcher   |
| btop (system monitor) | `SUPER` + `P`               | System monitor in workspace 5 |

## Media Controls

### Volume Control

```
Volume up:   ALT + F12 or XF86AudioRaiseVolume
Volume down: ALT + F11 or XF86AudioLowerVolume
Volume mute: XF86AudioMute (usually on keyboard)
```

**Note**: Repeatable - hold down to continuously increase/decrease

### Brightness Control

```
Brightness up:   ALT + F3 or XF86MonBrightnessUp
Brightness down: ALT + F2 or XF86MonBrightnessDown
```

**Note**: Most modern keyboards have dedicated brightness keys

## Screenshot & Screen Recording

### Take Screenshots

```
Screenshot workspace:     SUPER + SHIFT + S
Screenshot selection:     SUPER + CTRL + SHIFT + S
```

### Screen Recording

```
Record workspace:         SUPER + SHIFT + R
Record selection:         SUPER + CTRL + SHIFT + R
```

Screenshots are saved to `$HOME/Pictures/Screenshots` or your configured directory
Screen recordings are saved to `$HOME/Videos/ScreenRecords` or your configured directory

## System Controls

| Action          | Keybinding                            | Purpose                     |
|-----------------|---------------------------------------|-----------------------------|
| Lock screen     | `SUPER` + `SHIFT` + `Escape`          | Requires password to unlock |
| Suspend (sleep) | `SUPER` + `CTRL` + `Escape`           | Enter sleep mode            |
| Shutdown        | `SUPER` + `CTRL` + `SHIFT` + `Escape` | Turn off computer           |

**⚠️ WARNING**: Shutdown requires no password confirmation!

## Status Bar & Panels

These keybindings toggle various UI panels:

| Action                    | Keybinding          | Panel                |
|---------------------------|---------------------|----------------------|
| Toggle status bar         | `SUPER` + `B`       | Top bar              |
| Toggle app launcher       | `SUPER` + `SUPER_L` | App menu             |
| Toggle media panel        | `SUPER` + `M`       | Music/media controls |
| Toggle right panel        | `SUPER` + `R`       | Right sidebar        |
| Toggle left panel         | `SUPER` + `L`       | Left sidebar         |
| Toggle wallpaper switcher | `SUPER` + `W`       | Background picker    |
| Toggle user panel         | `SUPER` + `Escape`  | User menu            |

## Utilities

| Action            | Keybinding              | Purpose                 |
|-------------------|-------------------------|-------------------------|
| Clipboard manager | `SUPER` + `SHIFT` + `V` | Recent copied items     |
| Emoji picker      | `SUPER` + `.`           | Search and insert emoji |
| Notes app         | `SUPER` + `ALT` + `N`   | Quick notes             |
| Keyboard layout   | `ALT` + `F10`           | Toggle Dvorak/QWERTY    |

## Mouse Bindings

| Action             | Mouse Button                 | Purpose                   |
|--------------------|------------------------------|---------------------------|
| Drag window        | `SUPER` + Left click + drag  | Move window               |
| Resize window      | `SUPER` + Right click + drag | Resize window             |
| Next workspace     | `SUPER` + Mouse wheel up     | Scroll through workspaces |
| Previous workspace | `SUPER` + Mouse wheel down   | Scroll through workspaces |

## How to Customize Keybindings

### Edit the Bindings File

Open `~/.config/hypr/config/bind.lua`

### Add a New Keybinding

General syntax:
```lua
hl.bind("MODIFIER + KEY", hl.dsp.exec_cmd("command"))
```

### Examples

**Add a screenshot tool shortcut:**
```lua
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("flameshot gui"))
```

**Add a custom script:**
```lua
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/my-script.sh"))
```

**Bind multiple key combinations:**
```lua
-- Both do the same thing
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + C", hl.dsp.focus({ direction = "up" }))  -- Dvorak
```

### Available Modifiers

```lua
"SUPER"  -- Windows key
"CTRL"   -- Control key
"ALT"    -- Alt key
"SHIFT"  -- Shift key

-- Combinations:
"SUPER + CTRL"
"ALT + SHIFT"
etc...
```

### Get Key Names

Use the `wev` tool to see key names:

```bash
# Install if needed
sudo pacman -S wev

# Run and press keys
wev

# You'll see output like: key 36 (Return)
# Use "Return" in your keybinding
```

## Common Key Names

```
Return / Enter
Space
Tab
Escape
Delete
Backspace
Home / End
Page_Up / Page_Down
a-z, A-Z, 0-9
F1-F12
XF86AudioRaiseVolume
XF86AudioLowerVolume
XF86AudioMute
```

## Organization Tips

### Group Related Keybindings

```lua
-- ## Window Management
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- ## Workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
```

### Using Variables

```lua
local mainMod = "SUPER"
local altMod = "ALT"
local menu = "~/.config/hypr/scripts/menu"

hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(menu))
```

## Troubleshooting Keybindings

### "My keybinding doesn't work"

1. **Check syntax**: `luac -p ~/.config/hypr/config/bind.lua` or `luacheck ~/.config/hypr/config/bind.lua`
2. **Verify key name**: Use `wev` to confirm key name
3. **Check modifiers**: Make sure modifier exists (SUPER, ALT, CTRL, SHIFT)
4. **Reload config**: `hyprctl reload`

### "Two keybindings are conflicting"

Each keybinding must be unique. Check for duplicates:

```bash
grep "SUPER + F" ~/.config/hypr/config/bind.lua
```

### "Keybinding stops working randomly"

- Another app may have captured the keybinding
- Check floating apps: they sometimes intercept keys
- Try a different key combination

## Performance Considerations

### Repeating Keybindings

Some keybindings are marked `repeating = true`:

```lua
hl.bind("ALT + F12", hl.dsp.exec_cmd("wpctl set-volume ..."), { repeating = true })
```

This allows holding the key to repeat the action (volume up/down).

### Locked Keybindings

Some keybindings are marked `locked = true`:

```lua
{ locked = true }
```

These work even when a window is focused and capturing input.

## Cheat Sheet

Save this quick reference:

```
SUPER + Return = Terminal
SUPER + Q = Close
SUPER + F = Fullscreen
SUPER + Space = Float
SUPER + 1-9 = Workspace
SUPER + Tab = Last workspace
SUPER + Arrows = Focus
SUPER + SHIFT + Arrows = Resize
SUPER + CTRL + Arrows = Move
SUPER + S = Special workspace
SUPER + SHIFT + S = Screenshot
SUPER + SHIFT + Escape = Lock
ALT + F11/F12 = Volume
ALT + F2/F3 = Brightness
```

## Next Steps

- Learn about [Window Management Rules](./03_WINDOW_MANAGEMENT.md)
- See [Advanced Customization](./08_ADVANCED.md) for advanced key handling
- Check [Gestures Guide](./07_GESTURES.md) for touchpad gestures
