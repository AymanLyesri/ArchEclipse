# 03 - Window Management Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## Understanding Window Management in Hyprland

Hyprland automatically manages windows using a tiling system. Unlike floating window managers where you manually drag windows, Hyprland positions windows in a grid layout.

## Window States

### Tiled (Default)

Windows snap to a grid and fill available space:

```
┌─────────────┬─────────────┐
│             │             │
│  Window 1   │  Window 2   │
│             │             │
├─────────────┼─────────────┤
│             │             │
│  Window 3   │  Window 4   │
│             │             │
└─────────────┴─────────────┘
```

### Floating

Windows can overlap and move freely:

```
        ┌──────────────────┐
        │   Window 1       │ (can move)
        │  (overlapping)   │
    ┌───┼──────────────────┤
    │   └──────────────────┘
    │   Window 2
    │
```

**Toggle floating**: `SUPER` + `Space`

### Fullscreen

Window takes the entire screen:

```
┌────────────────────────────┐
│                            │
│       Window 1             │
│    (entire screen)         │
│                            │
│                            │
└────────────────────────────┘
```

**Toggle fullscreen**: `SUPER` + `F`

### Pinned

Window appears on ALL workspaces:

```
Workspace 1: [Pinned Window] [App 1] [App 2]
Workspace 2: [Pinned Window] [App 3] [App 4]
Workspace 3: [Pinned Window] [App 5] [App 6]
```

**Toggle pin**: `SUPER` + `CTRL` + `Space`

**Use case**: Floating terminal on every workspace

## Layouts

Your configuration uses two main layouts:

### Dwindle Layout (Default)

A spiral tiling pattern - new windows split the current window:

```
Original:        After adding windows:
┌──────┐        ┌─────┬─────┐
│      │        │  1  │  2  │
│  1   │  --->  │─────┼─────┤
│      │        │  3  │  4  │
└──────┘        └─────┴─────┘
```

### Master Layout

One main window on the left, others stacked on the right:

```
┌──────────────┬────────┐
│              │   2    │
│      1       ├────────┤
│   (Master)   │   3    │
│              ├────────┤
│              │   4    │
└──────────────┴────────┘
```

**Switch layouts**: Edit `config/layouts.lua` and change `layout = "dwindle"` to `layout = "master"`

## Window Rules

Window rules are preset configurations for specific applications. They determine:
- Which workspace an app opens in
- Whether it starts floating
- Size and position
- Opacity settings

### Current Rules

Here are rules applied to specific applications:

#### Always Floating

These apps always open floating:
- Polkit authentication dialogs
- Network Manager dialogs
- Image viewers (Viewnior, feh)
- Audio/Volume controls (pavucontrol)
- Theme settings (nwg-look, qt5ct)
- Video player (mpv)
- Rofi launcher

#### Workspace Assignment

```
Spotify       → Workspace 4
Steam         → Workspace 7
Lutris        → Workspace 7
Steam Games   → Workspace 10
Windows .exe  → Workspace 10
Minecraft     → Workspace 10
```

#### Opacity Override

Games get full opacity (1.0) to prevent transparency bugs:
- Steam games
- Windows apps
- Emulators

### Adding a New Window Rule

Edit `config/windowrule.lua`:

**Example: Make Firefox always open in workspace 2**

```lua
hl.window_rule({
    match = { class = "^(firefox)$" },
    workspace = "2 silent",  -- "silent" = no animation
})
```

**Example: Float a specific app**

```lua
hl.window_rule({
    match = { class = "^(my-app)$" },
    float = true,
})
```

**Example: Set app size when floating**

```lua
hl.window_rule({
    match = { class = "^(calculator)$" },
    float = true,
    size = "600 400",  -- Width x Height
    move = "cursor 0 0",  -- Position at cursor
})
```

### Window Rule Options

Common options you can use:

```lua
-- Workspace
workspace = "5 silent"

-- Floating/Tiled
float = true
float = false

-- Position/Size (for floating)
move = "100 200"  -- X Y coordinates
move = "cursor -50% -50%"  -- Centered on cursor
size = "800 600"  -- Width Height

-- Opacity
opacity = "1 override 1 override"  -- Full opacity, no dimming

-- Pinning
pin = true

-- Animation
animation = "fade"

-- Blur
blur = true
```

## Resizing Windows

### Manual Resize

Hold `SUPER + SHIFT` + arrow keys:

```
→ Makes window wider
← Makes window narrower  
↑ Makes window taller
↓ Makes window shorter
```

### Resize on Border

Hover over a window edge and resize by dragging:

This is enabled in `config/general.lua`:
```lua
resize_on_border = true
```

### Resize Snap

When resizing, windows snap to grid:

```lua
snap = {
    enabled = true,  -- Snap to neighboring windows
}
```

## Moving Windows

### Between Workspaces

```
Move to workspace 1:  SUPER + CTRL + 1
Move to workspace 2:  SUPER + CTRL + 2
etc...
```

### Between Monitors

If you have multiple monitors, move with arrow keys:

```
SUPER + CTRL + LEFT  = Move to left monitor
SUPER + CTRL + RIGHT = Move to right monitor
```

### Manual Drag

Floating windows: `SUPER` + Left click + drag

## Focus and Navigation

### Basic Navigation

```
SUPER + arrow keys = Navigate between windows
SUPER + H/N/C/T = Dvorak navigation
```

### Focus Modes

#### Follow Mouse

When enabled, focus follows mouse cursor:

```lua
follow_mouse = 1  -- In config/input.lua
```

### Window Cycling

```
SUPER + Tab = Switch to previous workspace
SUPER + mouse wheel = Cycle through workspaces
```

## Gaps and Borders

### Inner Gaps

Space between windows inside the same workspace:

```lua
gaps_in = 7  -- Pixels between windows
```

Larger value = more separation

### Outer Gaps

Space between windows and screen edges:

```lua
gaps_out = 10  -- Pixels from edge
```

### Borders

Windows have borders that highlight focus:

```lua
border_size = 0  -- 0 = disabled, >0 = pixels
active_border = "rgb(808080)"  -- Focused window border
inactive_border = "rgb(000000)"  -- Unfocused window border
```

## Special Workspace

The special workspace is a hidden area accessible anywhere:

### Using It

```
Toggle special workspace: SUPER + S
Move window to special:   SUPER + CTRL + S
```

### Practical Uses

- Floating terminal always available
- Media player controls
- System monitor window
- Temporary notes

### Configuration

In `config/workspace.lua`:

```lua
hl.workspace_rule({
    workspace = "special:special",
    on_created_empty = "kitty",  -- Spawn this when first opened
})
```

## Window Dimming

Inactive (unfocused) windows are slightly dimmed:

```lua
dim_inactive = true  -- Enable dimming
dim_strength = 0.1   -- 0-1, higher = darker
```

This helps focus on the active window.

## Opacity Settings

### Active Window

```lua
active_opacity = 0.9  -- 90% opaque
```

### Inactive Window

```lua
inactive_opacity = 0.85  -- 85% opaque
```

### Fullscreen

```lua
fullscreen_opacity = 1  -- 100% opaque (no transparency)
```

## Window Rounding

Corners are slightly rounded for modern aesthetic:

```lua
rounding = 15  -- Pixels for corner radius
```

## Blur Effects

Inactive windows have a slight blur effect:

```lua
blur = {
    size = 4,      -- Blur strength
    passes = 4,    -- Number of blur passes
    popups = true, -- Blur tooltips/menus
}
```

## Shadows

Windows cast subtle shadows:

```lua
shadow = {
    enabled = true,
    range = 15,      -- Shadow size in pixels
    render_power = 3,  -- Shadow darkness (1-4)
}
```

## Practical Examples

### Professional Setup

Minimal distractions:

```lua
gaps_in = 0
gaps_out = 0
border_size = 0
dim_inactive = false
active_opacity = 1
inactive_opacity = 1
rounding = 0
```

### Cozy Setup

Maximum comfort:

```lua
gaps_in = 15
gaps_out = 20
border_size = 3
dim_inactive = true
dim_strength = 0.2
active_opacity = 0.95
inactive_opacity = 0.8
rounding = 20
```

### Gaming Setup

Full performance:

```lua
-- Disable blur, shadows, dimming
blur = { passes = 0 }
shadow = { enabled = false }
dim_inactive = false
rounding = 0
```

## Troubleshooting

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

## Next Steps

- See [Keybindings Guide](./02_KEYBINDINGS.md) for navigation commands
- Learn about [Visual Styling](./06_VISUAL_STYLING.md) for colors and effects
- Check [Advanced Customization](./08_ADVANCED.md) for complex window rules
