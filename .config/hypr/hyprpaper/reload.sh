#!/bin/bash
hyprDir=$HOME/.config/hypr # hypr directory

# Kill existing hyprpaper and auto.sh to prevent memory leak
killall hyprpaper 2>/dev/null
pkill -f "hyprpaper-loop" 2>/dev/null

hyprpaper &

sleep 1 # Give hyprpaper a moment to start

"/tmp/hyprpaper-loop" &
