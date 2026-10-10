-- Minimal Hyprland config for the Archeclipse greeter (Lua format: .conf
-- configs warn on every start and lose support in 0.57).
-- Runs ONLY the quickshell login. Keyboard map comes from the generated
-- sibling file (system-wide config only — never any user's private config;
-- see sync-greeter.sh). Lives in the greeter source tree; sync-greeter.sh
-- mirrors it world-readable. Launched by greetd as:
--   start-hyprland -- -c /etc/xdg/quickshell/archeclipse-greeter/hyprland.lua

local this_dir = debug.getinfo(1, "S").source:match("@(.*/)") or ""
dofile(this_dir .. "keyboard-input.lua")

-- Deferred to compositor-ready: a top-level hl.exec_cmd runs at config
-- parse time, before the Wayland socket exists, and quickshell dies with
-- "Connection refused" (seen 2026-10-10: FATAL with no platform plugin).
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -c archeclipse-greeter > /tmp/qs-greeter.log 2>&1")
end)

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
    animations = {
        enabled = false,
    },
    general = {
        border_size = 0,
    },
    decoration = {
        rounding = 0,
        blur = {
            enabled = false,
        },
    },
    input = {
        follow_mouse = 0,
    },
})
