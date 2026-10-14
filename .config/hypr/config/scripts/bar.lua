#!/usr/bin/env lua

local M = {}

local home = os.getenv("HOME") or ""
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local qs_config = config_home .. "/quickshell/archeclipse"
local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
if not runtime_dir then
    local uid = io.popen("id -u")
    local user_id = uid and uid:read("*l") or ""
    if uid then
        uid:close()
    end
    runtime_dir = "/run/user/" .. user_id
end
local lock_file = runtime_dir .. "/archeclipse-bar-lua.lock"
local log_file = "/tmp/qs-bar-" .. (os.getenv("USER") or "user") .. ".log"

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function run(command)
    local ok, _, code = os.execute(command)
    return ok == true or code == 0
end

local function pids()
    local command = "pgrep -x qs; pgrep -x quickshell"
    local handle = io.popen(command)
    if not handle then
        return {}
    end

    local result = {}
    for line in handle:lines() do
        local pid = line:match("^(%d+)")
        if pid then
            local cmdline_file = io.open("/proc/" .. pid .. "/cmdline", "rb")
            local cmdline = cmdline_file and cmdline_file:read("*a") or ""
            if cmdline_file then
                cmdline_file:close()
            end

            if cmdline:find(qs_config, 1, true)
                and not cmdline:find("ipc call", 1, true) then
                result[#result + 1] = pid
            end
        end
    end
    handle:close()
    return result
end

local function stop()
    local current = pids()
    if #current == 0 then
        return
    end

    run("kill -TERM " .. table.concat(current, " "))
    for _ = 1, 50 do
        if #pids() == 0 then
            return
        end
        os.execute("sleep 0.1")
    end

    current = pids()
    if #current > 0 then
        run("kill -KILL " .. table.concat(current, " "))
    end
end

local function launch()
    local launch_command = "MANGOHUD=0 nohup qs -n -p " .. quote(qs_config)
        .. " > " .. quote(log_file) .. " 2>&1 &"
    run(launch_command)

    local greeter_sync = home .. "/.config/quickshell/archeclipse/scripts/sync-greeter.sh"
    run(quote(greeter_sync) .. " >/dev/null 2>&1")
end

function M.run(...)
    local args = { ... }
    local locked = os.getenv("ARCH_ECLIPSE_BAR_LOCK_HELD") == "1"

-- Keep the lock only around stopping the previous daemon. Long-lived
-- descendants must not inherit it, or they can block every later restart.
if not locked then
    local self = debug.getinfo(1, "S").source:sub(2)
    local command = "ARCH_ECLIPSE_BAR_LOCK_HELD=1 lua " .. quote(self)
    for _, argument in ipairs(args) do
        command = command .. " " .. quote(argument)
    end
    command = "flock -w 15 " .. quote(lock_file) .. " -c " .. quote(command)
    if not run(command) then
        -- This branch is reachable from inside the compositor (hl.on/hl.bind
        -- callbacks). os.exit() there would call exit() in the Hyprland
        -- process mid-run and crash its global destructors, so fail soft.
        io.stderr:write("bar.lua: could not acquire " .. lock_file .. "\n")
        return false
    end

    if args[1] ~= "--kill" then
        launch()
    end
    return
end

stop()

if args[1] == "--kill" then
    return
end
end

-- `local x = ...` is nil when invoked with no arguments; passing `...`
-- straight to type() errors on zero varargs.
local loaded_as_module = ...
if type(loaded_as_module) ~= "string" or not string.match(loaded_as_module, "^config%.scripts") then
    M.run(table.unpack(arg))
end

return M
