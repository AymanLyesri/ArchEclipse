# 99 - TROUBLESHOOTING

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## General Troubleshooting

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

## Animation Troubleshooting

### Animations Are Choppy
- Check GPU drivers are updated
- Reduce animation speed (smaller interval value)
- Lower blur passes in decoration config

### Animations Not Smooth
- Check monitor refresh rate: `hyprctl monitors`
- Ensure animation speed matches your monitor (60Hz vs 144Hz)

### Animations Won't Disable
- Restart Hyprland: `hyprctl reload`
- Check `enabled = false` is in correct section

## Keybindings Troubleshooting

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

## Window Troubleshooting

### "Window opened in wrong workspace"

Check `windowrule.lua` for conflicting rules. Windows follow the first matching rule.

### "Can't resize window"

- Is it fullscreen? Press `SUPER` + `F` to exit
- Is it maximized? Some apps have their own maximize
- Try `SUPER + SHIFT + arrow` keys

### "Window won't float"

- Check it's not in a fullscreen group
- Check `windowrule.lua` isn't forcing it tiled
- Check app-specific window rules

### "Gaps disappeared"

- Check `config/general.lua` for `gaps_in` and `gaps_out`
- If set to 0, they won't show
- Reload: `hyprctl reload`

## Display Troubleshooting

### "Monitor not detected"

1. Check connection
2. List monitors: `hyprctl monitors -j`
3. If still not showing, check cable/GPU drivers. Force a mode in config:
   ```lua
   hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "auto", scale = 1 })
   ```
   Then reload: `hyprctl reload`

### "Wrong resolution set"

1. Check available modes: `hyprctl monitors`
2. Verify in config: is name spelled correctly?
3. Reload: `hyprctl reload`

### "Monitors duplicated in config"

Each monitor in config file creates a rule. The first match wins. Remove duplicates:

```bash
grep "output =" ~/.config/hypr/config/monitor.lua
```

### "Can't see workspace on monitor"

- Check workspaces are created: `hyprctl workspaces`
- Switch to workspace: `SUPER + 1`
- Monitor may be sleeping: move mouse to wake

### "Text looks blurry"

- Check scaling value: should be whole numbers (1, 2)
- Fractional scaling (1.5) can cause blur
- Some apps don't support scaling

### "High refresh rate not working"

1. Check monitor supports it: `hyprctl monitors`
2. Cable may be limiting (use certified cables)
3. GPU may need driver update
4. Try: `mode = "1920x1080@60"` first, then increase

## Input Troubleshooting

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

## Visual Troubleshooting

### "Blur is very slow"

1. Reduce passes: `passes = 2`
2. Reduce size: `size = 2`
3. Disable entirely: `passes = 0`

### "Shadows look weird"

- Try different `render_power`: 1, 2, 3, 4
- Adjust `range`: bigger for softer

### "Colors look wrong"

- Use any valid format: `"#ff0000"`, `"rgb(255,0,0)"` or `"rgb(ff0000)"`
- Note: decimal rgb/rgba values must have **no spaces** between numbers: `"rgb(255,0,0)"` ✓ vs `"rgb(255, 0, 0)"` ✗

### "Lock screen has wrong colors"

- Edit `hyprlock.conf`
- Use same RGB format
- Reload: `hyprctl reload`

## Gestures Troubleshooting

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

## Advanced Configs Troubleshooting

### Common Lua Errors

```lua
-- Error: attempt to index nil value
-- Fix: Make sure variable is defined before using
local x = x or 0  -- Provide default

-- Error: bad argument to 'pairs'
-- Fix: Make sure table exists
local t = t or {}

-- Error: attempt to concatenate
-- Fix: Convert to string
local result = tostring(value) .. " text"
```

### Testing Configuration Changes

```bash
# Reload without restarting
hyprctl reload

# Test script syntax
luac -p ~/.config/hypr/hyprland.lua 2>&1 | head

# Or use syntax checker
# If command not found, install the luacheck package: sudo pacman -S luacheck
luacheck ~/.config/hypr/hyprland.lua 2>&1 | head

# Hyprland checker
hyprctl configerrors

# Hyprland logs
hyprctl rollinglog -f
```
