# 05 - Input Devices Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Understanding Input Configuration

This guide covers keyboard, mouse, and touchpad settings in Hyprland.

## Keyboard Configuration

### Keyboard Settings in `config/input.lua`

```lua
hl.config({
    input = {
        kb_rules = "evdev",        -- Input method
        kb_model = "pc105",        -- Keyboard model
        kb_options = "grp:alt_shift_toggle",  -- Layout switching
        repeat_rate = 50,          -- Key repeat rate (keys/second)
        repeat_delay = 300,        -- Delay before repeat starts (ms)
        numlock_by_default = 1,    -- Start with numlock on
        left_handed = 0,           -- Left-handed mode (mouse)
        follow_mouse = 1,          -- Focus follows cursor
    },
})
```

### Keyboard Models

```
pc105      Standard US 105-key
pc104      US 104-key
laptop     Laptop keyboard
mac        Apple keyboard
dvorak     Dvorak layout hardware
```

**View available keyboard options** (works on Wayland/Hyprland via XKB):
```bash
# List keyboard layouts
localectl list-x11-keymap-layouts

# List keyboard models  
localectl list-x11-keymap-models | head -20

# List variants (dvorak, colemak, etc.)
localectl list-x11-keymap-variants en
```

**Note**: These `x11-keymap` commands work perfectly with Wayland. XKB is the standard keyboard config across Linux desktops.

### Keyboard Layouts

Change keyboard layout in keybindings. Your config supports:
- US (QWERTY)
- Dvorak (via `ALT + F10`)

### Key Repeat

Controls how fast held keys repeat:

```lua
repeat_rate = 50     -- 50 times per second (fast)
repeat_delay = 300   -- Wait 300ms before repeating
```

**For typing comfort** (normal):
```lua
repeat_rate = 30
repeat_delay = 500
```

**For gaming** (responsive):
```lua
repeat_rate = 50
repeat_delay = 200
```

## Mouse Configuration

### Basic Mouse Settings

```lua
left_handed = 0     -- 0 = right-handed, 1 = left-handed
```

### Mouse Acceleration

Currently not configured (uses system default). To disable:

1. Check current accel profile via libinput

```bash
libinput list-devices | grep "Accel profiles"
```

2. Disable acceleration (add to config)

```lua
hl.config({
    input = {
        accel_profile = "flat",
        force_no_accel = true
    },
})
```

### Mouse Speed

Controlled by system settings. Here are ways to change mouse speed (sensitivity):


1. Check device name

```bash
hyprctl devices
```

2. Increase mouse speed in config (permanent solution)

```lua
hl.config({
    input = {
        sensitivity = 0.5, -- Increase mouse speed (e.g. 0.5)
    },
})
```

3. Increase mouse speed in terminal (temporarily solution)

```bash
hyprctl keyword "device[DEVICE_NAME]:sensitivity" 0.5
```

### Mouse Bindings (From Keybindings)

```
SUPER + mouse_down   = Next workspace
SUPER + mouse_up     = Previous workspace
SUPER + click        = Drag window
SUPER + right-click  = Resize window
```

## Touchpad Configuration

### Touchpad Settings

```lua
touchpad = {
    scroll_factor = 0.1,           -- Scroll sensitivity
    disable_while_typing = 0,      -- Keep touchpad active while typing
    natural_scroll = 1,            -- Mac-style scrolling
    tap_to_click = 1,              -- Tap to click enabled
}
```

### Scroll Factor

Controls how much the screen scrolls per touchpad movement:

```lua
scroll_factor = 0.1   -- Minimal scroll (most sensitive)
scroll_factor = 0.5   -- Moderate
scroll_factor = 1.0   -- Maximum scroll per unit movement
```

**Lower = more sensitive scrolling**

### Natural Scroll

Mimics Apple/macOS behavior:

```lua
natural_scroll = 1    -- Enabled (macOS style)
natural_scroll = 0    -- Disabled (traditional)
```

With `natural_scroll = 1`:
- Scroll down on touchpad → Content moves up (like pushing paper)

### Tap to Click

```lua
tap_to_click = 1      -- Single tap = left click
tap_to_click = 0      -- Disabled
```

### Disable While Typing

Prevents accidental pointer movement while typing:

```lua
disable_while_typing = 0    -- Touchpad always active
disable_while_typing = 1    -- Disabled while typing
```

## Hardware Devices

### Device-Specific Configuration

Edit `config/device.lua`:

```lua
hl.device({
    name = "elan-touchpad",    -- Device name
    sensitivity = 0.1,         -- Sensitivity (-1 to 1)
})
```

### Finding Device Names

```bash
# List all input devices
libinput list-devices

# Get verbose info
hyprctl devices
```

### Example Device Output

```
Device: ELAN Touchpad
Type: Touchpad
Enabled: Yes
Sensitivity: 0.1
```

### Sensitivity Range

```
-1.0  = Slowest
 0.0  = Default/neutral
 1.0  = Fastest
```

## Cursor Configuration

### Cursor Size

In `config/env.lua`:

```lua
hl.env("HYPRCURSOR_SIZE", "24")   -- Cursor size in pixels
```

Change to larger/smaller:
```lua
hl.env("HYPRCURSOR_SIZE", "32")   -- Large
hl.env("HYPRCURSOR_SIZE", "16")   -- Small
```

### Cursor Theme

System-wide cursor theme. To change:

```bash
# List available themes
ls /usr/share/icons/*/cursors

# Set theme (add to hyprland.lua)
hl.env("XCURSOR_THEME", "Adwaita")
```

## Multiple Input Devices

If you have multiple keyboards or mice:

### Identify Devices

```bash
# Get detailed device info
hyprctl devices

# Output shows:
# Device: Logitech USB Mouse
# Device: Kinesis Advantage
```

### Device-Specific Settings

Currently not easily configurable per-device in Hyprland. Settings apply globally to all devices of same type (all mice, all keyboards).

## Keyboard Shortcuts for Layout Switching

### Current Setup

Switch between Dvorak and QWERTY:

Keybinding: ALT + F10
Toggles between layouts via script

The script is at: `~/.config/hypr/scripts/dvorak-qwerty.sh`

### Other Layout Combinations

Common combinations:

```lua
kb_options = "grp:alt_shift_toggle"    -- Alt+Shift to switch (current)
kb_options = "grp:ctrl_shift_toggle"   -- Ctrl+Shift to switch
kb_options = "grp:win_space_toggle"    -- Win+Space to switch
```

## Practical Configuration Examples

### Fast Typer Profile

```lua
repeat_rate = 40
repeat_delay = 200
scroll_factor = 0.2
tap_to_click = 1
disable_while_typing = 1
```

### Gaming Profile

```lua
repeat_rate = 50
repeat_delay = 100
scroll_factor = 0.5
tap_to_click = 0
disable_while_typing = 1
accel_profile = "flat"
```

### Accessibility Profile

```lua
repeat_rate = 20    -- Slower key repeat
repeat_delay = 500  -- Long delay before repeat
scroll_factor = 0.05  -- Less sensitive scrolling
tap_to_click = 0    -- Disable accidental taps
```

### Laptop-Friendly Profile

```lua
repeat_rate = 35
repeat_delay = 400
scroll_factor = 0.15
tap_to_click = 1
disable_while_typing = 1
natural_scroll = 1
```

## Troubleshooting

### "Keys not repeating when held"

1. Check repeat settings in `config/input.lua`
2. Try: `repeat_rate = 30` and `repeat_delay = 300`
3. Reload: `hyprctl reload`

### "Scrolling too fast/slow"

Edit touchpad section:
```lua
scroll_factor = 0.1   -- Try different value
```

Reload and test.

### "Mouse feels sluggish"

1. Check sensitivity: `hyprctl devices`
2. Adjust: `hl.device({ name = "...", sensitivity = 0.5 })`
3. System acceleration might be enabled - disable it

### "Touchpad won't click"

```lua
tap_to_click = 1   -- Re-enable
```

Or test with:
```bash
libinput debug-events
```

Then tap and watch for events.

### "Left-handed mode not working"

1. Check setting: `left_handed = 1`
2. This only affects pointer, not all devices
3. Some mice have hardware left-handed mode

### "Keyboard layout not switching"

1. Check script exists: `ls ~/.config/hypr/scripts/dvorak-qwerty.sh`
2. Make executable: `chmod +x ~/.config/hypr/scripts/dvorak-qwerty.sh`
3. Test manually: `bash ~/.config/hypr/scripts/dvorak-qwerty.sh`

### "Cursor invisible or too small"

Adjust cursor size:
```lua
hl.env("HYPRCURSOR_SIZE", "24")  -- Current
hl.env("HYPRCURSOR_SIZE", "48")  -- Try larger
```

## XKB Options Reference

Common keyboard options for `kb_options`:

```lua
"grp:alt_shift_toggle"    -- Alt+Shift between layouts
"compose:ralt"            -- Right Alt as Compose key
"caps:escape"             -- Caps Lock → Escape
"ctrl:nocaps"             -- Caps Lock → Control
"numpad:pc"               -- Use PC numpad layout
"altwin:menu_win"         -- Menu key as Super
```

Multiple options (separated by comma):
```lua
kb_options = "grp:alt_shift_toggle,compose:ralt,caps:escape"
```

## Performance Impact

Input settings have minimal performance impact. Most are just preference/comfort settings.

The main performance factor is the OS/compositor, not input configuration.

## Next Steps

- See [Window Management Guide](./03_WINDOW_MANAGEMENT.md) for mouse interactions
- Learn about [Gestures Guide](./07_GESTURES.md) for touchpad gestures
- Check [Display Configuration](./04_DISPLAYS.md) for multi-monitor setup
