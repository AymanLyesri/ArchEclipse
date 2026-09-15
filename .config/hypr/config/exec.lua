local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"
local themeScriptsDir = home .. "/.config/hypr/theme/scripts"

hl.on("hyprland.start", function()
    -- NOTE: no `hyprpm reload && hyprctl reload` here — it re-triggers this
    -- on-start block (reload loop / slow start). Run hyprpm manually once
    -- after plugin changes instead.
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(scriptsDir .. "/compile-run-binaries.sh")
    hl.exec_cmd(scriptsDir .. "/bar.sh")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(themeScriptsDir .. "/system-theme.sh apply")
    hl.exec_cmd("nm-applet")
    -- Single clipboard watcher: kill stale watchers first so reloads don't
    -- stack duplicates, and avoid double-backgrounding (no `bash -c ... &`).
    -- [w] trick keeps pkill from matching its own shell command line.
    hl.exec_cmd("pkill -f '[w]l-paste --watch' 2>/dev/null; wl-paste --watch " .. home .. "/.config/hypr/scripts/clipboard-monitor.sh")
    hl.exec_cmd("blueman-applet")
end)
