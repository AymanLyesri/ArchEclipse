local terminal = "foot"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal .. " zsh -ic btop", { workspace = "5 silent" })
end)