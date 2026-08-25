#!/bin/bash

# Record a wallpaper for a monitor, and show it right away when it is the one
# that should currently be on screen.
#
#   set-wallpaper.sh <workspace_id> <monitor> [wallpaper]   per-workspace slot
#   set-wallpaper.sh global <monitor> [wallpaper]           the one-for-all slot
#   set-wallpaper.sh --mode <workspace|global> [monitor]    switch which is used
#
# The mode lives in the monitor's own config next to the wallpapers it applies
# to, so the workspace watcher can read it without knowing anything about the
# shell's settings.

hyprDir="$HOME/.config/hypr"
configDir="$hyprDir/wallpaper-daemon/config"

monitor_config() { printf '%s/%s/defaults.conf' "$configDir" "$1"; }

wallpaper_mode() {
    local mode
    mode="$(grep '^mode=' "$(monitor_config "$1")" 2>/dev/null | cut -d'=' -f2- | head -n 1)"
    [ "$mode" = "global" ] && echo global || echo workspace
}

# Write `<key>=<value>` into a monitor config, adding the line when it is new.
write_entry() {
    local config="$1" key="$2" value="$3"
    grep -q "^${key}=" "$config" || echo "${key}=" >>"$config"
    sed -i "s|^${key}=.*|${key}=${value}|" "$config"
}

read_entry() {
    grep "^${2}=" "$1" 2>/dev/null | cut -d'=' -f2- | head -n 1
}

# --mode: record the mode, then show whatever that mode says belongs on screen.
if [ "$1" = "--mode" ]; then
    mode="$2"
    if [ "$mode" != "workspace" ] && [ "$mode" != "global" ]; then
        echo "Usage: set-wallpaper.sh --mode <workspace|global> [monitor]" >&2
        exit 1
    fi

    monitors="$3"
    [ -n "$monitors" ] || monitors="$(hyprctl monitors -j | jq -r '.[].name')"

    for name in $monitors; do
        config="$(monitor_config "$name")"
        [ -f "$config" ] || continue
        write_entry "$config" mode "$mode"

        if [ "$mode" = "global" ]; then
            wallpaper="$(read_entry "$config" global)"
        else
            workspace="$(hyprctl monitors -j |
                jq -r --arg m "$name" '.[] | select(.name == $m) | .activeWorkspace.id')"
            wallpaper="$(read_entry "$config" "w-${workspace}")"
        fi

        [ -n "$wallpaper" ] && "$hyprDir/wallpaper-daemon/apply.sh" "$name" "$wallpaper" &
    done
    exit 0
fi

target="$1"
monitor="$2"
wallpaper="$3"

if [ -z "$target" ] || [ -z "$monitor" ]; then
    echo "Usage: set-wallpaper.sh <workspace_id|global> <monitor> [wallpaper]"
    exit 1
fi

if [ -z "$wallpaper" ]; then
    wallpaper="$(find "$HOME/.config/wallpapers/defaults" -type f | shuf -n 1)"
    if [ -z "$wallpaper" ]; then
        echo "Failed to pick a random wallpaper"
        exit 1
    fi
fi

current_config="$(monitor_config "$monitor")"
if [ ! -f "$current_config" ]; then
    echo "Config not found for monitor '$monitor': $current_config"
    exit 1
fi

if [ "$target" = "global" ]; then
    key="global"
    # The global wallpaper is on screen whenever the monitor is in global mode.
    [ "$(wallpaper_mode "$monitor")" = "global" ] && on_screen=1 || on_screen=0
else
    key="w-${target}"
    current_workspace="$(hyprctl monitors -j |
        jq -r --arg monitor "$monitor" '.[] | select(.name == $monitor) | .activeWorkspace.id')"
    [ "$target" = "$current_workspace" ] &&
        [ "$(wallpaper_mode "$monitor")" = "workspace" ] && on_screen=1 || on_screen=0
fi

old_wallpaper="$(read_entry "$current_config" "$key")"
if [ "$old_wallpaper" = "$wallpaper" ]; then
    echo "Wallpaper is already set to $wallpaper"
    exit 0
fi

if [ "$on_screen" = 1 ]; then
    "$hyprDir/wallpaper-daemon/apply.sh" "$monitor" "$wallpaper" &
fi

write_entry "$current_config" "$key" "$wallpaper"
