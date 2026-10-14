-- Spawn the bar script instead of calling it in-process: it calls os.exit()
-- on failure (fatal inside Hyprland) and can block on its flock.
local bar_script = (os.getenv("HOME") or "") .. "/.config/hypr/config/scripts/bar.lua"
local bar_hidden_for_fullscreen = false

local function is_game_fullscreen(window)
    if not window or (window.fullscreen or 0) < 2 then
        return false
    end

    local class = window.class or ""

    return class:match("^steam_app_") ~= nil
        or class:match("%.exe$") ~= nil
        or class:match("^Minecraft") ~= nil
        or class:match("minecraft") ~= nil
        or class:match("^com%.mojang%.minecraft") ~= nil
        or class == "Emulator"
end

local function sync_fullscreen_bar()
    local should_hide = is_game_fullscreen(hl.get_active_window())

    if should_hide == bar_hidden_for_fullscreen then
        return
    end

    bar_hidden_for_fullscreen = should_hide

    if should_hide then
        hl.exec_cmd("lua " .. bar_script .. " --kill")
    else
        hl.exec_cmd("lua " .. bar_script)
    end
end

-- These events cover entering/leaving fullscreen, focus changes, and workspace
-- switches. The state guard makes repeated fullscreen events inexpensive.
hl.on("window.fullscreen", sync_fullscreen_bar)
hl.on("window.active", sync_fullscreen_bar)
hl.on("workspace.active", sync_fullscreen_bar)
