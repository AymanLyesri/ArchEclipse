#!/bin/bash

set -u

interval=20
backoffInterval=300
maxFailures=3
hyprDir="$HOME/.config/hypr"
tmpDir="/tmp"
failures=0

running() { pgrep -x "$1" >/dev/null 2>&1; }

ags_running() {
    local pid
    for pid in $(pgrep -x gjs 2>/dev/null); do
        if tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | grep -qE 'ags\.js|ags-bin'; then
            return 0
        fi
    done
    return 1
}

resolve_session_env() {
    local pid sock name dir sig

    pid=$(pgrep -x Hyprland | head -1)
    [ -n "$pid" ] || return 1

    name=""
    for sock in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
        [ -S "$sock" ] || continue
        if ss -lxHp 2>/dev/null | grep -F " $sock " | grep -q "pid=$pid,"; then
            name=$(basename "$sock")
            break
        fi
    done
    if [ -z "$name" ]; then
        for sock in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
            [ -S "$sock" ] && name=$(basename "$sock")
        done
    fi
    [ -n "$name" ] || return 1

    sig=""
    for dir in "$XDG_RUNTIME_DIR"/hypr/*/; do
        [ -S "${dir}.socket.sock" ] || continue
        if HYPRLAND_INSTANCE_SIGNATURE=$(basename "$dir") hyprctl version >/dev/null 2>&1; then
            sig=$(basename "$dir")
            break
        fi
    done
    [ -n "$sig" ] || return 1

    export WAYLAND_DISPLAY="$name"
    export HYPRLAND_INSTANCE_SIGNATURE="$sig"
    export XDG_CURRENT_DESKTOP=Hyprland
    return 0
}

start_once() {
    setsid nohup "$@" >/dev/null 2>&1 &
}

ensure_wallpaper_loop() {
    if [ ! -x "$tmpDir/wallpaper-loop" ]; then
        gcc "$hyprDir/scripts-c/wallpaper-loop.c" -o "$tmpDir/wallpaper-loop" >/dev/null 2>&1 || return 1
    fi
    running wallpaper-loop || start_once "$tmpDir/wallpaper-loop"
}

while true; do
    if resolve_session_env; then
        if ags_running; then
            failures=0
        else
            echo "session-guard: AGS is gone; restarting the shell"
            start_once bash "$hyprDir/scripts/bar.sh"
            sleep 30
            if ags_running; then
                failures=0
            else
                failures=$((failures + 1))
                echo "session-guard: AGS did not come back (failure $failures)"
            fi
        fi

        ensure_wallpaper_loop
        running hyprpaper || start_once hyprpaper
        running nm-applet || start_once nm-applet
        running blueman-applet || start_once blueman-applet
    fi

    if [ "$failures" -ge "$maxFailures" ]; then
        sleep "$backoffInterval"
    else
        sleep "$interval"
    fi
done
