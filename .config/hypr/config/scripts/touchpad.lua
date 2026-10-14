local M = {}

local touchpad_enabled = true
local TOUCHPAD_NAME = "elan0307:00-04f3:3282-touchpad"

function M.toggle()
    touchpad_enabled = not touchpad_enabled

    hl.device({
        name = TOUCHPAD_NAME,
        enabled = touchpad_enabled,
    })

    local status_text = touchpad_enabled and "enabled" or "disabled"
    hl.exec_cmd("notify-send 'Touchpad' '" .. status_text .. "'")
end

return M
