# 04 - Display Configuration Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Understanding Monitors and Displays

This guide covers setting up multiple monitors, display arrangement, and resolution configuration in Hyprland.

## Basic Monitor Setup

### Default Configuration

In `config/monitor.lua`:

```lua
hl.monitor({
    output = "",           -- Empty = applies to all monitors
    mode = "highres",      -- Use highest resolution
    position = "auto",     -- Automatic placement
    scale = 1,             -- 1 = no scaling
})
```

### Specific Monitor Configuration

For individual monitors:

```lua
hl.monitor({
    output = "HDMI-A-1",   -- Monitor name
    mode = "1920x1080@60", -- Resolution and refresh rate
    position = "1920 0",   -- X Y coordinates
    scale = 1,
})
```

## Getting Monitor Information

### List Connected Monitors

```bash
hyprctl monitors -j | jq '.'
```

This shows:
- Monitor names (e.g., "HDMI-A-1", "DP-1")
- Current resolution
- Refresh rates
- Position

### Example Output

```
HDMI-A-1 - 1920x1080@60Hz at 0,0
DP-1 - 2560x1440@144Hz at 1920,0
eDP-1 - 1920x1080@60Hz at 4480,0
```

## Monitor Names

Common names depend on connection type:

```
HDMI connections:    HDMI-A-1, HDMI-A-2
DisplayPort:         DP-1, DP-2, DP-3
Laptop screen:       eDP-1
VGA (older):         VGA-1
USB-C:               DP-4-1
```

## Resolution and Refresh Rate

### Resolution Modes

```lua
-- Use highest available
mode = "highres"

-- Specific resolution
mode = "1920x1080"

-- With refresh rate
mode = "1920x1080@60"   -- 60 Hz
mode = "1920x1080@144"  -- 144 Hz (for gaming)

-- List available: hyprctl monitors
```

### Common Resolutions

```
1920x1080    (Full HD, 16:9)
2560x1440    (QHD, 16:9)
3840x2160    (4K, 16:9)
1920x1200    (WUXGA, 16:10)
1440x900     (1440p, 16:10)
```

### Refresh Rates

```
60 Hz        Standard (smooth for daily use)
75 Hz        Better smoothness
120 Hz       High refresh (better animations)
144 Hz       Gaming grade
240 Hz       Professional gaming
```

**Higher = smoother but uses more power**

## Monitor Positioning

### Coordinate System

```
Screen dimensions:
┌──────────────────┬──────────────────┐
│ (0, 0)           │                  │
│                  │                  │
│  Monitor 1       │  Monitor 2       │
│  (1920x1080)     │  (1920x1080)     │
│                  │                  │
│                  │  (1920, 0)       │
└──────────────────┴──────────────────┘
                   (1920, 0)
```

### Setting Position

```lua
-- Monitor 1 (left)
hl.monitor({
    output = "HDMI-A-1",
    position = "0 0",      -- Top left
    mode = "1920x1080@60",
})

-- Monitor 2 (right)
hl.monitor({
    output = "DP-1",
    position = "1920 0",   -- Starts where Monitor 1 ends
    mode = "1920x1080@60",
})

-- Monitor 3 (below left)
hl.monitor({
    output = "eDP-1",
    position = "0 1080",   -- Starts below Monitor 1
    mode = "1920x1080@60",
})
```

### Automatic Positioning

```lua
position = "auto"  -- Hyprland arranges automatically
```

## Display Scaling

For high-DPI monitors (like laptop screens):

```lua
-- No scaling (1x pixel mapping)
scale = 1

-- Scale up to 2x (for 4K displays)
scale = 2

-- Fractional scaling (may reduce performance)
scale = 1.5
```

**Use case**: 4K monitor at normal viewing distance needs `scale = 2`

## Multiple Monitor Example

Full setup for 3 monitors:

```lua
-- Laptop monitor (1920x1080)
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0 0",
    scale = 1,
})

-- Left external (2560x1440@144)
hl.monitor({
    output = "HDMI-A-1",
    mode = "2560x1440@144",
    position = "-2560 0",  -- Left of laptop
    scale = 1,
})

-- Right external (2560x1440@60)
hl.monitor({
    output = "DP-1",
    mode = "2560x1440@60",
    position = "1920 0",   -- Right of laptop
    scale = 1,
})
```

## Workspaces Across Monitors

By default, workspaces are shared across all monitors. You can bind workspaces to specific monitors:

```bash
# View current workspace layout
hyprctl workspaces -j | jq '.'
```

## Focusing Different Monitors

```
Focus left monitor:   SUPER + CTRL + LEFT
Focus right monitor:  SUPER + CTRL + RIGHT
Focus up monitor:     SUPER + CTRL + UP
Focus down monitor:   SUPER + CTRL + DOWN
```

## Mirror Display (Clone)

For presentations or mirroring:

```lua
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60",
    position = "0 0",
    scale = 1,
})

hl.monitor({
    output = "DP-1",
    mode = "1920x1080@60",
    position = "0 0",      -- Same position = clone
    scale = 1,
})
```

## Monitor Disconnection Handling

When an external monitor disconnects:
- Windows on that monitor move to primary
- Workspaces reassign
- Layout adjusts automatically

**No configuration needed** - Hyprland handles it

## Troubleshooting Display Issues

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

## Advanced: Per-Monitor Workspaces

Some users prefer workspaces to stay on one monitor:

This requires custom scripting (not covered in basic guide)

## Performance Tips

### High Refresh Rates

Every Hz increase uses more GPU power. On laptops:
- Use `60` for battery life
- Use `120-144` for gaming
- Monitor draws more power at higher Hz

### Resolution Selection

```
1920x1080 = Balanced (most common)
2560x1440 = More screen space, uses more GPU
3840x2160 = 4K (for large monitors only)
1024x768  = For older hardware
```

### Multiple Monitors Impact

Each monitor increases GPU load. With 3 monitors:
- Disable blur effects
- Reduce animation quality
- Use lower refresh rates

## Next Steps

- See [Input Devices Guide](./05_INPUT_DEVICES.md) for mouse/keyboard
- Learn [Visual Styling](./06_VISUAL_STYLING.md) for per-monitor themes
- Check [Advanced Customization](./08_ADVANCED.md) for dynamic monitor configuration
