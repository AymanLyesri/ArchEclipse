#!/bin/bash
#
# set-wallpaper.sh <slot> <monitor> [wallpaper]
#
# <slot> is one of:
#   <number>  - assign to that workspace      (stored as w-<number>=)
#   global    - the single Global-mode wallpaper (stored as global=)
#   primary   - the fallback wallpaper        (stored as primary=)
#
# Whether the wallpaper is rendered immediately depends on the configured
# wallpaper mode (Global vs Per Workspace) and the currently active workspace.

hyprDir="$HOME/.config/hypr"
slot="$1"
monitor="$2"
wallpaper="$3"

if [ -z "$slot" ] || [ -z "$monitor" ]; then
    echo "Usage: set-wallpaper.sh <slot|global|primary> <monitor> [wallpaper]"
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

# Map the slot to its config key.
case "$slot" in
    global) key="global" ;;
    primary) key="primary" ;;
    *) key="w-${slot}" ;;
esac

read_key() { grep "^$1=" "$current_config" | cut -d'=' -f2- | head -n 1; }

# Apply a wallpaper using the appropriate backend for its type (see dispatch.sh).
dispatch() {
    "$hyprDir/wallpaper-daemon/dispatch.sh" "$monitor" "$1" &
}

# Read the configured wallpaper mode (default: per-workspace).
settings="$HOME/.config/ags/cache/settings/settings.json"
mode="workspace"
if command -v jq >/dev/null 2>&1 && [ -f "$settings" ]; then
    m="$(jq -r '(.wallpaper.mode.value) // "workspace"' "$settings" 2>/dev/null)"
    [ -n "$m" ] && mode="$m"
fi

current_workspace="$(hyprctl monitors -j | jq -r --arg monitor "$monitor" '.[] | select(.name == $monitor) | .activeWorkspace.id')"

# Ensure the key exists so the upsert below can replace it.
if ! grep -q "^${key}=" "$current_config"; then
    echo "${key}=" >> "$current_config"
fi

old_wallpaper="$(read_key "$key")"

# Decide whether the change is visible right now and should be rendered.
render=false
if [ "$mode" = "global" ]; then
    if [ "$slot" = "global" ]; then
        render=true
    elif [ "$slot" = "primary" ] && [ -z "$(read_key global)" ]; then
        # Primary is the effective wallpaper when no Global wallpaper is set.
        render=true
    fi
else
    if [ "$slot" = "$current_workspace" ]; then
        render=true
    elif [ "$slot" = "primary" ] && [ -z "$(read_key "w-${current_workspace}")" ]; then
        # Primary is the effective wallpaper when the active workspace is unset.
        render=true
    fi
fi

# Skip re-rendering if the value didn't actually change.
if [ "$old_wallpaper" = "$wallpaper" ]; then
    render=false
fi

[ "$render" = true ] && dispatch "$wallpaper"

sed -i "s|^${key}=.*|${key}=${wallpaper}|" "$current_config"
