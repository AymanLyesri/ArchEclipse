#!/bin/bash

# Lid Event Handler for Hyprland Multi-Monitor Setup
# Automatically handles lid open/close events for laptops

SCRIPT_DIR="$(dirname "$0")"
MULTI_MONITOR_SCRIPT="$SCRIPT_DIR/multi-monitor-manager.sh"

# Log file for debugging
LOG_FILE="/tmp/hyprland-lid-handler.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Handle lid event
handle_lid() {
    log "Lid event detected, calling multi-monitor manager"
    
    if [ -x "$MULTI_MONITOR_SCRIPT" ]; then
        "$MULTI_MONITOR_SCRIPT" lid
        log "Multi-monitor manager executed successfully"
    else
        log "ERROR: Multi-monitor manager script not found or not executable"
    fi
}

# Get current lid state
get_lid_state() {
    if [ -f "/proc/acpi/button/lid/LID/state" ]; then
        cat /proc/acpi/button/lid/LID/state | awk '{print $2}'
    elif [ -f "/proc/acpi/button/lid/LID0/state" ]; then
        cat /proc/acpi/button/lid/LID0/state | awk '{print $2}'
    else
        echo "unknown"
    fi
}

# Monitor lid events using acpi_listen (preferred) or polling (fallback)
monitor_lid_events() {
    log "Starting lid event monitoring"

    # Try acpi_listen first (more efficient)
    if command -v acpi_listen &>/dev/null; then
        log "Using acpi_listen for lid events"
        acpi_listen | while read -r event; do
            case "$event" in
                *"button/lid"*)
                    log "Lid event received: $event"
                    handle_lid
                    ;;
            esac
        done
    else
        # Fallback to polling /proc/acpi/button/lid
        log "acpi_listen not available, using polling fallback"
        local last_state=$(get_lid_state)
        log "Initial lid state: $last_state"

        while true; do
            sleep 2
            local current_state=$(get_lid_state)

            if [ "$current_state" != "$last_state" ]; then
                log "Lid state changed: $last_state -> $current_state"
                last_state="$current_state"
                handle_lid
            fi
        done
    fi
}

# Check if running as systemd service or standalone
if [ "$1" = "monitor" ]; then
    monitor_lid_events
else
    handle_lid
fi
