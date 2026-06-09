hl.on("hyprland.start", function()
    hl.exec_cmd("{{ APP_NAME }}")
end)

hl.window_rule({
    match = { class = "{{ CLASS_NAME }}" },
    workspace = "6 silent",
})