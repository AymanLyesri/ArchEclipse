local home = os.getenv("HOME") or ""
local scriptsDir = home .. "/.config/hypr/scripts"
local themeScriptsDir = home .. "/.config/hypr/theme/scripts"

hl.on("hyprland.start", function()
    -- NOTE: no `hyprpm reload && hyprctl reload` here — it re-triggers this
    -- on-start block (reload loop / slow start). Run hyprpm manually once
    -- after plugin changes instead.
    hl.exec_cmd("walleclipse")
    hl.exec_cmd(scriptsDir .. "/compile-run-binaries.sh")
    hl.exec_cmd(scriptsDir .. "/bar.sh")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(themeScriptsDir .. "/system-theme.sh apply")
    hl.exec_cmd("nm-applet")
    -- Single clipboard watcher: kill stale watchers first so reloads don't
    -- stack duplicates. Kill and start MUST be separate exec_cmds: a combined
    -- "pkill ...; wl-paste --watch ..." runs in one `sh -c` whose own cmdline
    -- contains "wl-paste --watch", so pkill matches and SIGTERMs its own
    -- parent shell before the watcher ever starts (the [w] trick only hides
    -- the pkill process itself, not the wrapping shell). Split, the killer
    -- shell is short-lived (self-kill harmless) and the starter has no pkill
    -- to match itself.
    hl.exec_cmd("pkill -f '[w]l-paste --watch' 2>/dev/null; pkill -f '[c]lipboard-monitor.sh' 2>/dev/null; true")
    hl.exec_cmd("wl-paste --watch " ..
    home .. "/.config/hypr/scripts/clipboard-monitor.sh")
    hl.exec_cmd("blueman-applet")
end)

-- Quickshell fullscreen watcher (kill+restart on focused fullscreen):
-- focused-only semantics: background fullscreen on another
-- workspace/monitor never hides the bar; leaving the fullscreen
-- window (focus change, workspace switch, un-fullscreen) restores
-- it. The sync helper is idempotent (docs warn fullscreen can
-- fire multiple times per toggle) and self-serializes, so stacked
-- handlers after a reload are harmless.
-- NOTE: top-level on purpose. Inside hyprland.start these would only
-- register at compositor boot and never on reload.
local function fullscreenSync()
    hl.exec_cmd(scriptsDir .. "/quickshell-fullscreen-sync.sh")
end
hl.on("window.fullscreen", function(w) fullscreenSync() end)
hl.on("window.active", function(w) fullscreenSync() end)
hl.on("workspace.active", function(ws) fullscreenSync() end)
