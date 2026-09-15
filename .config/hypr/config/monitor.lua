-- Single fallback rule covers all outputs (incl. HDMI-A-1).
-- Add per-output blocks above this only when a monitor needs
-- a non-default mode/position/scale.
hl.monitor({
    output = "",
    mode = "highres",
    position = "auto",
    scale = 1,
})
