#!/bin/bash
hyprDir=$HOME/.config/hypr # hypr directory

# hyprctl hyprpaper unload all # unload wallpaper
killall auto.sh              # kill auto.sh

nohup $hyprDir/hyprpaper/load.sh & # load wallpaper
