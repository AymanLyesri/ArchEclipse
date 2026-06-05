-- -- Hyprland Lua config entrypoint.
local function require_all(configs)
    for _, name in ipairs(configs) do
        require("config." .. name)
    end
end

local function require_custom_dir()
    local home = os.getenv("HOME") or ""
    local custom_dir = home .. "/.config/hypr/config/custom"
    local handle = io.popen("ls -1 " .. custom_dir)

    if not handle then
        return
    end

    for file in handle:lines() do
        local module = file:match("^(.*)%.lua$")

        if module then
            require("config.custom." .. module)
        end
    end

    handle:close()
end

require_all({
    "animations",
    "bind",
    "decoration",
    "device",
    "env",
    "exec",
    "general",
    "gesture",
    "input",
    "layerrule",
    "layouts",
    "misc",
    "monitor",
    "windowrule",
    "workspace",
})

require_custom_dir()
