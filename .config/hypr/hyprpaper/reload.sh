#!/bin/bash
BIN_DIR=/tmp
SRC=$HOME/.config/hypr/scripts-c
hyprDir=$HOME/.config/hypr # hypr directory

# Kill existing hyprpaper and auto.sh to prevent memory leak
killall hyprpaper 2>/dev/null
pkill -f "hyprpaper-loop" 2>/dev/null

hyprpaper &

sleep 1 # Give hyprpaper a moment to start

rm "$BIN_DIR/hyprpaper-loop" 2>/dev/null

gcc "$SRC/hyprpaper-loop.c"  -o "$BIN_DIR/hyprpaper-loop"

pkill -f "hyprpaper-loop"

"$BIN_DIR/hyprpaper-loop" &
