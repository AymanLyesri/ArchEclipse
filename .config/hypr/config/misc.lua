hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        -- Swallow disabled by default: enable_swallow with no swallow_regex
        -- swallows every child (e.g. terminal stays hidden behind launched
        -- GUI apps). Set enable_swallow = true + swallow_regex when wanted.
        enable_swallow = false,
    },
})
