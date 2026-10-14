local M = {}

local start_x = 0
local start_y = 0
local start_monitor = nil
local is_dragging = false
local drag_timer = nil
local quickshell_config = (os.getenv("HOME") or "") .. "/.config/quickshell/archeclipse"

local function cursor_on_monitor()
    local cursor = hl.get_cursor_pos()
    local monitor = cursor and hl.get_monitor_at_cursor()

    if not cursor or not monitor then
        return nil
    end

    return cursor, monitor, cursor.x - monitor.position.x, cursor.y - monitor.position.y
end

local function overlay_ipc(action, args)
    hl.exec_cmd(
        "qs -p " .. quickshell_config .. " ipc call dragOverlay "
            .. action .. " " .. start_monitor .. (args or "")
    )
end

local function update_drag_overlay()
    if not is_dragging then
        return
    end

    local _, _, x, y = cursor_on_monitor()

    if not x or not y then
        return
    end

    overlay_ipc("update", string.format(" %.0f %.0f", x, y))
end

function M.start()
    local _, monitor, x, y = cursor_on_monitor()

    if not monitor or not x or not y then
        return
    end

    start_x = x
    start_y = y
    start_monitor = monitor.name
    is_dragging = true

    overlay_ipc("start", string.format(" %.0f %.0f", start_x, start_y))

    if drag_timer then
        drag_timer:set_enabled(false)
    end

    drag_timer = hl.timer(update_drag_overlay, { timeout = 16, type = "repeat" })
end

function M.finish()
    if not is_dragging then
        return
    end

    is_dragging = false

    if drag_timer then
        drag_timer:set_enabled(false)
        drag_timer = nil
    end

    overlay_ipc("stop")

    local _, monitor, cursor_x, cursor_y = cursor_on_monitor()

    if not monitor or monitor.name ~= start_monitor then
        return
    end

    local x = math.min(start_x, cursor_x)
    local y = math.min(start_y, cursor_y)
    local w = math.max(1, math.abs(start_x - cursor_x))
    local h = math.max(1, math.abs(start_y - cursor_y))

    hl.dispatch(
        hl.dsp.exec_cmd(
            "foot",
            {
                float = true,
                move = { x, y },
                size = { w, h }
            }
        )
    )
end

-- { release = true } only works for mouse buttons. Finish on any keyboard
-- release while a drag is active because modifier release has no separate bind.
hl.on("input.keyboard.key", function(_, _, state)
    if state ~= 0 or not is_dragging then
        return
    end

    M.finish()
end)

return M
