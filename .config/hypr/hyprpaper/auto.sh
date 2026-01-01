#!/bin/bash

hyprDir=$HOME/.config/hypr                       # hypr directory
defaults=$hyprDir/hyprpaper/config/defaults.conf # config file

declare -A previous_workspace_ids
declare -A current_wallpapers

change_wallpaper() {
    # Get all monitors and their active workspaces
    local monitors=$(hyprctl monitors | awk '/Monitor/ {print $2}')
    
    for monitor in $monitors; do
        local workspace_id=$(hyprctl monitors | awk -v monitor="$monitor" '/Monitor/ {m=$2} /active workspace/ && m == monitor {print $3}')
        
        # If workspace hasn't changed, skip the rest of the function for this monitor
        if [ "${previous_workspace_ids[$monitor]}" == "$workspace_id" ]; then
            continue
        fi
        
        # Get the wallpaper from the config only if needed
        local wallpaper=$(awk -F= -v wsid="w-$workspace_id" '$1 == wsid {print $2}' "$hyprDir/hyprpaper/config/$monitor/defaults.conf")
        
        # Check if wallpaper is valid and has changed
        if [ "$wallpaper" ] && [ "$wallpaper" != "${current_wallpapers[$monitor]}" ]; then
            echo "$wallpaper" >"$hyprDir/hyprpaper/config/current.conf"
            
            # Kill the wallpaper script only if it's already running
            pgrep -f "$hyprDir/hyprpaper/w.sh" && killall w.sh
            
            # Run the wallpaper script with the new wallpaper
            $hyprDir/hyprpaper/w.sh "$monitor" "$(eval echo "$wallpaper")" &
            
            # Update current wallpaper and workspace ID for this monitor
            current_wallpapers[$monitor]=$wallpaper
            previous_workspace_ids[$monitor]=$workspace_id
        fi
    done
}

# Initial wallpaper setup
change_wallpaper

# Listen to workspace changes via Hyprland socket
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
    change_wallpaper
done
