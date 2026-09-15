#!/usr/bin/env bash
set -euo pipefail

hyprDir="$HOME/.config/hypr"
workspace_id="${1:-}"
monitor="${2:-}"
wallpaper="${3:-}"

if [ -z "$workspace_id" ] || [ -z "$monitor" ]; then
    echo "Usage: set-wallpaper.sh <workspace_id> <monitor> [wallpaper]"
    exit 1
fi

if [ -z "$wallpaper" ]; then
    # Cached file list: full `find` rescan on every pick scales linearly.
    # Refresh cache when older than 5 min or missing.
    wall_dir="$HOME/.config/wallpapers/defaults"
    cache_list="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-list.txt"
    if [ ! -f "$cache_list" ] || [ "$wall_dir" -nt "$cache_list" ] || \
       [ $(( $(date +%s) - $(stat -c %Y "$cache_list" 2>/dev/null || echo 0) )) -gt 300 ]; then
        mkdir -p "$(dirname "$cache_list")"
        find "$wall_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' \) -print > "$cache_list.tmp.$$" 2>/dev/null \
            && mv -f "$cache_list.tmp.$$" "$cache_list"
    fi
    wallpaper="$(shuf -n 1 "$cache_list" 2>/dev/null)"
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

# Serialize config read-modify-write: concurrent invocations (workspace
# flapping, multi-monitor events) otherwise interleave grep/sed and corrupt
# defaults.conf. Hold the lock for the whole critical section below.
lock_file="${current_config}.lock"
exec 200>"$lock_file"
flock 200

current_workspace="$(hyprctl monitors -j | jq -r --arg monitor "$monitor" '.[] | select(.name == $monitor) | .activeWorkspace.id')"

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
