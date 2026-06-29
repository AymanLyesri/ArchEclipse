#!/bin/bash
#
# dispatch.sh <monitor> <wallpaper>
#
# Single source of truth for picking a wallpaper's renderer:
#   Steam Workshop item -> Wallpaper Engine, gif/mp4/webm -> mpvpaper, else -> hyprpaper.
# Called by wallpaper-loop.c, apply-current.sh and set-wallpaper.sh so the decision lives in one place.

hyprDir="$HOME/.config/hypr"
daemon="$hyprDir/wallpaper-daemon"
monitor="$1"
wallpaper="$2"
[ -n "$monitor" ] && [ -n "$wallpaper" ] || { echo "usage: dispatch.sh <monitor> <wallpaper>" >&2; exit 1; }

case "$wallpaper" in
    */workshop/content/431960/*)
        exec "$daemon/wallpaperengine.sh" "$monitor" "$wallpaper"
        ;;
    *)
        case "$(printf '%s' "${wallpaper##*.}" | tr '[:upper:]' '[:lower:]')" in
            gif|mp4|webm) exec "$daemon/mpvpaper.sh" "$monitor" "$wallpaper" ;;
            *)            exec "$daemon/hyprpaper.sh" "$monitor" "$wallpaper" ;;
        esac
        ;;
esac
