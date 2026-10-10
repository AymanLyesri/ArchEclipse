-- Fallback keymap for the greeter Hyprland. sync-greeter.sh overwrites this
-- file on every run with the generated system-wide map — this stub exists so
-- the dofile() in hyprland.lua can never fail on a missing file (a missing
-- file is a hard config error popup on every greeter start).
hl.config({
    input = {
        kb_layout = "us",
    },
})
