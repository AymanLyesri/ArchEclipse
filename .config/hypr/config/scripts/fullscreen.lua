-- Spawn the bar script instead of calling it in-process: it calls os.exit()
-- on failure (fatal inside Hyprland) and can block on its flock.
local bar_script = (os.getenv("HOME") or "") .. "/.config/hypr/config/scripts/bar.lua"
local settings_file = (os.getenv("HOME") or "") .. "/.cache/quickshell/settings/settings.json"
local gaming_workspace = 10
local bar_hidden_for_fullscreen = false

-- Settings > General toggles this (`gameMode.autoHideBar`, default on). Read the
-- file per event: the toggle must apply without a Hyprland reload or a shell restart.
local function auto_hide_enabled()
    local handle = io.open(settings_file, "r")
    if not handle then
        return true
    end

    local text = handle:read("a")
    handle:close()
    if not text then
        return true
    end

    return text:match('"gameMode".-"autoHideBar"%s*:%s*{%s*"value"%s*:%s*(%a+)') ~= "false"
end

local function is_fullscreen(window)
    return window ~= nil and (window.fullscreen or 0) >= 2
end

local function is_on_gaming_workspace(window)
    local workspace = window.workspace
    -- The Lua binding may hand down {id, name} or the bare number/name string.
    local id = type(workspace) == "table" and (workspace.id or workspace.name) or workspace

    return tonumber(id) == gaming_workspace
end

local function is_game_fullscreen(window)
    if not is_fullscreen(window) then
        return false
    end

    -- The gaming workspace hides for any fullscreen window, not only known classes.
    if is_on_gaming_workspace(window) then
        return true
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
    local should_hide = auto_hide_enabled() and is_game_fullscreen(hl.get_active_window())

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
