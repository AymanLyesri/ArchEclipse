local terminal = "foot"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal .. " btop", { workspace = "5 silent" })
end)