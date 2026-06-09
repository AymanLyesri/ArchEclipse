# 06 - Visual Styling Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Decorating Your Windows and Interface

This guide covers colors, effects, and visual customization in Hyprland.

## Window Decoration

### Rounding Corners

Makes windows have rounded edges instead of sharp corners:

```lua
rounding = 15  -- Corner radius in pixels
```

Options:

```lua
rounding = 0   -- Sharp corners (boxy)
rounding = 10  -- Slightly rounded
rounding = 15  -- Standard (current)
rounding = 20  -- Very rounded
```

## Borders and Colors

### Border Settings

```lua
border_size = 0  -- 0 = disabled, any number = pixel width

-- Colors
active_border = "rgb(808080)"    -- Focused window border
inactive_border = "rgb(000000)"  -- Unfocused window border
```

### Enabling Visible Borders

Change in `config/general.lua`:

```lua
border_size = 2  -- Make border visible (0 currently)

-- Color examples:
active_border = "rgb(100,200,255)"    -- Light blue when focused
inactive_border = "rgb(50,50,50)"     -- Dark gray when not focused
```

### RGB Color Format

Hyprland supports **four color formats** (all are valid):

**1. Web hex** — most common:

```
"#ff0000"    = Red
"#00ff00"    = Green
"#0000ff"    = Blue
"#ff0000ff"  = Red, fully opaque (RGBA order)
```

**2. rgb() — hex or decimal:**

```
"rgb(ff0000)"     = Red (hex)
"rgb(255,0,0)"    = Red (decimal, no spaces)
"rgb(0,255,0)"    = Green (decimal)
```

**3. rgba() — with alpha channel:**

```
"rgba(ff000088)"       = Red, ~53% transparent (hex)
"rgba(255,0,0,0.933)"  = Red, 93% opaque (decimal, no spaces)
```

**4. Legacy 0x format** (ARGB order, avoid in new configs):

```
0xffff0000  = Red, fully opaque (ARGB)
```

> **Tip:** Use `"#ff0000"` or `"rgb(255,0,0)"` for simplicity. Decimal rgb/rgba values must have **no spaces** between numbers.

## Window Opacity

Controls transparency of windows:

### Active Window Opacity

```lua
active_opacity = 0.9  -- 90% opaque (slightly transparent)
active_opacity = 1.0  -- 100% opaque (fully solid)
```

### Inactive Window Opacity

```lua
inactive_opacity = 0.85  -- 85% opaque (more transparent)
```

### Fullscreen Window Opacity

```lua
fullscreen_opacity = 1  -- Fullscreen is always fully opaque
```

### Example: Transparency Effect

```lua
active_opacity = 0.85    -- Active windows slightly transparent
inactive_opacity = 0.70  -- Inactive windows very transparent
```

This creates a visual hierarchy showing which window is focused.

## Window Dimming

Darkens inactive windows to show focus:

```lua
dim_inactive = true   -- Enable dimming
dim_strength = 0.1    -- 0 = no dimming, 1 = very dark
```

### Dimming Examples

```lua
dim_strength = 0.05   -- Subtle (barely noticeable)
dim_strength = 0.1    -- Standard (current)
dim_strength = 0.2    -- Strong (very obvious)
dim_strength = 0.3    -- Heavy (almost dark)
```

**Effect**: Inactive windows become slightly darker, making focused window stand out

## Blur Effects

Applies Gaussian blur to window backgrounds:

### Blur Settings

```lua
blur = {
    enabled = true,           -- Master blur toggle
    contrast = 1,             -- Blur contrast (0.5 - 1.5)
    vibrancy = 1,             -- Color vibrancy (0 - 2)
    new_optimizations = true, -- Use newer, faster algorithm
    ignore_opacity = true,    -- Blur ignores window opacity
    popups = true,            -- Blur dropdown menus/tooltips
    popups_ignorealpha = 0.97,-- Blur only mostly opaque popups
    input_methods = true,     -- Blur input method windows
    size = 4,                 -- Blur strength (1 - 20)
    passes = 4,               -- Number of blur passes (1 - 10)
}
```

### Blur Strength (size)

```lua
size = 2   -- Light blur (less CPU)
size = 4   -- Medium blur (current)
size = 8   -- Heavy blur (more CPU)
```

### Blur Passes

Number of times blur is applied (stacked):

```lua
passes = 2   -- Fast (less blur)
passes = 4   -- Balanced (current)
passes = 8   -- Maximum blur (heavy CPU)
```

**More passes = more blurred but slower**
**Blur can significantly impact battery life and GPU usage on laptops.**

### Disabling Blur

```lua
blur = { passes = 0 }  -- Disable all blur
```

## Contrast and Vibrancy

Fine-tune blur appearance:

### Contrast

```lua
contrast = 0.8   -- Less contrasty
contrast = 1.0   -- Normal (current)
contrast = 1.2   -- More contrasty
```

### Vibrancy

Color intensity of blurred area:

```lua
vibrancy = 0.5   -- Muted colors
vibrancy = 1.0   -- Normal (current)
vibrancy = 2.0   -- Very vibrant
```

## Window Shadows

Subtle drop shadows behind windows:

```lua
shadow = {
    enabled = true,      -- Master shadow toggle
    range = 15,          -- Shadow size (5 - 50 pixels)
    render_power = 3,    -- Shadow darkness (1 - 4)
}
```

### Shadow Examples

```lua
-- No shadows (flat look)
shadow = { enabled = false }

-- Subtle (barely visible)
shadow = { range = 5, render_power = 1 }

-- Standard (current)
shadow = { range = 15, render_power = 3 }

-- Strong (very obvious)
shadow = { range = 25, render_power = 4 }
```

## Layer Rules for UI Elements

Apply styling to specific UI layers (bars, panels, popups):

### Applying Blur to UI

```lua
hl.layer_rule({ match = { namespace = "bar" }, blur = true })
hl.layer_rule({ match = { namespace = "notification-popups" }, blur = true })
hl.layer_rule({ match = { namespace = "app-launcher" }, blur = true })
```

### Animation Styles

```lua
hl.layer_rule({ match = { namespace = "user-panel" }, animation = "fade" })
```

## Screen Lock Styling

Configure `hyprlock.conf` for lock screen appearance:

```conf
background {
    path = $HOME/.config/wallpapers/lockscreen/wallpaper
    color = rgba(25, 20, 20, 1.0)  -- Fallback color

    blur_passes = 1      -- Number of blur passes
    blur_size = 1        -- Blur strength
    brightness = 0.3     -- Darkening level
    contrast = 0.69      -- Contrast amount
    vibrancy = 0         -- Color vibrancy
}
```

## Color Schemes

### Light Theme

```lua
active_border = "rgb(50,50,150)"     -- Blue
inactive_border = "rgb(200,200,200)" -- Light gray
dim_inactive = false                    -- No dimming
```

### Dark Theme (Current)

```lua
active_border = "rgb(128, 128, 128)"   -- Gray
inactive_border = "rgb(0, 0, 0)"       -- Black
dim_inactive = true                     -- Dimming enabled
```

### Minimal Theme

```lua
border_size = 0                 -- No visible borders
rounding = 0                    -- Sharp corners
dim_inactive = false            -- No dimming
active_opacity = 1.0            -- No transparency
blur = { passes = 0 }           -- No blur
shadow = { enabled = false }    -- No shadows
```

### Minimal with Subtle Effects

```lua
border_size = 1
rounding = 5
dim_inactive = true
dim_strength = 0.05
active_opacity = 0.95
inactive_opacity = 0.9
blur = { size = 2, passes = 2 }
shadow = { range = 8, render_power = 2 }
```

### Gaming Theme (Maximum Performance)

```lua
border_size = 0
rounding = 0
dim_inactive = false
active_opacity = 1.0
inactive_opacity = 1.0
blur = { passes = 0 }
shadow = { enabled = false }
-- Disable animations in config/animations.lua
```

## Creating Custom Themes

### Step 1: Choose Base Colors

```lua
local primary = "rgb(100,150,255)"    -- Accent color
local active = "rgb(200,200,200)"     -- Active window
local inactive = "rgb(100,100,100)"   -- Inactive window
local bg = "rgb(30,30,30)"            -- Background tint
```

### Step 2: Apply to Config

Edit `config/decoration.lua`:

```lua
col = {
    active_border = active,
    inactive_border = inactive,
}
```

### Step 3: Add Effects

```lua
blur = { size = 4, passes = 4 }
shadow = { range = 15, render_power = 3 }
dim_inactive = true
dim_strength = 0.1
```

## Wallpaper Integration

Hyprpaper manages desktop wallpaper. Configure in `hyprpaper.conf`:

```conf
preload = $HOME/.config/wallpapers/background.png
wallpaper = DP-1,$HOME/.config/wallpapers/background.png
```

The blur effect uses your wallpaper as a base for the blur.

## Performance Optimization

### If Your System Struggles:

1. **Disable blur**:

   ```lua
   blur = { passes = 0 }
   ```

2. **Reduce blur quality**:

   ```lua
   blur = { size = 2, passes = 2 }
   ```

3. **Disable shadows**:

   ```lua
   shadow = { enabled = false }
   ```

4. **Disable dimming**:

   ```lua
   dim_inactive = false
   ```

5. **Disable corner rounding**:
   ```lua
   rounding = 0
   ```

### GPU Impact (Highest to Lowest)

1. Blur + shadows + dimming (most intensive)
2. Blur alone
3. Shadows alone
4. Dimming alone
5. Border/rounding (minimal impact)

## Lock Screen Customization

Edit `hyprlock.conf`:

### Input Field Styling

```conf
input-field {
    size = 200, 50              -- Width x Height
    outline_thickness = 3       -- Border thickness

    outer_color = rgb(151515)   -- Border color
    inner_color = rgb(1,1,1)  -- Background color
    font_color = rgb(200,200,200)  -- Text color

    check_color = rgb(204,136,34)  -- Correct password color
    fail_color = rgb(204,34,34)    -- Wrong password color

    position = 0, -20           -- X, Y offset from center
    rounding = -1               -- -1 = fully rounded (oval)
}
```

## Practical Themes

### Professional Office

```lua
border_size = 0
rounding = 5
dim_inactive = false
blur = { size = 2, passes = 2 }
shadow = { range = 8 }
```

### Creative/Dark

```lua
border_size = 2
active_border = "rgb(100,200,255)"
rounding = 10
blur = { size = 6, passes = 4 }
shadow = { range = 20, render_power = 4 }
```

### Cyberpunk

```lua
active_border = "rgb(0,255,255)"      -- Cyan
inactive_border = "rgb(255,0,255)"    -- Magenta
rounding = 0
dim_inactive = true
dim_strength = 0.3
blur = { size = 8, passes = 6 }
```

## Testing Changes

After editing decoration settings:

```bash
# Reload configuration
hyprctl reload

# View current settings
hyprctl getoption decoration:rounding
hyprctl getoption decoration:blur:enabled
```

## Troubleshooting

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

## Next Steps

- See [Animations Guide](./01_ANIMATIONS.md) for smooth transitions
- Learn [Window Management](./03_WINDOW_MANAGEMENT.md) for gap and layout effects
- Check [Advanced Customization](./08_ADVANCED.md) for shader effects
