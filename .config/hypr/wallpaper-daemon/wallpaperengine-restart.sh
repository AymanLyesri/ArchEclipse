#!/bin/bash
#
# wallpaperengine-restart.sh
#
# Restarts every running per-monitor engine and re-applies the current wallpaper.
# Used for the few changes that can't be pushed live over the socket (e.g. the
# audio capture device, which the recorder binds at startup).

daemon="$HOME/.config/hypr/wallpaper-daemon"

for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
    sock="${XDG_RUNTIME_DIR:-/tmp}/lwe-$monitor.sock"
    [ -S "$sock" ] || continue
    pkill -f -- "--control-socket $sock" 2>/dev/null
    rm -f "$sock"
    "$daemon/apply-current.sh" "$monitor"
done
