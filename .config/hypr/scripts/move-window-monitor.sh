#!/bin/bash

# Dynamic Window Movement Script for Multi-Monitor Setup
# Moves active window to next/previous monitor dynamically

SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="/tmp/hyprland-window-movement.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get all connected monitors in order
get_monitors() {
    hyprctl monitors -j | jq -r 'sort_by(.x) | .[].name'
}

# Get current focused monitor
get_focused_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

# Get monitor by direction (next/previous)
get_target_monitor() {
    local direction="$1"
    local monitors=($(get_monitors))
    local current_monitor=$(get_focused_monitor)
    local current_index=-1
    
    # Find current monitor index
    for i in "${!monitors[@]}"; do
        if [[ "${monitors[$i]}" == "$current_monitor" ]]; then
            current_index=$i
            break
        fi
    done
    
    if [[ $current_index -eq -1 ]]; then
        log "Error: Could not find current monitor in list"
        return 1
    fi
    
    local target_index
    case "$direction" in
        "next"|"+1"|"right")
            target_index=$(( (current_index + 1) % ${#monitors[@]} ))
            ;;
        "prev"|"-1"|"left")
            target_index=$(( (current_index - 1 + ${#monitors[@]}) % ${#monitors[@]} ))
            ;;
        *)
            log "Error: Invalid direction '$direction'"
            return 1
            ;;
    esac
    
    echo "${monitors[$target_index]}"
}

# Move active window to target monitor
move_window() {
    local direction="$1"
    local target_monitor=$(get_target_monitor "$direction")
    
    if [[ -z "$target_monitor" ]]; then
        log "Error: Could not determine target monitor for direction '$direction'"
        return 1
    fi
    
    log "Moving active window from $(get_focused_monitor) to $target_monitor (direction: $direction)"
    
    # Move window to target monitor
    hyprctl dispatch movewindow "mon:$target_monitor"
    
    if [[ $? -eq 0 ]]; then
        log "Successfully moved window to $target_monitor"
    else
        log "Error: Failed to move window to $target_monitor"
        return 1
    fi
}

# Handle different commands
case "${1:-}" in
    "next"|"right"|"+1")
        move_window "next"
        ;;
    "prev"|"previous"|"left"|"-1")
        move_window "prev"
        ;;
    "list-monitors")
        get_monitors
        ;;
    "current-monitor")
        get_focused_monitor
        ;;
    "debug")
        echo "Available monitors: $(get_monitors | tr '\n' ' ')"
        echo "Current monitor: $(get_focused_monitor)"
        echo "Next monitor: $(get_target_monitor next)"
        echo "Previous monitor: $(get_target_monitor prev)"
        ;;
    *)
        echo "Dynamic Window Movement Script"
        echo "Usage: $0 [next|prev|list-monitors|current-monitor|debug]"
        echo "  next/right     - Move active window to next monitor"
        echo "  prev/left      - Move active window to previous monitor"
        echo "  list-monitors  - List all connected monitors"
        echo "  current-monitor- Show currently focused monitor"
        echo "  debug          - Show debug information"
        ;;
esac
