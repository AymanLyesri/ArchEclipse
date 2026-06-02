local terminal = "kitty"

hl.on("hyprland.start", function()
    hl.exec_cmd("[workspace 5 silent] " .. terminal .. " btop")
end)
