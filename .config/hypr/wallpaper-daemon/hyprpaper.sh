#!/bin/bash

# Define variables
hyprdir=$HOME/.config/hypr
monitor=$1
wallpaper=$2 # This is passed as an argument to the script

# Stop any running mpvpaper instance on this monitor when switching to static wallpaper
pkill -f "mpvpaper.*${monitor}" 2>/dev/null

# Apply wallpaper directly (hyprpaper 0.8+ no longer requires preload)
hyprctl hyprpaper wallpaper "$monitor,$wallpaper"

sleep 1 # Wait for wallpaper to be set (removes stuttering)

# Set wallpaper theme
"$hyprdir/theme/scripts/wal-theme.sh" "$wallpaper"
