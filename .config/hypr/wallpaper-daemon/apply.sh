#!/bin/bash

# Apply a wallpaper on one monitor with whichever backend can render it.
#
# The wallpaper daemon has more than one renderer, and every caller used to
# repeat the same guesswork about which one a given file needs. They call this
# instead, so a new renderer is one case here rather than an edit in each
# caller.

hyprDir="$HOME/.config/hypr"
monitor="$1"
wallpaper="$2"

if [ -z "$monitor" ] || [ -z "$wallpaper" ]; then
    echo "Usage: apply.sh <monitor> <wallpaper>" >&2
    exit 1
fi

# A Wallpaper Engine item is a directory with a project.json beside its assets.
if [ -f "$wallpaper/project.json" ]; then
    exec "$hyprDir/wallpaper-daemon/kirie.sh" "$monitor" "$wallpaper"
fi

# Anything else is a plain file, so the engine must let go of this monitor.
"$hyprDir/wallpaper-daemon/kirie.sh" --stop "$monitor" >/dev/null 2>&1

ext="${wallpaper##*.}"
ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

case "$ext" in
    gif | mp4 | webm)
        exec "$hyprDir/wallpaper-daemon/mpvpaper.sh" "$monitor" "$wallpaper"
        ;;
    *)
        exec "$hyprDir/wallpaper-daemon/hyprpaper.sh" "$monitor" "$wallpaper"
        ;;
esac
