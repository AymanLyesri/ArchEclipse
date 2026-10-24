local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"
local screenshot = scriptsDir .. "/screenshot.sh"
local screenrecord = scriptsDir .. "/screenrecord.sh"
local brightnessScript = home .. "/.config/hypr/config/scripts/brightness.lua"
local barScript = home .. "/.config/hypr/config/scripts/bar.lua"
local terminal = "foot"
local scripts = require("config.scripts")
-- Quickshell secure lock (qs ipc) + suspend chain (sleep 1 lets grim
-- capture and the session lock engage before the machine sleeps).
local lock = "qs -p " .. home .. "/.config/quickshell/archeclipse ipc call lock activate"
local suspend = "qs -p " ..
    home .. "/.config/quickshell/archeclipse ipc call lock activate && sleep 1 && systemctl suspend"
-- Focused monitor, resolved at keypress time. Uses activeworkspace (small JSON)
-- instead of full monitors list to avoid a hyprctl+jq scan per keypress.
local monitor = "$(hyprctl activeworkspace -j | jq -r '.monitor')"
local resizeAmount = 25
local volUp = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
local volDown = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
local volMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

-- Quickshell bar: IPC calls target the QS config
local qsCfg = home .. "/.config/quickshell/archeclipse"
local qsIpc = "qs -p " .. qsCfg .. " ipc call bar "
-- Brightness of the focused monitor (internal backlight or DDC/CI) is handled by
-- the shell: `ipc call brightness incrementFor|decrementFor <monitor>`. If quickshell isn't
-- running, `qs ipc` exits non-zero and the script fallback takes over.
local qsBrightness = "qs -p " .. qsCfg .. " ipc call brightness "
local brightnessUp = qsBrightness .. "incrementFor \"" .. monitor .. "\" || lua " .. brightnessScript .. " +10"
local brightnessDown = qsBrightness .. "decrementFor \"" .. monitor .. "\" || lua " .. brightnessScript .. " -10"

hl.config({
    binds = {
        workspace_back_and_forth = 1,
        allow_workspace_cycles = 1,
        pass_mouse_when_bound = 0,
    },
})

local mainMod = "SUPER"

-- Physical XKB evdev keycodes keep ordinary key positions independent of the
-- active keyboard layout. Modifiers and media keys stay symbolic; mouse buttons
-- use named aliases in the same table.
local keycode = {
    A = "code:38", B = "code:56", C = "code:54", D = "code:40",
    E = "code:26", F = "code:41", G = "code:42", H = "code:43",
    I = "code:31", J = "code:44", K = "code:45", L = "code:46",
    M = "code:58", N = "code:57", O = "code:32", P = "code:33",
    Q = "code:24", R = "code:27", S = "code:39", T = "code:28",
    U = "code:30", V = "code:55", W = "code:25", X = "code:53",
    Y = "code:29", Z = "code:52",
    Backspace = "code:22", Escape = "code:9", F1 = "code:67",
    F2 = "code:68", F3 = "code:69", F11 = "code:95", F12 = "code:96",
    Left = "code:113", Return = "code:36", Right = "code:114",
    Space = "code:65", Tab = "code:23", Up = "code:111", Down = "code:116",
    period = "code:60",
    LMB = "mouse:272", RMB = "mouse:273",
}

-- Window Management
--- fullscreen active window
hl.bind(mainMod .. " + " .. keycode.F, hl.dsp.window.fullscreen({ action = "toggle" }))
--- close active window
hl.bind(mainMod .. " + " .. keycode.Q, hl.dsp.window.close())
--- kill active window
hl.bind(mainMod .. " + SHIFT + " .. keycode.Q, hl.dsp.window.kill())
--- float for active window
hl.bind(mainMod .. " + " .. keycode.Space, hl.dsp.window.float({ action = "toggle" }))
--- pin active window
hl.bind(mainMod .. " + ALT + " .. keycode.Space, hl.dsp.window.pin())

-- Open Apps
--- open terminal
hl.bind(mainMod .. " + " .. keycode.Return, hl.dsp.exec_cmd(terminal))
--- open floating terminal
hl.bind(mainMod .. " + CTRL + " .. keycode.Return, hl.dsp.exec_cmd("[float] " .. terminal))
--- open btop in workspace 5
hl.bind(mainMod .. " + " .. keycode.P, hl.dsp.exec_cmd("[workspace 5] " .. terminal .. " btop"))

-- Status Bar and Panels
--- restart status bar
hl.bind(mainMod .. " + " .. keycode.B, hl.dsp.exec_cmd("lua " .. barScript))
--- toggle status bar visibility
hl.bind(mainMod .. " + ALT + " .. keycode.Backspace, hl.dsp.exec_cmd(qsIpc .. "toggleBar " .. monitor))
--- toggle app launcher
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd(qsIpc .. "toggleSearch " .. monitor))
--- toggle media panel
hl.bind(mainMod .. " + " .. keycode.M, hl.dsp.exec_cmd(qsIpc .. "togglePanel media-panel " .. monitor))
--- toggle right panel
hl.bind(mainMod .. " + " .. keycode.R, hl.dsp.exec_cmd(qsIpc .. "toggleRightPanel " .. monitor))
--- toggle left panel
hl.bind(mainMod .. " + " .. keycode.L, hl.dsp.exec_cmd(qsIpc .. "toggleLeftPanel " .. monitor))
--- toggle wallpaper switcher
hl.bind(mainMod .. " + " .. keycode.W, hl.dsp.exec_cmd(qsIpc .. "togglePanel wallpaper-switcher " .. monitor))
--- lock screen
hl.bind(mainMod .. " + " .. keycode.Escape, hl.dsp.exec_cmd(lock))
--- open clipboard manager
hl.bind(mainMod .. " + SHIFT + " .. keycode.V, hl.dsp.exec_cmd(qsIpc .. "clipboard " .. monitor))
--- open emoji picker
hl.bind(mainMod .. " + " .. keycode.period, hl.dsp.exec_cmd(qsIpc .. "emojis " .. monitor))
--- open notes app
hl.bind(mainMod .. " + SHIFT + " .. keycode.N, hl.dsp.exec_cmd(qsIpc .. "notes " .. monitor))
--- open all apps
hl.bind(mainMod .. " + " .. keycode.A, hl.dsp.exec_cmd(qsIpc .. "apps " .. monitor))
--- toggle welcome tour
hl.bind(mainMod .. " + " .. keycode.F1, hl.dsp.exec_cmd("qs -p " .. qsCfg .. " ipc call welcome toggle"))

-- Screenshot and Screen Record Keybinds
--- screenshot workspace
hl.bind(mainMod .. " + SHIFT + " .. keycode.S, hl.dsp.exec_cmd(screenshot .. " --now --monitor \"" .. monitor .. "\""))
--- screenshot area
hl.bind(mainMod .. " + CTRL + SHIFT + " .. keycode.S, hl.dsp.exec_cmd(screenshot .. " --area --monitor \"" .. monitor .. "\""))
--- screen record workspace
hl.bind(mainMod .. " + SHIFT + " .. keycode.R, hl.dsp.exec_cmd(screenrecord .. " toggle --monitor \"" .. monitor .. "\""))
--- screen record area
hl.bind(mainMod .. " + CTRL + SHIFT + " .. keycode.R, hl.dsp.exec_cmd(screenrecord .. " toggle --area --monitor \"" .. monitor .. "\""))
--- screenshot all monitors
hl.bind(mainMod .. " + ALT + " .. keycode.S, hl.dsp.exec_cmd(screenshot .. " --now --all"))
--- record all monitors
hl.bind(mainMod .. " + ALT + " .. keycode.R, hl.dsp.exec_cmd(screenrecord .. " toggle --all"))

-- Special Workspace Keybinds
--- move to special workspace
hl.bind(mainMod .. " + CTRL + " .. keycode.S, hl.dsp.window.move({ workspace = "special" }))
--- toggle special workspace
hl.bind(mainMod .. " + " .. keycode.S, hl.dsp.workspace.toggle_special())

-- Media, Brightness and Volume Controls
--- volume up
local volumeUp = qsIpc .. "noteVolumeTarget \"" .. monitor .. "\"; " .. volUp
local volumeDown = qsIpc .. "noteVolumeTarget \"" .. monitor .. "\"; " .. volDown
local volumeMute = qsIpc .. "noteVolumeTarget \"" .. monitor .. "\"; " .. volMute
hl.bind("ALT + " .. keycode.F12, hl.dsp.exec_cmd(volumeUp), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(volumeUp),
    { locked = true, repeating = true })
--- volume down
hl.bind("ALT + " .. keycode.F11, hl.dsp.exec_cmd(volumeDown), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(volumeDown),
    { locked = true, repeating = true })
--- toggle mute
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(volumeMute), { locked = true })

--- brightness up
hl.bind("ALT + " .. keycode.F3, hl.dsp.exec_cmd(brightnessUp), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(brightnessUp), { locked = true, repeating = true })
--- brightness down
hl.bind("ALT + " .. keycode.F2, hl.dsp.exec_cmd(brightnessDown), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(brightnessDown), { locked = true, repeating = true })

-- System Controls
--- lock
hl.bind(mainMod .. " + SHIFT + " .. keycode.Escape, hl.dsp.exec_cmd(lock))
--- suspend
hl.bind(mainMod .. " + CTRL + " .. keycode.Escape, hl.dsp.exec_cmd(suspend))
--- shutdown
hl.bind(mainMod .. " + CTRL + SHIFT + " .. keycode.Escape, hl.dsp.exec_cmd("shutdown now"))

-- Window Resize, Move and Focus
--- expand left
hl.bind(mainMod .. " + SHIFT + " .. keycode.Left, hl.dsp.window.resize({ x = -resizeAmount, y = 0, relative = true }),
    { repeating = true })
--- expand right
hl.bind(mainMod .. " + SHIFT + " .. keycode.Right, hl.dsp.window.resize({ x = resizeAmount, y = 0, relative = true }),
    { repeating = true })
--- expand up
hl.bind(mainMod .. " + SHIFT + " .. keycode.Up, hl.dsp.window.resize({ x = 0, y = -resizeAmount, relative = true }),
    { repeating = true })
--- expand down
hl.bind(mainMod .. " + SHIFT + " .. keycode.Down, hl.dsp.window.resize({ x = 0, y = resizeAmount, relative = true }),
    { repeating = true })

--- move left
hl.bind(mainMod .. " + CTRL + " .. keycode.Left, hl.dsp.window.move({ direction = "l" }))
--- move right
hl.bind(mainMod .. " + CTRL + " .. keycode.Right, hl.dsp.window.move({ direction = "r" }))
--- move up
hl.bind(mainMod .. " + CTRL + " .. keycode.Up, hl.dsp.window.move({ direction = "u" }))
--- move down
hl.bind(mainMod .. " + CTRL + " .. keycode.Down, hl.dsp.window.move({ direction = "d" }))

--- focus left
hl.bind(mainMod .. " + " .. keycode.Left, hl.dsp.focus({ direction = "left" }))
--- focus right
hl.bind(mainMod .. " + " .. keycode.Right, hl.dsp.focus({ direction = "right" }))
--- focus up
hl.bind(mainMod .. " + " .. keycode.Up, hl.dsp.focus({ direction = "up" }))
--- focus down
hl.bind(mainMod .. " + " .. keycode.Down, hl.dsp.focus({ direction = "down" }))

-- Workspace Keybinds
-- @keybind-labels key=1,2,3,4,5,6,7,8,9,0
for i = 1, 10 do
    local key = "code:" .. tostring(i + 9)
    --- switch workspace [key]
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    --- move to workspace [key]
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i }))
    --- silent move to workspace [key]
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- NumPad Workspaces Keybinds
-- @keybind-labels key_name=KP1,KP2,KP3,KP4,KP5,KP6,KP7,KP8,KP9,KP0
local numpad_keys = {
    "code:87",
    "code:88",
    "code:89",
    "code:83",
    "code:84",
    "code:85",
    "code:79",
    "code:80",
    "code:81",
    "code:90"
}

for index, key_name in ipairs(numpad_keys) do
    local workspace_id = tostring(index + 10)

    --- switch Workspace [key_name]
    hl.bind(mainMod .. " + " .. key_name, hl.dsp.focus({ workspace = workspace_id }))
    --- move to workspace [key_name]
    hl.bind(mainMod .. " + CTRL + " .. key_name, hl.dsp.window.move({ workspace = workspace_id }))
    --- silent move to workspace [key_name]
    hl.bind(mainMod .. " + SHIFT + " .. key_name, hl.dsp.window.move({ workspace = workspace_id, follow = false }))
end

--- previous workspace
hl.bind(mainMod .. " + " .. keycode.Tab, hl.dsp.focus({ workspace = "prev" }))
--- workspace overview
hl.bind(mainMod .. " + SHIFT + " .. keycode.Tab, hl.dsp.exec_cmd(qsIpc .. "toggleOverview \"" .. monitor .. "\""))

--- focus next workspace
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
--- previous workspace
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

--- spawn a floating terminal under a selected rectangle
hl.bind(mainMod .. " + SHIFT + " .. keycode.LMB, scripts.dragStart, { mouse = true })
hl.bind(mainMod .. " + SHIFT + " .. keycode.LMB, scripts.dragEnd, { mouse = true, release = true })

--- move window with the primary mouse button
hl.bind(mainMod .. " + " .. keycode.LMB, hl.dsp.window.drag(), { mouse = true })
--- resize window with the secondary mouse button
hl.bind(mainMod .. " + " .. keycode.RMB, hl.dsp.window.resize(), { mouse = true })
