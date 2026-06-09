local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"
local hyprDir = home .. "/.config/hypr"
local screenshot = scriptsDir .. "/screenshot.sh"
local screenshotAll = scriptsDir .. "/screenshot_all.sh"
local terminal = "kitty"
local menu = scriptsDir .. "/menu"
local lock = scriptsDir .. "/hyprlock.sh"
local suspend = scriptsDir .. "/hyprlock.sh suspend"
local keyboardLayout = scriptsDir .. "/dvorak-qwerty.sh"
local statusBar = scriptsDir .. "/bar.sh"
local monitor = "$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')"
local resizeAmount = 25

hl.config({
    binds = {
        workspace_back_and_forth = 1,
        allow_workspace_cycles = 1,
        pass_mouse_when_bound = 0,
    },
})

local mainMod = "SUPER"

-- ## Window Management
-- # fullscreen active window
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
-- # close active window
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- # float for active window
hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
-- # pin active window
hl.bind(mainMod .. " + CTRL + Space", hl.dsp.window.pin())

-- ## Open Apps
-- # open terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
-- # open floating terminal
hl.bind(mainMod .. " + CTRL + Return", hl.dsp.exec_cmd("[float] " .. terminal))
-- # open btop in workspace 5
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("[workspace 5] " .. terminal .. " btop"))

-- ## Status Bar and Panels
-- # start -- refresh main bar
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(statusBar))
-- # toggle app launcher
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("ags toggle app-launcher-" .. monitor))
-- # toggle media panel
hl.bind(mainMod .. " + m", hl.dsp.exec_cmd("ags toggle media-" .. monitor))
-- # toggle right panel
hl.bind(mainMod .. " + r", hl.dsp.exec_cmd("ags toggle right-panel-" .. monitor))
-- # toggle left panel
hl.bind(mainMod .. " + l", hl.dsp.exec_cmd("ags toggle left-panel-" .. monitor))
-- # toggle wallpaper switcher
hl.bind(mainMod .. " + w", hl.dsp.exec_cmd("ags toggle wallpaper-switcher-" .. monitor))
-- # toggle user panel
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("ags toggle user-panel-" .. monitor))
-- # open clipboard manager
hl.bind(mainMod .. " + SHIFT + v", hl.dsp.exec_cmd("ags request clipboard " .. monitor))
-- # open emoji picker
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("ags request emojis " .. monitor))
-- # open notes app
hl.bind(mainMod .. " + ALT + n", hl.dsp.exec_cmd("ags request notes " .. monitor))

-- ## Screenshot and Screen Record Keybinds
-- # screenshot workspace
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " --now"))
-- # screenshot area
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " --area"))
-- # screen record workspace
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(scriptsDir .. "/screenrecord.sh --now"))
-- # screen record area
hl.bind(mainMod .. " + CTRL + SHIFT + R", hl.dsp.exec_cmd(scriptsDir .. "/screenrecord.sh --area"))

-- ## Special Workspace Keybinds
-- # move to special workspace
hl.bind(mainMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special" }))
-- # toggle special workspace
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special())

hl.bind("ALT + F10", hl.dsp.exec_cmd(keyboardLayout))

-- ## Media, Brightness and Volume Controls
-- # volume up
hl.bind("ALT + F12", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
-- # volume down
hl.bind("ALT + F11", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
-- # volume up
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
-- # volume down
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- # brightness up
hl.bind("ALT + F3", hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
-- # brightness down
hl.bind("ALT + F2", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })
-- # brightness up
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
-- # brightness down
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })

-- ## System Controls
-- # lock
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd(lock))
-- # suspend
hl.bind(mainMod .. " + CTRL + Escape", hl.dsp.exec_cmd(suspend))
-- # shutdown
hl.bind(mainMod .. " + CTRL + SHIFT + Escape", hl.dsp.exec_cmd("shutdown now"))

-- ## Window Resize, Move and Focus
-- # expand left
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -resizeAmount, y = 0, relative = true }),
    { repeating = true })
-- # expand left
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.resize({ x = -resizeAmount, y = 0, relative = true }),
    { repeating = true })

-- # expand right
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = resizeAmount, y = 0, relative = true }),
    { repeating = true })
-- # expand right
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.resize({ x = resizeAmount, y = 0, relative = true }),
    { repeating = true })
-- # expand up
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -resizeAmount, relative = true }),
    { repeating = true })
-- # expand up
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.resize({ x = 0, y = -resizeAmount, relative = true }),
    { repeating = true })
-- # expand down
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = resizeAmount, relative = true }),
    { repeating = true })
-- # expand down
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.resize({ x = 0, y = resizeAmount, relative = true }),
    { repeating = true })

-- # move left
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({ direction = "l" }))
-- # move right
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
-- # move up
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({ direction = "u" }))
-- # move down
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({ direction = "d" }))

-- # move left
hl.bind(mainMod .. " + CTRL + h", hl.dsp.window.move({ direction = "l" }))
-- # move right
hl.bind(mainMod .. " + CTRL + n", hl.dsp.window.move({ direction = "r" }))
-- # move up
hl.bind(mainMod .. " + CTRL + c", hl.dsp.window.move({ direction = "u" }))
-- # move down
hl.bind(mainMod .. " + CTRL + t", hl.dsp.window.move({ direction = "d" }))

-- # focus left
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
-- # focus right
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
-- # focus up
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
-- # focus down
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- # focus left
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
-- # focus right
hl.bind(mainMod .. " + n", hl.dsp.focus({ direction = "right" }))
-- # focus up
hl.bind(mainMod .. " + c", hl.dsp.focus({ direction = "up" }))
-- # focus down
hl.bind(mainMod .. " + t", hl.dsp.focus({ direction = "down" }))

-- ## Workspace Keybinds
for i = 1, 10 do
    local key = i % 10
    -- # switch workspace [key]
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    -- # move to workspace [key]
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i }))
    -- silent move to workspace [key]
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.move({ workspace = i, follow = false}))
end

-- # previous workspace
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "prev" }))

-- # next workspace
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
-- # previous workspace
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- # move to next workspace
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- # move to previous workspace
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
