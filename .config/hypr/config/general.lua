hl.config({
    general = {
        layout = "dwindle",
        -- border_size 0: col.active/inactive_border are dead config while
        -- this is 0. Raise to >=1 if you want visible borders.
        border_size = 0,
        resize_on_border = true,
        gaps_in = 4,
        gaps_out = 12,
        snap = {
            enabled = true,
        },
    },
})
