#!/usr/bin/env lua

local home = os.getenv("HOME") or ""

local function capture(command)
    local handle = io.popen(command .. " 2>/dev/null")
    if not handle then
        return nil
    end
    local value = handle:read("*l")
    local ok = handle:close()
    if not ok then
        return nil
    end
    return value
end

local function quote(value)
    return string.format("%q", value)
end

if home ~= "" and capture("git -C " .. quote(home) .. " rev-parse --is-inside-work-tree") == "true" then
    os.execute("git -C " .. quote(home) .. " fetch >/dev/null 2>&1")
    local behind = tonumber(capture("git -C " .. quote(home) .. " rev-list --count '@..@{u}'"))
    if behind and behind > 0 then
        local message = string.format("We are behind by %d commits.", behind)
        local action = io.popen(
            "notify-send " .. quote("Repository Update") .. " " .. quote(message)
                .. " --action=update='Pull Changes' 2>/dev/null"
        )
        local response = action and action:read("*l") or nil
        if action then
            action:close()
        end
        if response and response:find("update", 1, true) then
            os.execute("foot " .. quote(home .. "/.config/hypr/maintenance/update.py")
                .. " >/dev/null 2>&1 &")
        end
    end
end
