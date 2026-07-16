#!/bin/bash
#
# ags-watchdog.sh <ags-bin>
#
# Keeps the AGS shell alive. ArchEclipse's GTK4 shell occasionally dies with a
# `gdk_surface_get_display` assertion (a surface lifecycle race, seen alongside the
# network applet's GtkStack churn). Rather than leave the desktop without a bar/panels
# until a manual relaunch, respawn it automatically.
#
# Stops cleanly when ags-bin exits 0 (e.g. `ags quit` during a config reload) or when
# the watchdog itself is terminated (so a deliberate restart isn't fought). A crash
# (non-zero exit) is respawned, with a back-off if it's crash-looping.

BIN="$1"
[ -x "$BIN" ] || { echo "ags-watchdog: '$BIN' not executable" >&2; exit 1; }

child=0
trap 'kill "$child" 2>/dev/null; exit 0' TERM INT

fails=0
window=$(date +%s)

while true; do
    "$BIN" &
    child=$!
    wait "$child"
    code=$?

    # Clean shutdown (ags quit) -> stop respawning.
    [ "$code" -eq 0 ] && exit 0

    now=$(date +%s)
    if [ $((now - window)) -ge 30 ]; then
        fails=0
        window=$now
    fi
    fails=$((fails + 1))

    if [ "$fails" -ge 6 ]; then
        notify-send -u critical "AGS" "Crashed ${fails}× in 30s — backing off 20s" 2>/dev/null
        sleep 20
        fails=0
        window=$(date +%s)
    fi
    sleep 1
done
