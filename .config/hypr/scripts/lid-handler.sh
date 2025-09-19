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

# Monitor lid events using acpi_listen
monitor_lid_events() {
    log "Starting lid event monitoring"
    
    acpi_listen | while read -r event; do
        case "$event" in
            *"button/lid"*)
                log "Lid event received: $event"
                handle_lid
                ;;
        esac
    done
}

# Check if running as systemd service or standalone
if [ "$1" = "monitor" ]; then
    monitor_lid_events
else
    handle_lid
fi
