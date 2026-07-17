# 01 - Animations Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Understanding Animations in Hyprland

This configuration uses smooth, professional animations to make window transitions and workspace changes feel fluid and responsive. Animations are powered by **Bezier curves** and the **golden ratio** for natural-feeling motion.

## Animation Types

### What Gets Animated?

The configuration animates:

- **windowsIn**: When windows open
- **windowsOut**: When windows close
- **windowsMove**: When windows are moved around
- **workspaces**: When switching between workspaces
- **layers**: UI elements like panels and notifications
- **specialWorkspace**: The hidden scratchpad workspace
- **fadePopups**: Small floating notifications and tooltips

## Bezier Curves Explained

Animations use **Bezier curves** to control speed and smoothness. Think of it like:

- A straight line = constant speed (boring)
- A curved line = speed changes for natural motion

### The Curves in Your Config

This configuration uses the **golden ratio (φ)** for curve calculations:

```lua
local phi = 1.618       -- Golden ratio
local phi_min = 0.618   -- Inverse golden ratio

hl.curve("default", { type = "bezier", points = { { 0, 1 }, { 0, 1 } } })
hl.curve("wind", { type = "bezier", points = { { 0.05, phi_min }, { 0.1, 1 } } })
hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, 1 }, { 0, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })
hl.curve("ease", { type = "bezier", points = { { 0, 1 }, { phi_min, 1 } } })
```

- **default**: Neutral animation (no acceleration)
- **wind**: Springy, bouncy motion (using golden ratio)
- **winIn**: Bouncy entrance animation
- **winOut**: Bouncy exit animation
- **ease**: Smooth deceleration
- **linear**: Constant speed throughout

## Animation Settings

### Duration (Speed) - Golden Ratio Physics

The interval uses the golden ratio for natural-feeling motion:

```lua
local phi = 1.618           -- Golden ratio (~1.618)
local phi_min = 0.618       -- Inverse (1/phi)
local interval = phi * 1    -- Current: ~1.6 seconds
```

The golden ratio creates proportionally pleasing animations that feel natural to humans.

### Customizing Animation Speed

Change the multiplier to adjust all animations:

```lua
local interval = phi * 0.5  -- Faster (0.8 seconds, more responsive)
local interval = phi * 1    -- Balanced (1.6 seconds, current)
local interval = phi * 2    -- Slower (3.2 seconds, cinematic)
```

This single value controls timing for:

- Window in/out animations
- Window movement animations
- Workspace transitions
- Layer animations
- Special workspace animations

## Animation Styles and Configuration

### Available Animation Leaf Types

Each animation can be individually configured:

```lua
hl.animation({ leaf = "windowsIn", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "layers", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = interval, bezier = curve, style = "slidevert" })
hl.animation({ leaf = "fadePopups", enabled = true, speed = interval, bezier = curve })
```

### Available Styles

- **slide**: Smooth movement across screen (windows, workspaces)
- **slidevert**: Vertical sliding (special workspace from edge)
- **fade**: Opacity fade in/out (popups, notifications)

### Disabling Animations

Disable all animations globally:

```lua
hl.config({
    animations = {
        enabled = false,
    },
})
```

Or disable specific animation types:

```lua
hl.animation({ leaf = "windowsIn", enabled = false })     -- No window open animation
hl.animation({ leaf = "windowsMove", enabled = false })   -- Windows move instantly
hl.animation({ leaf = "workspaces", enabled = false })    -- Workspace switches instantly
```

## Performance Tips

### Animations Can Impact Performance On:

- Old integrated graphics
- Older CPUs
- Laptops with battery concerns

### Optimization

If your system struggles:

1. Reduce animation speed (make interval smaller):

   ```lua
   local interval = phi * 0.3  -- Much faster = less GPU work
   ```

2. Disable blur effects in `config/decoration.lua`:

   ```lua
   blur = {
       passes = 0,  -- Disable blur entirely
   }
   ```

3. Use simpler curves:

   ```lua
   hl.animation({ leaf = "windowsIn", enabled = true, speed = interval, bezier = "linear" })
   ```

4. Disable animations entirely:
   ```lua
   hl.config({ animations = { enabled = false } })
   ```

## Practical Examples

### Making Window Open Animation Springy

```lua
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = phi * 0.5,  -- Faster opening (0.8 seconds)
    bezier = "wind",    -- Bouncy curve
    style = "slide"
})
```

### Slow Down Workspace Transitions

```lua
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = phi * 2,     -- Slower switching (3.2 seconds)
    bezier = "ease",     -- Smooth deceleration
    style = "slide"
})
```

### Disable Only Window Movement Animation

```lua
hl.animation({
    leaf = "windowsMove",
    enabled = false  -- Windows move instantly
})
```

### Bouncy Entrance, Smooth Exit

```lua
hl.animation({ leaf = "windowsIn", bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut", bezier = "ease", style = "slide" })
```

## Common Customizations

### Professional (Fast & Responsive)

For a business-like feel with minimal visual overhead:

```lua
local interval = phi * 0.3  -- Very fast (0.5 seconds)
-- Use "linear" curve for predictable timing
hl.animation({ leaf = "windowsIn", speed = interval, bezier = "linear" })
```

### Gaming (No Distractions)

Disable animations completely for competitive advantage:

```lua
hl.config({
    animations = { enabled = false },
})
-- Or selectively disable only specific types
hl.animation({ leaf = "windowsMove", enabled = false })
```

### Cinematic (Maximum Polish)

For a luxurious, smooth, deliberate experience:

```lua
local interval = phi * 3  -- Slow and graceful (4.8 seconds)
-- Use "ease" curve for natural deceleration
hl.animation({ leaf = "windowsIn", speed = interval, bezier = "ease" })
hl.animation({ leaf = "workspaces", speed = interval, bezier = "ease" })
```

## Debugging Animations

### Preview Animation Changes

After editing `config/animations.lua`:

```bash
hyprctl reload
```

## Troubleshooting

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

## Animation Performance Notes

- **Golden Ratio**: Natural-feeling timing that's pleasing to the human eye
- **Curve Complexity**: Bezier curves have minimal CPU impact
- **Main Impact**: GPU handles rendering, not curve calculations
- **Disable if**: Very old GPU or integrated graphics struggles

## Technical Reference

### Bezier Curve Points Format

```lua
{ type = "bezier", points = { { x1, y1 }, { x2, y2 } } }
```

- `x1, y1`: First control point
- `x2, y2`: Second control point
- Start point: implicit (0, 0)
- End point: implicit (1, 1)
- Values: typically 0-1, but can exceed for bouncy effects

### Speed Parameter

The `speed` parameter controls animation duration in tenths of a second:

- **1.0** = 0.1 seconds
- **5.0** = 0.5 seconds
- Lower value = faster animation
- Higher value = slower animation

> **Tip:** The golden ratio value used in this config (`phi * 1` = ~1.618) means animations last about **1.6 seconds** — a balanced, natural feel.

## Next Steps

- Learn about [Window Management](./03_WINDOW_MANAGEMENT.md) for gaps and visual effects
- See [Visual Styling](./06_VISUAL_STYLING.md) for blur and color effects
- Check [Advanced Customization](./08_ADVANCED.md) for custom Bezier curves and physics
