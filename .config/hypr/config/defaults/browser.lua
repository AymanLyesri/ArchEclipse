hl.on("hyprland.start", function()
    hl.exec_cmd("{{ APP_NAME }}")
end)

hl.window_rule({
    match = { title = "{{ APP_TITLE }}" },
    workspace = "2 silent",
})