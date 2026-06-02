hl.on("hyprland.start", function()
    hl.exec_cmd("discord")
end)

hl.window_rule({
    match = { class = "^.*cord$" },
    workspace = "6 silent",
})
