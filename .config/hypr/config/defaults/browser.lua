hl.on("hyprland.start", function()
    hl.exec_cmd("zen-browser")
end)

hl.window_rule({
    match = { title = "^(Zen Browser)$" },
    workspace = "2 silent",
})
