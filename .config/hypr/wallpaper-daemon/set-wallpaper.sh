#!/bin/bash

hyprDir="$HOME/.config/hypr"
workspace_id="$1"
monitor="$2"
wallpaper="$3"

if [ -z "$workspace_id" ] || [ -z "$monitor" ]; then
    echo "Usage: set-wallpaper.sh <workspace_id> <monitor> [wallpaper]"
    exit 1
fi

if [ -z "$wallpaper" ]; then
    wallpaper="$(find "$HOME/.config/wallpapers/defaults" -type f | shuf -n 1)"
    if [ -z "$wallpaper" ]; then
        echo "Failed to pick a random wallpaper"
        exit 1
    fi
fi

current_config="$hyprDir/wallpaper-daemon/config/$monitor/defaults.conf"
if [ ! -f "$current_config" ]; then
    echo "Config not found for monitor '$monitor': $current_config"
    exit 1
fi

current_workspace="$(hyprctl monitors | awk -v monitor="$monitor" '/Monitor/ {m=$2} /active workspace/ && m == monitor {print $3}')"

if ! grep -q "^w-${workspace_id}=" "$current_config"; then
    echo "w-${workspace_id}=" >> "$current_config"
fi

old_wallpaper="$(grep "^w-${workspace_id}=" "$current_config" | cut -d'=' -f2- | head -n 1)"
if [ "$old_wallpaper" = "$wallpaper" ]; then
    echo "Wallpaper is already set to $wallpaper"
    exit 0
fi

if [ "$workspace_id" = "$current_workspace" ]; then
    wallpaper_ext="${wallpaper##*.}"
    wallpaper_ext="$(printf '%s' "$wallpaper_ext" | tr '[:upper:]' '[:lower:]')"
    
    if [ "$wallpaper_ext" = "gif" ] || [ "$wallpaper_ext" = "mp4" ] || [ "$wallpaper_ext" = "webm" ]; then
        "$hyprDir/wallpaper-daemon/mpvpaper.sh" "$monitor" "$wallpaper" &
    else
        "$hyprDir/wallpaper-daemon/hyprpaper.sh" "$monitor" "$wallpaper" &
    fi
fi

sed -i "s|^w-${workspace_id}=.*|w-${workspace_id}=${wallpaper}|" "$current_config"
