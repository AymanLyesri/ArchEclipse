#!/bin/bash

# ArchEclipse status bar launcher (Quickshell/QtQuick).

set -u

QS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/archeclipse"
LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/archeclipse-bar.lock"

# Serialize concurrent bar.sh invocations (Hyprland autostart, SUPER+B, and
# the maintenance updater's "reload bar" step can all fire close together).
# Blocking (not -n) so every caller's restart actually happens instead of
# being silently dropped when it loses the race — a caller only gives up
# if a previous restart is *still* stuck after a generous timeout, which
# stop_archeclipse's own SIGTERM->SIGKILL escalation below keeps bounded.
exec 9>"$LOCK_FILE"
if ! flock -w 15 9; then
    echo "bar.sh: another instance is still restarting the bar, giving up after 15s" >&2
    exit 1
fi

# PIDs of live archeclipse *daemon* processes (one per line, empty if none).
# Single matcher shared by the running-check and the kill step so they can
# never disagree. Covers both launch forms (`qs -p <path>`, `qs -c` /
# `--config archeclipse`, either binary name) and excludes short-lived
# `ipc call` clients, which previously fooled the running-check into
# pointless 5s waits and caught pointless SIGTERMs.
archeclipse_pids() {
    pgrep -af -- "$QS_CONF|(^|/)(qs|quickshell)([[:space:]].*)?[[:space:]](-c|--config)(=|[[:space:]]+)archeclipse([[:space:]]|$)" 2>/dev/null \
        | grep -v -F 'ipc call' | awk '{print $1}'
}

is_archeclipse_running() {
    [ -n "$(archeclipse_pids)" ]
}

stop_archeclipse() {
    local pids
    pids="$(archeclipse_pids)"
    [ -z "$pids" ] && return 0
    kill -TERM $pids >/dev/null 2>&1 || true

    # Give Quickshell time to release its Wayland surfaces before starting
    # the replacement. This avoids two panel instances during restart.
    for _ in {1..50}; do
        pids="$(archeclipse_pids)"
        [ -z "$pids" ] && return 0
        sleep 0.1
    done

    # A stuck instance must not prevent a restart forever.
    kill -KILL $pids >/dev/null 2>&1 || true
}

stop_archeclipse

# QML disk cache enabled for production startup speed. Set
# QML_DISABLE_DISK_CACHE=1 in the environment only when debugging QML.
# 9>&- closes the lock fd in this long-lived child: without it, `qs`
# inherits fd 9 across the fork and holds the flock for as long as the bar
# itself runs — every later bar.sh invocation would then block for the
# full 15s (or, with -n, silently no-op forever) instead of the lock being
# released once *this* script's own restart sequence is done.
# -n (--no-duplicate) is the authoritative singleton guard: Quickshell
# tracks the running config by ID, so a second daemon exits immediately
# instead of instantiating a duplicate per-monitor Bar/Popups/Hover set
# (double widgets). The pgrep/pkill matchers above are string-based and
# bypassable (miss `qs -c` / `--config` forms, TOCTOU between kill and
# exec), so the launched daemon must defend itself.
MANGOHUD=0 \
nohup qs -n -p "$QS_CONF" > "/tmp/qs-bar-${USER}.log" 2>&1 9>&- &

exit 0
