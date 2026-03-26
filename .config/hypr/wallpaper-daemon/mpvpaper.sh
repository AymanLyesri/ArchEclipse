#!/bin/bash

# Define variables
hyprdir=$HOME/.config/hypr
monitor=$1
wallpaper=$2

if [ -z "$monitor" ] || [ -z "$wallpaper" ]; then
    echo "Usage: mpvpaper.sh <monitor> <wallpaper>" >&2
    exit 1
fi

# unload any existing wallpaper on this monitor (hyprpaper 0.8+ no longer requires unload)
hyprctl hyprpaper unload "$monitor" >/dev/null 2>&1

# Stop any existing mpvpaper instance on this monitor
killall mpvpaper 2>/dev/null

# Start mpvpaper in background for animated/video wallpapers
nohup mpvpaper -o "no-audio --loop --fs --panscan=1.0" "$monitor" "$wallpaper" >/dev/null 2>&1 &

sleep 1 # Wait for wallpaper to be set (removes stuttering)

"$hyprdir/theme/scripts/wal-theme.sh" "$wallpaper" >/dev/null 2>&1

exit 0

