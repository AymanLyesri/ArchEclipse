#!/usr/bin/env lua

local locked = os.getenv("BRIGHTNESS_LOCK_HELD") == "1"
local delta = tonumber(arg[1])
if not locked and not delta then
    io.stderr:write("Usage: brightness.lua [+10|-10]\n")
    os.exit(1)
end

local home = os.getenv("HOME") or ""
local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local pending = runtime_dir .. "/brightness.pending"
local work = runtime_dir .. "/brightness.work"
local lock = runtime_dir .. "/brightness-lua.lock"
local cache = runtime_dir .. "/ddc-buses"

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function run(command)
    local ok, _, code = os.execute(command)
    return ok == true or code == 0
end

local function capture(command)
    local handle = io.popen(command)
    if not handle then
        return ""
    end
    local output = handle:read("*a")
    handle:close()
    return output
end

local function append(path, value)
    local file = io.open(path, "a")
    if not file then
        return false
    end
    file:write(value, "\n")
    file:close()
    return true
end

local function sum_file(path)
    local total = 0
    for value in io.lines(path) do
        total = total + (tonumber(value) or 0)
    end
    return total
end

local function apply(total)
    local devices = {}
    for device in capture("find /sys/class/backlight -mindepth 1 -maxdepth 1 -type l -printf '%f\\n' 2>/dev/null"):gmatch("[^\n]+") do
        devices[#devices + 1] = device
    end

    if #devices > 0 then
        local current = capture("brightnessctl -m -d " .. quote(devices[1]) .. " 2>/dev/null")
        local percent = tonumber(current:match("([^,]+)%%")) or 0
        local target = math.max(0, math.min(100, percent + total))

        for _, device in ipairs(devices) do
            run("brightnessctl -q --device=" .. quote(device) .. " set " .. target .. "%")
        end
    end

    if not run("command -v ddcutil >/dev/null 2>&1") then
        return
    end

    local cache_file = io.open(cache, "r")
    local cached = cache_file and cache_file:read("*a") or ""
    if cache_file then
        cache_file:close()
    end

    if cached == "" then
        local buses = {}
        local current_bus
        for line in capture("ddcutil detect --brief 2>/dev/null"):gmatch("[^\n]+") do
            local bus = line:match("I2C bus:%s*(%S+)")
            if bus then
                current_bus = bus:gsub(".*i2c%-", "")
            end
            local connector = line:match("DRM_connector:%s*(%S+)")
            if connector and current_bus then
                connector = connector:gsub("^card%d+%-", "")
                buses[#buses + 1] = connector .. " " .. current_bus
            end
        end
        cached = table.concat(buses, "\n")
        local file = io.open(cache, "w")
        if file then
            file:write(cached, "\n")
            file:close()
        end
    end

    local focused = capture("hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name'"):match("%S+")
    local bus = focused and cached:match("\n?" .. focused:gsub("([^%w])", "%%%1") .. "%s+(%S+)") or nil
    if bus then
        local sign = total < 0 and "-" or "+"
        run("ddcutil --bus " .. quote(bus) .. " setvcp 10 " .. sign .. " " .. math.abs(total)
            .. " --noverify --sleep-multiplier .1")
    end
end

if not locked then
    append(pending, delta)
    local self = debug.getinfo(1, "S").source:sub(2)
    local command = "BRIGHTNESS_LOCK_HELD=1 lua " .. quote(self)
    command = "flock -n " .. quote(lock) .. " -c " .. quote(command)
    os.exit(run(command) and 0 or 1)
end

while true do
    if not run("mv " .. quote(pending) .. " " .. quote(work) .. " 2>/dev/null") then
        break
    end

    local total = sum_file(work)
    os.remove(work)
    if total ~= 0 then
        apply(total)
    end
end
