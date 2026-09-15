-- Base defaults. Host-local tweaks live in config/custom/decoration_*.lua
-- (active/inactive_opacity, blur enabled/size/passes) and win over these.
-- NOTE: blur size 4 / passes 4 is the perf-safe default; size 6 + passes 5
-- costs ~2x blur time on iGPUs — only raise it in custom/ if you need it.
hl.config({
    decoration = {
        rounding = 12,
        rounding_power = 12,
        dim_inactive = false,
        dim_strength = 0.25,
        active_opacity = 0.85,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        blur = {
            contrast = 1,
            vibrancy = 1,
            new_optimizations = true,
            ignore_opacity = true,
            popups = true,
            popups_ignorealpha = 0.97,
            input_methods = true,
            size = 4,
            passes = 4,
        },
        shadow = {
            enabled = false,
            range = 15,
            render_power = 3,
        },
    },
})
