#!/bin/bash
hyprDir=$HOME/.config/hypr # hypr directory

# Kill existing hyprpaper and auto.sh to prevent memory leak
killall hyprpaper 2>/dev/null
killall auto.sh 2>/dev/null

nohup $hyprDir/hyprpaper/load.sh & # load wallpaper
