#!/bin/bash
hyprDir=$HOME/.config/hypr # hypr directory

new_wallpaper=""

#############################################

# check for $1 (workspace_id)
if [ -z "$1" ]; then
    echo "Usage: set-wallpaper.sh <workspace_id> <monitor> <wallpaper>"
    exit 1
else
    echo "Setting random wallpaper for workspace $1"
    workspace_id=$1
fi

# check for $2 (monitor)
if [ -z "$2" ]; then
    echo "Usage: set-wallpaper.sh <workspace_id> <monitor> <wallpaper>"
    # monitor=$(hyprctl monitors | awk '/Monitor/ {monitor=$2} /focused: yes/ {print monitor}')
    # echo "Setting wallpaper for monitor $monitor"
    exit 1
else
    monitor=$2
fi

# check for $3 (wallpaper)
if [ -z "$3" ]; then
    echo "Setting random wallpaper for workspace $workspace_id"
    new_wallpaper=$(find $HOME/.config/wallpapers/defaults -type f | shuf -n 1 ) # get random wallpaper
    echo "New wallpaper: $new_wallpaper"
else
    echo "Setting wallpaper $3 for workspace $workspace_id"
    new_wallpaper=$(echo $3) # get wallpaper
    echo "New wallpaper: $new_wallpaper"
fi

#############################################

current_config=$hyprDir/hyprpaper/config/$monitor/defaults.conf # config file
current_workspace=$(hyprctl monitors | awk -v monitor="$monitor" '/Monitor/ {m=$2} /active workspace/ && m == monitor {print $3}')

#############################################

old_wallpaper=$(grep "^w-${workspace_id}=" "$current_config" | cut -d'=' -f2 | head -n 1)

#check if wallpaper is the same
if [ "$old_wallpaper" = "$new_wallpaper" ]; then
    echo "Wallpaper is already set to $new_wallpaper"
    exit 0
fi

# Note: In hyprpaper 0.8+ preload/unload no longer work via hyprctl
# The wallpaper is loaded automatically when applied

sed -i "s|w-${workspace_id}=.*|w-${workspace_id}=|" $current_config # clear old entry

# hyprctl hyprpaper unload "$old_wallpaper" # unload old wallpaper

#############################################

if [ "$workspace_id" = "$current_workspace" ]; then
    $hyprDir/hyprpaper/w.sh $monitor "$new_wallpaper" & # set wallpaper
fi

# #############################################

sed -i "s|w-${workspace_id}=.*|w-${workspace_id}=${new_wallpaper}|" $current_config # set wallpaper in config
