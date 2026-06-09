# 08 - Advanced Customization Guide

## Part of **Arch Eclipse** by AymanLyesri

> **Note:** This documentation is part of the [**Arch Eclipse**](https://github.com/AymanLyesri/ArchEclipse) project by **AymanLyesri**.

## For Power Users and Developers

This guide covers advanced configuration topics for experienced Hyprland users.

## Lua Configuration Deep Dive

### Understanding the Lua API

Your configuration uses a Lua API provided by Hyprland:

```lua
-- Configuration objects
hl.config({ ... })      -- Main configuration block
hl.bind(...)           -- Keybinding
hl.gesture(...)        -- Gesture configuration
hl.monitor(...)        -- Monitor setup
hl.device(...)         -- Input device
hl.env(...)            -- Environment variable
hl.animation(...)      -- Animation definition
hl.curve(...)          -- Bezier curve
hl.window_rule(...)    -- Window rule
hl.layer_rule(...)     -- Layer rule
hl.workspace_rule(...) -- Workspace rule
hl.on(...)             -- Event listener
hl.exec_cmd(...)       -- Execute command
```

### Dispatch Commands

Hyprland actions are dispatches accessible via `hl.dsp`:

```lua
hl.dsp.window.fullscreen({ action = "toggle" })
hl.dsp.window.close()
hl.dsp.window.float({ action = "toggle" })
hl.dsp.window.move({ workspace = 5 })
hl.dsp.window.resize({ x = 50, y = 0, relative = true })
hl.dsp.focus({ direction = "left" })
hl.dsp.focus({ workspace = 3 })
hl.dsp.workspace.toggle_special()
hl.dsp.exec_cmd("command here")
```

## Creating Custom Modules

### Module Organization

Create reusable configurations:

```lua
-- File: config/custom/gaming.lua
return {
    setup = function()
        hl.config({
            misc = {
                enable_swallow = false,
                mouse_move_enables_dpms = false,
            }
        })
        
        -- Gaming-specific keybindings
        hl.bind("ALT + G", hl.dsp.exec_cmd("discord"))
    end
}

-- In hyprland.lua, load it:
-- require("config.custom.gaming").setup()
```

## Event Handling

React to Hyprland events using `hl.on(event_name, callback)`. Event names use **dot-notation** introduced in Hyprland 0.55.

### Complete Event List (Hyprland 0.55)

**Window events** — callback receives `HL.Window` object (or two objects where noted):

| Event name                   | Trigger                             | Callback args       |
|------------------------------|-------------------------------------|---------------------|
| `"window.open"`              | Window mapped (opened)              | `window`            |
| `"window.open_early"`        | Window mapped, before rules applied | `window`            |
| `"window.close"`             | Window unmapped (closed)            | `window`            |
| `"window.destroy"`           | Window fully destroyed              | `window`            |
| `"window.kill"`              | Window killed                       | `window`            |
| `"window.active"`            | Active/focused window changes       | `window, reason`    |
| `"window.urgent"`            | Window requests urgent attention    | `window`            |
| `"window.title"`             | Window title changes                | `window`            |
| `"window.class"`             | Window class changes                | `window`            |
| `"window.pin"`               | Window pin state changes            | `window`            |
| `"window.fullscreen"`        | Window fullscreen state changes     | `window`            |
| `"window.update_rules"`      | Window rules are re-evaluated       | `window`            |
| `"window.move_to_workspace"` | Window moves to another workspace   | `window, workspace` |

**Workspace events** — callback receives `HL.Workspace`:

| Event name                    | Trigger                            | Callback args        |
|-------------------------------|------------------------------------|----------------------|
| `"workspace.active"`          | Active workspace changes           | `workspace`          |
| `"workspace.created"`         | New workspace created              | `workspace`          |
| `"workspace.removed"`         | Workspace removed                  | `workspace`          |
| `"workspace.move_to_monitor"` | Workspace moves to another monitor | `workspace, monitor` |

**Monitor events** — callback receives `HL.Monitor`:

| Event name                 | Trigger                | Callback args |
|----------------------------|------------------------|---------------|
| `"monitor.added"`          | Monitor connected      | `monitor`     |
| `"monitor.removed"`        | Monitor disconnected   | `monitor`     |
| `"monitor.focused"`        | Monitor focus changes  | `monitor`     |
| `"monitor.layout_changed"` | Monitor layout changes | *(none)*      |

**Layer surface events**:

| Event name       | Trigger                                       | Callback args   |
|------------------|-----------------------------------------------|-----------------|
| `"layer.opened"` | Layer surface mapped (e.g. a bar/panel opens) | `layer_surface` |
| `"layer.closed"` | Layer surface unmapped                        | `layer_surface` |

**System events**:

| Event name            | Trigger                                            | Callback args                   |
|-----------------------|----------------------------------------------------|---------------------------------|
| `"hyprland.start"`    | Hyprland started (**once** at boot, not on reload) | *(none)*                        |
| `"hyprland.shutdown"` | Hyprland is shutting down                          | *(none)*                        |
| `"config.reloaded"`   | Config was reloaded                                | *(none)*                        |
| `"keybinds.submap"`   | Submap changes                                     | `submap_name` (string)          |
| `"screenshare.state"` | Screensharing state changes                        | `active` (bool), `type`, `name` |

### Examples

```lua
-- Startup: run apps once at boot
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
end)

-- React to focused window changing
hl.on("window.active", function(w)
    if w ~= nil then
        print("Focused: " .. w.title .. " (" .. w.class .. ")")
    end
end)

-- React to window being closed
hl.on("window.close", function(w)
    print("Closed: " .. w.title)
end)

-- React to workspace switch
hl.on("workspace.active", function(ws)
    print("Switched to workspace: " .. ws.name)
end)

-- React to monitor being plugged in
hl.on("monitor.added", function(mon)
    print("Monitor connected: " .. mon.name)
end)
```

## Advanced Bezier Curves

### Understanding Bezier Mathematics

A cubic Bezier curve is defined by 4 points:
- P0: Start (0, 0)
- P1: Control point 1
- P2: Control point 2
- P3: End (1, 1)

In Hyprland, you only define P1 and P2:

```lua
hl.curve("custom", {
    type = "bezier",
    points = { { x1, y1 }, { x2, y2 } }
})
```

### Creating Custom Curves

**Bouncy curve** (spring-like):
```lua
hl.curve("bouncy", { 
    type = "bezier", 
    points = { { 0.1, 1.3 }, { 0.2, 0.8 } } 
})
```

**Smooth deceleration** (easing out):
```lua
hl.curve("smooth", {
    type = "bezier",
    points = { { 0, 1 }, { 0.5, 1 } }
})
```

**Acceleration** (easing in):
```lua
hl.curve("quick", {
    type = "bezier",
    points = { { 0.5, 0 }, { 1, 1 } }
})
```

**S-curve** (slow start, fast middle, slow end):
```lua
hl.curve("smooth-s", {
    type = "bezier",
    points = { { 0.33, 0.33 }, { 0.67, 0.67 } }
})
```

## Complex Window Rules

### Regex Pattern Matching

Window rules use regex for flexibility:

```lua
-- Match Firefox or Chrome
hl.window_rule({
    match = { class = "^(firefox|google-chrome)$" },
    workspace = "2",
})

-- Match any Steam game (numeric IDs)
hl.window_rule({
    match = { class = "^steam_app_\\d+$" },
    workspace = "10",
})

-- Match all .exe files (Windows apps)
hl.window_rule({
    match = { class = "^(.+\\.exe)$" },
    workspace = "10",
})

-- Match by title
hl.window_rule({
    match = { title = "Mozilla Firefox" },
    float = true,
})
```

### Floating Window Positioning

```lua
-- Centered on cursor
hl.window_rule({
    match = { class = "^calculator$" },
    float = true,
    move = "cursor -50% -50%",
})

-- Specific coordinates (top-right)
hl.window_rule({
    match = { class = "^notes$" },
    float = true,
    move = "100%-w-20 20",  -- 20px from right, 20px from top
})

-- Specific size and position
hl.window_rule({
    match = { class = "^settings$" },
    float = true,
    size = "800 600",
    move = "100%-840 100%-640",
})
```

## Dynamic Configuration

### Conditional Setup

```lua
local hostname = io.popen("hostname"):read()

if hostname == "laptop" then
    hl.config({
        general = {
            gaps_in = 5,
            gaps_out = 5,
        }
    })
elseif hostname == "desktop" then
    hl.config({
        general = {
            gaps_in = 10,
            gaps_out = 15,
        }
    })
end
```

### Environment-Based Configuration

```lua
local use_external_monitor = os.getenv("HYPR_EXTERNAL") == "1"

if use_external_monitor then
    hl.monitor({
        output = "HDMI-A-1",
        mode = "2560x1440@144",
        position = "0 0",
    })
else
    -- Laptop only
    hl.monitor({
        output = "eDP-1",
        mode = "1920x1080@60",
        position = "0 0",
    })
end
```

Run with:
```bash
HYPR_EXTERNAL=1 hyprland
```

## Custom Scripts Integration

### Executing Complex Actions

```lua
local home = os.getenv("HOME") or ""
local script = home .. "/.config/hypr/scripts/custom-action.sh"

hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("bash " .. script))
```

### Shell Script with Parameters

```bash
#!/bin/bash
# scripts/custom-action.sh

ACTION=$1

case "$ACTION" in
    "save-layout")
        hyprctl clients -j > ~/.config/hypr/.layout-backup.json
        notify-send "Layout saved"
        ;;
    "restore-layout")
        # Restore windows to positions
        notify-send "Layout restored"
        ;;
    *)
        echo "Unknown action: $ACTION"
        ;;
esac
```

## Performance Tuning

### Disabling Expensive Features

```lua
-- For very old hardware
hl.config({
    animations = { enabled = false },
    decoration = {
        rounding = 0,
        blur = { passes = 0 },
        shadow = { enabled = false },
        dim_inactive = false,
    },
    general = {
        gaps_in = 0,
        gaps_out = 0,
    },
})
```

### High-Performance Gaming Setup

```lua
hl.config({
    misc = {
        enable_swallow = false,
        mouse_move_enables_dpms = false,
    },
})

hl.animation({ leaf = "windowsIn", enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })
hl.animation({ leaf = "workspaces", enabled = false })
```

## Debugging Configuration

### Validate Syntax

**Check syntax**: `luac -p ~/.config/hypr/hyprland.lua` or `luacheck ~/.config/hypr/hyprland.lua` or `hyprctl configerrors`

Shows all syntax errors in your config.

### Check Current Settings

```bash
# Get specific setting
hyprctl getoption general:gaps_in

# Get all decoration settings
hyprctl getoption decoration

# Monitor all settings
hyprctl --batch 'getoption general' | jq '.'
```

### Watch for Errors

```bash
# Hyprland logs
hyprctl rollinglog -f

# Hyprland checker
hyprctl configerrors
```

## Advanced Keybinding Techniques

### Chained Keybindings

Create multi-step actions:

```lua
-- Press ALT+S twice quickly to do something
-- (Hyprland doesn't have built-in support, use external tool)
```

### Dynamic Keybindings

```lua
-- Bind keys based on conditions
if use_dvorak then
    hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + N", hl.dsp.focus({ direction = "right" }))
else
    hl.bind(mainMod .. " + LEFT", hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
end
```

### Keybinding Logging

Create a keybinding that logs to a file:

```lua
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(
    "bash -c 'echo $(date +%s) >> ~/.config/hypr/keybind.log'"
))
```

## Workspace Management Scripts

### Create Auto-Workspace Script

```bash
#!/bin/bash
# scripts/auto-workspace.sh
# Automatically move apps to workspace based on class

class=$1
workspace=$2

hyprctl --batch "dispatch movetoworkspace $workspace,^($class)$"
```

Call from config using the event name:
```lua
hl.on("window.active", function(w)
    if w.class == "firefox" then
        hl.dispatch(hl.dsp.window.move({ workspace = "1" }))
    end
end)
```

> **Note:** Use `hl.window_rule()` for static workspace assignment — it's simpler and more reliable than event hooks for this use case:
> ```lua
> hl.window_rule({ match = { class = "^firefox$" }, workspace = "1 silent" })
> ```

## Monitor Configuration Scripts

### Dynamic Monitor Setup

```bash
#!/bin/bash
# scripts/setup-monitors.sh

if hyprctl monitors | grep -q "HDMI-A-1"; then
    hyprctl --batch "monitor HDMI-A-1,2560x1440@144,0x0,1"
    HYPR_EXTERNAL=1 notify-send "External monitor detected"
else
    hyprctl --batch "monitor,1920x1080@60,0x0,1"
    notify-send "Using laptop monitor only"
fi
```

## Custom Status Bar Integration

### Update Status Based on Events

```lua
hl.on("workspace.move_to_monitor", function(ws, m)
    os.execute("bash ~/.config/hypr/scripts/update-bar.sh workspace " .. ws.name)
end)

hl.on("window.active", function(w)
    os.execute("bash ~/.config/hypr/scripts/update-bar.sh title '" .. w.title .. "'")
end)
```

## Troubleshooting Advanced Configs

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

## Resources

- **Hyprland Docs**: https://wiki.hypr.land
- **Lua Documentation**: https://www.lua.org/manual/
- **Bezier Curve Tool**: https://cubic-bezier.com
- **Color Picker**: https://colorpicker.fr

## Next Steps

- Create custom modules in `config/custom/`
- Develop integration scripts
- Share configurations with community
- Contribute improvements back to Hyprland

## Performance Benchmarking

### Hyprland Built-in Debug Overlay (FPS counter)

Hyprland has a built-in FPS/performance overlay. Enable it in `config/misc.lua` or directly in `hyprland.lua`:

```lua
hl.config({
    debug = {
        overlay = true,   -- Show FPS + frame time overlay on screen
    },
})
```

> **Note:** For accurate readings, disable VFR (Variable Frame Rate) while benchmarking:
> ```lua
> hl.config({
>     debug = { overlay = true, vfr = false },
> })
> ```
> Remember to re-enable `vfr = true` afterwards — without it Hyprland renders every frame continuously and wastes GPU power.

Temporarily enabling overlay via terminal:
```bash
hyprctl eval 'hl.config({ debug = { overlay = true, vfr = false } })' 
```

The overlay displays FPS, frame time, and other compositor metrics directly on screen.

---

### MangoHud — overlay for games and applications

[MangoHud](https://github.com/flightlessmango/MangoHud) is the standard Linux performance overlay tool, the same one built into Steam Deck. It works on top of any Vulkan/OpenGL application and shows FPS, CPU/GPU load, temperatures and more in real time.

**Install:**
```bash
sudo pacman -S mangohud lib32-mangohud
```

**Run any application with the overlay:**
```bash
mangohud <app-name>
# Examples:
mangohud firefox
mangohud glxgears
```

**For Steam games** — add to the game's launch options:
```
mangohud %command%
```

**What MangoHud shows by default:**
- FPS and frame time graph
- CPU usage (per core)
- GPU usage and VRAM
- CPU/GPU temperatures
- RAM usage

**Configure** via `~/.config/MangoHud/MangoHud.conf`:
```ini
fps
frametime
cpu_stats
gpu_stats
ram
vram
temps
position=top-left
```

---

### System Monitoring

```bash
# Hyprland process — CPU usage
top -p $(pgrep -f "Hyprland")

# GPU — NVIDIA
nvidia-smi dmon

# GPU — AMD (more detailed than nvidia-smi equivalent)
amdgpu_top
# or
radeontop

# GPU — Intel
intel_gpu_top
```

---

### Optimize Based on Metrics

| Symptom                | Likely cause           | Fix                                            |
|------------------------|------------------------|------------------------------------------------|
| Hyprland CPU > 10%     | Blur + animations      | Reduce `blur.passes`, disable animations       |
| GPU > 30% on desktop   | Blur too aggressive    | `blur = { passes = 0 }`                        |
| FPS below refresh rate | VFR accidentally off   | Check `debug.vfr = true`                       |
| Frame time spikes      | Fractional scaling     | Use integer values: `scale = 1` or `scale = 2` |
| RAM > 200MB            | Too many layer effects | Reduce `blur.size`                             |

## Contributing Back

If you create useful modules or scripts:

1. Share in Hyprland forums
2. Create GitHub gist
3. Contribute to community configs
4. Upstream useful patches to Hyprland
