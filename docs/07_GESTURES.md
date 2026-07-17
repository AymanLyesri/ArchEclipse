# 07 - Gestures Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Touchpad Gestures in Hyprland

This guide covers touchpad gestures for controlling workspaces and windows.

## What Are Gestures?

Gestures are special touchpad movements that trigger actions:

```
3-finger swipe → Switch workspaces
4-finger swipe up → Toggle fullscreen
4-finger swipe right → Toggle floating
etc.
```

## Gesture Configuration

In `config/gesture.lua`:

```lua
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = "special" })
hl.gesture({ fingers = 3, direction = "down", action = "special" })
hl.gesture({ fingers = 4, direction = "up", action = "fullscreen" })
hl.gesture({ fingers = 4, direction = "down", action = "fullscreen" })
hl.gesture({ fingers = 4, direction = "right", action = "float" })
hl.gesture({ fingers = 4, direction = "left", action = "float" })
```

## Your Configured Gestures

### 3-Finger Gestures

| Gesture              | Action                   | Result                          |
|----------------------|--------------------------|---------------------------------|
| Swipe left/right     | workspace                | Move to previous/next workspace |
| Swipe up             | special                  | Toggle special workspace        |
| Swipe down           | special                  | Toggle special workspace        |

### 4-Finger Gestures

| Gesture     | Action     | Result               |
|-------------|------------|----------------------|
| Swipe up    | fullscreen | Toggle fullscreen    |
| Swipe down  | fullscreen | Toggle fullscreen    |
| Swipe right | float      | Toggle floating mode |
| Swipe left  | float      | Toggle floating mode |

## Finger Count

```
2 fingers = Pinch, 2-finger scroll
3 fingers = Most common (workspace control)
4 fingers = Less common (advanced actions)
5+ fingers = Not typically supported
```

> **Note:**
>Unfortunately, 5+ finger gestures are not supported in Hyprland.
>Most touchpads and current Hyprland gesture setups commonly use 3–4 finger gestures.
>Support for higher finger counts depends on hardware and gesture implementation.

## Gesture Directions

```
"horizontal" = Left or right swipe (workspace switching)
"vertical"   = Up or down swipe
"up"         = Upward swipe
"down"       = Downward swipe
"left"       = Leftward swipe
"right"      = Rightward swipe
"inward"     = Pinch zoom inward
"outward"    = Pinch zoom outward
```

## Available Actions

```
"workspace"   = Switch workspaces
"special"     = Toggle special workspace
"fullscreen"  = Toggle fullscreen
"float"       = Toggle floating mode
"custom"      = Custom command
```

## Adding Custom Gestures

### Example: Close Window on 3-Finger Down

```lua
hl.gesture({
    fingers = 3,
    direction = "down",
    action = "close"  -- Close active window
})
```

### Example: Toggle App Launcher

```lua
hl.gesture({
    fingers = 2,
    direction = "up",
    action = "custom",
    command = "ags toggle app-launcher"
})
```

## Practical Uses

### For Laptop Users

3-finger swipe left/right to switch workspaces is very natural for trackpad users.

### For Desktop Trackpads

External trackpads work great too if they support multitouch:
- Magic Trackpad (Apple)
- High-end Logitech trackpads
- Microsoft Precision Trackpads

### For Gaming

Disable gestures during gaming to prevent accidental triggers:

Edit `config/gesture.lua` and comment out gestures:

```lua
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
```

## Gesture Sensitivity

Sensitivity is configured per gesture automatically. To adjust overall touchpad sensitivity:

In `config/input.lua`:

```lua
touchpad = {
    scroll_factor = 0.1,  -- Also affects gesture sensitivity
}
```

Lower = more sensitive to small movements

## Troubleshooting

### "Gestures don't work"

1. **Check touchpad supports multitouch**:
   ```bash
   libinput list-devices | grep "Touchpad"
   ```

2. **Verify multitouch enabled**:
   ```bash
   grep "Tap" /proc/bus/input/devices
   ```

3. **Test gestures**:
   ```bash
   libinput debug-events
   ```
   Then perform a 3-finger swipe and watch output

### "Gestures too sensitive"

Reduce scroll factor:

```lua
scroll_factor = 0.05  -- Less sensitive
```

### "Gestures too slow to trigger"

Gestures have fixed thresholds. Try:
1. Making larger, deliberate swipes
2. Checking touchpad firmware is updated
3. Testing with `libinput debug-events`

### "Only 2-finger scrolling works"

3+ finger gestures need multitouch support. Some trackpads don't support it.

Check with:
```bash
libinput list-devices | grep -A 5 "Gestures"
```

### "Gesture triggers accidentally"

Reduce gesture sensitivity by:
1. Making them less likely (change fingers needed)
2. Disabling low-value gestures
3. Using longer swipes in your usage

## Examples for Common Workflows

### Minimal Gestures (Safe)

```lua
-- Only essential, hard to trigger accidentally
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = "fullscreen" })
```

### Complete Gestures (Current)

Uses all available 3 and 4-finger gestures for full control.

### No Gestures (Keyboard-Only)

Remove all `hl.gesture` calls and use keybindings instead.

## Comparing Gestures vs Keybindings

### Gestures Pros
- Very natural on trackpad
- Great for laptop users
- No keyboard needed
- Faster than menu clicks

### Gestures Cons
- Require multitouch trackpad
- Can trigger accidentally
- Can't be combined with modifiers
- Limited action count

### Keybindings Pros
- Always work
- Precise control
- Can combine modifiers
- Work with any keyboard

### Keybindings Cons
- Require memorization
- More key presses

### Best Practice

**Combine them**: Use gestures for frequent actions on trackpad, keybindings as backup.

## Advanced: Gestures with Modifiers

Currently not supported directly in Hyprland. Workaround:

1. Use keybindings for modifier combos
2. Use gestures for simple actions
3. Create scripts triggered by keybindings

Example script:
```bash
#!/bin/bash
# Usage: ./action.sh action_type
case "$1" in
  "workspace-next")
    hyprctl dispatch workspace e+1
    ;;
  "special-toggle")
    hyprctl dispatch togglespecialworkspace
    ;;
esac
```

## Calibration

No calibration needed for gestures. They work automatically if your trackpad supports multitouch.

To test trackpad support:
```bash
# Install if needed
sudo pacman -S libinput

# Test
libinput debug-events
# Perform 3-finger swipe
```

If you see "GESTURE" events in output, multitouch is working.

## Performance

Gestures have zero performance impact:
- Handled by input device firmware
- Don't use CPU
- No latency

Safe to use even on low-power systems.

## Next Steps

- Learn [Keybindings Guide](./02_KEYBINDINGS.md) for keyboard control
- See [Input Devices Guide](./05_INPUT_DEVICES.md) for touchpad settings
- Check [Advanced Customization](./08_ADVANCED.md) for advanced gesture scripting
