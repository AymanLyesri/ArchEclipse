local phi = 1.618
local phi_min = 0.618
local interval = phi * 1
local curve = "ease"

hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("default", { type = "bezier", points = { { 0, 1 }, { 0, 1 } } })
hl.curve("wind", { type = "bezier", points = { { 0.05, phi_min }, { 0.1, 1 } } })
hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, 1 }, { 0, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })
hl.curve("ease", { type = "bezier", points = { { 0, 1 }, { phi_min, 1 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "layers", enabled = true, speed = interval, bezier = curve, style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = interval, bezier = curve, style = "slidevert" })
hl.animation({ leaf = "fadePopups", enabled = true, speed = interval, bezier = curve })
