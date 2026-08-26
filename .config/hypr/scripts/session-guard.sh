#!/bin/bash

# Bring the shell back after a compositor crash.
#
# Hyprland relaunches itself with `--safe-mode` when it dies, and safe mode
# skips every `exec-once` — so the config and the keybinds come back but AGS,
# hyprpaper, the wallpaper loop and the tray applets simply are not there. The
# session looks broken until each one is started by hand.
#
# The crashes themselves are an amdgpu ring hang (the iGPU under a 1440p@360Hz
# compositor); this does not fix that, it just stops one from costing the whole
# desktop. Runs as a user service, checks every 20s, starts only what is
# missing, and does nothing at all while the session is healthy.

set -u

interval=20
hyprDir="$HOME/.config/hypr"

# Match on the process NAME, never on the command line: a `pgrep -f` for a
# pattern that appears in this script's own argv matches this script.
running() { pgrep -x "$1" >/dev/null 2>&1; }

# AGS's process name is `gjs`, and the bundle re-execs itself as
# `gjs -m /run/user/<uid>/ags.js` — NOT as the ags-bin path it was started
# from, which is what an earlier version of this check looked for. It decided
# a perfectly healthy shell was missing and restarted it.
ags_running() {
    local pid
    for pid in $(pgrep -x gjs 2>/dev/null); do
        if tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | grep -qE 'ags\.js|ags-bin'; then
            return 0
        fi
    done
    return 1
}

compositor_up() {
    [ -n "$(ls -A "$XDG_RUNTIME_DIR/hypr" 2>/dev/null)" ] && running Hyprland
}

start_once() {
    # `setsid` so nothing here dies with this service if it is restarted.
    setsid nohup "$@" >/dev/null 2>&1 &
}

while true; do
    if compositor_up; then
        if ! ags_running; then
            echo "session-guard: AGS is gone; restarting the shell"
            start_once bash "$hyprDir/scripts/compile-run-binaries.sh"
            # Give the bundle time to build before deciding it failed again.
            sleep 30
        fi

        running hyprpaper || start_once hyprpaper
        running nm-applet || start_once nm-applet
        running blueman-applet || start_once blueman-applet
    fi
    sleep "$interval"
done
