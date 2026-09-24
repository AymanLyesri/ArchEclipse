#!/usr/bin/env bash
# One-shot quickshell fullscreen sync, driven by Hyprland's
# window.fullscreen / window.active / workspace.active events
# (see exec.lua). Focused-only semantics: the shell dies only while
# the FOCUSED window is fullscreen, so a background fullscreen on
# another workspace/monitor never hides the bar, and leaving the
# fullscreen window's workspace restores it. Idempotent: safe to run
# on duplicate events (docs warn fullscreen can fire repeatedly
# per toggle). Concurrent runs serialize on a lock so an exit can
# never observe a half-killed shell and skip the restart.
set -euo pipefail

QS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/archeclipse"
BAR_SH="$HOME/.config/hypr/scripts/bar.sh"
LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell-fullscreen-sync.lock"
TRACE_LOG="/tmp/qs-fullscreen-sync.log"

# Same matcher as bar.sh: live archeclipse daemons only, never `ipc call` clients.
archeclipse_pids() {
    # Always exits 0 (pgrep finds nothing once the shell is dead, and
    # pipefail would otherwise trip set -e on the caller's assignment).
    pgrep -af -- "$QS_CONF|(^|/)(qs|quickshell)([[:space:]].*)?[[:space:]](-c|--config)(=|[[:space:]]+)archeclipse([[:space:]]|$)" 2>/dev/null \
    | grep -v -F 'ipc call' | awk '{print $1}' || true
}

# Focused-client fullscreen modes: 2 = fullscreen (3 = maximized-fullscreen).
# Plain maximize (1) must NOT kill the shell. Empty output (no focus)
# counts as not fullscreen, so the shell is ensured up.
focused_fullscreen() {
    hyprctl activewindow -j 2>/dev/null | grep -q '"fullscreen": [23]'
}

exec 8>"$LOCK_FILE"
flock -w 10 8 || exit 1

trace() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$1" >>"$TRACE_LOG"; }

if focused_fullscreen; then
    trace "event: focused fullscreen, shell=$(archeclipse_pids | tr '\n' ' ')"
    [ -z "$(archeclipse_pids)" ] && { trace "action: already dead, noop"; exit 0; }
    # Single kill implementation lives in bar.sh (TERM, grace wait, KILL).
    "$BAR_SH" --kill >/dev/null 2>&1
    if [ -z "$(archeclipse_pids)" ]; then
        trace "action: killed"
    else
        trace "action: kill attempted, shell still up"
    fi
    exit 0
else
    trace "event: focused not fullscreen, shell=$(archeclipse_pids | tr '\n' ' ')"
    [ -n "$(archeclipse_pids)" ] && { trace "action: already up, noop"; exit 0; }
    # Close the lock fd before spawning: otherwise bar.sh's long-lived
    # `qs` daemon inherits it and holds our lock forever (same class
    # of fd leak bar.sh itself guards against on fd 9).
    exec 8>&-
    "$BAR_SH" >/dev/null 2>&1
    trace "action: restarted via bar.sh"
fi
