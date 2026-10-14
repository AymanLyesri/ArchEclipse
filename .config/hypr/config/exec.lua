local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/config/scripts"

hl.on("hyprland.start", function()
    -- NOTE: no `hyprpm reload && hyprctl reload` here — it re-triggers this
    -- on-start block (reload loop / slow start). Run hyprpm manually once
    -- after plugin changes instead.
    hl.exec_cmd("walleclipse")
    hl.exec_cmd("lua " .. scriptsDir .. "/bar.lua")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("coloreclipse apply")
    hl.exec_cmd("nm-applet")
    -- Clipboard watcher is owned by quickshell (ClipboardService spawns
    -- `wl-paste --watch qs … ipc call clipboard event` at boot and culls
    -- stale watchers itself) — no hook here so boots don't stack duplicates.
    hl.exec_cmd("blueman-applet")
end)
