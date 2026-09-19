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

is_archeclipse_running() {
    pgrep -af -- "$QS_CONF" >/dev/null 2>&1 || \
        pgrep -af -- '(^|/)quickshell([[:space:]].*)?-[[:space:]]*c[[:space:]]+archeclipse([[:space:]]|$)' >/dev/null 2>&1
}

stop_archeclipse() {
    # Support both launch forms used by ArchEclipse:
    #   qs -p ~/.config/quickshell/archeclipse
    #   quickshell -c archeclipse
    pkill -TERM -f -- "$QS_CONF" >/dev/null 2>&1 || true
    pkill -TERM -f -- '(^|/)quickshell([[:space:]].*)?-[[:space:]]*c[[:space:]]+archeclipse([[:space:]]|$)' >/dev/null 2>&1 || true

    # Give Quickshell time to release its Wayland surfaces before starting
    # the replacement. This avoids two panel instances during restart.
    for _ in {1..50}; do
        if ! is_archeclipse_running; then
            return 0
        fi
        sleep 0.1
    done

    # A stuck instance must not prevent a restart forever.
    pkill -KILL -f -- "$QS_CONF" >/dev/null 2>&1 || true
    pkill -KILL -f -- '(^|/)quickshell([[:space:]].*)?-[[:space:]]*c[[:space:]]+archeclipse([[:space:]]|$)' >/dev/null 2>&1 || true
}

stop_archeclipse

# QML disk cache enabled for production startup speed. Set
# QML_DISABLE_DISK_CACHE=1 in the environment only when debugging QML.
# 9>&- closes the lock fd in this long-lived child: without it, `qs`
# inherits fd 9 across the fork and holds the flock for as long as the bar
# itself runs — every later bar.sh invocation would then block for the
# full 15s (or, with -n, silently no-op forever) instead of the lock being
# released once *this* script's own restart sequence is done.
MANGOHUD=0 \
nohup qs -p "$QS_CONF" > "/tmp/qs-bar-${USER}.log" 2>&1 9>&- &

exit 0
