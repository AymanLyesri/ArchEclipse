local M = {}

local drag = require("config.scripts.drag")
local refresh_rate = require("config.scripts.refresh_rate")
local touchpad = require("config.scripts.touchpad")

require("config.scripts.fullscreen")

M.dragStart = drag.start
M.dragEnd = drag.finish
-- Spawn (hl.exec_cmd is async): bar.lua uses io.popen/flock and os.exit(),
-- which must never run on the compositor event loop.
M.restart_bar = function()
    hl.exec_cmd("lua " .. (os.getenv("HOME") or "") .. "/.config/hypr/config/scripts/bar.lua")
end
M.toggle_refresh_rate = refresh_rate.toggle
M.touchpad_toggle = touchpad.toggle

return M
