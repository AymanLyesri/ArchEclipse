hl.config({
    dwindle = {
        force_split = 2,
        preserve_split = true,
        -- `dwindle:special_scale_factor` is deprecated in favour of
        -- workspace rules (config/workspace.lua). 1.0 is the new default;
        -- the old 0.95 value is preserved there as layout_opts.
    },
    master = {
        new_on_top = 0,
        mfact = 0.5,
        -- Old `master:special_scale_factor = 0.5` is dropped with the same
        -- deprecation. Workspace rules now carry a single special-workspace
        -- scale (0.95, the active dwindle value) — master mode's old 0.5
        -- no longer differs, which only matters if you switch layouts.
        orientation = "right",
    },
})
