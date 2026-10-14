local M = {}

local current_monitor = hl.get_monitor("eDP-1")
local is_144 = current_monitor and current_monitor.refresh_rate >= 144 or false

function M.toggle()
    is_144 = not is_144

    hl.monitor({
        output = "eDP-1",
        mode = is_144 and "1920x1080@144" or "1920x1080@60",
        position = "auto",
        scale = "1",
    })

    local current_rate = is_144 and "144Hz" or "60Hz"
    hl.exec_cmd("notify-send 'Refresh Rate' '" .. current_rate .. "'")
end

return M
