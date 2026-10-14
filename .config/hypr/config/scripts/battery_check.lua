#!/usr/bin/env lua

local function read_first_line(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local value = file:read("*l")
    file:close()
    return value
end

local function find_battery()
    for _, name in ipairs({ "BAT0", "BAT1" }) do
        local path = "/sys/class/power_supply/" .. name .. "/capacity"
        if read_first_line(path) then
            return "/sys/class/power_supply/" .. name
        end
    end
    return nil
end

local battery = find_battery()
if battery then
    local percentage = tonumber(read_first_line(battery .. "/capacity"))
    local status = read_first_line(battery .. "/status")
    if percentage and percentage > 0 and percentage <= 25 and status == "Discharging" then
        os.execute("notify-send -u critical " .. string.format("%q", "Battery Low!")
            .. " " .. string.format("%q", "Please plug in your charger."))
    end
end
