#!/bin/bash

# Monitor Hotplug Detection Script for AGS Multi-Monitor Support
# Automatically restarts AGS when monitors are connected/disconnected

SCRIPT_DIR="$(dirname "$0")"
MULTI_MONITOR_SCRIPT="$SCRIPT_DIR/multi-monitor-manager.sh"
LOG_FILE="/tmp/hyprland-monitor-hotplug.log"
STATE_FILE="/tmp/hyprland-monitor-state"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get current monitor configuration
get_monitor_state() {
    hyprctl monitors -j | jq -r 'sort_by(.name) | map(.name) | join(",")'
}

# Restart AGS safely
restart_ags() {
    log "Restarting AGS due to monitor configuration change"
    
    # Kill existing AGS instances
    pkill -x "ags" 2>/dev/null || true
    
    # Wait for cleanup
    sleep 1
    
    # Restart AGS
    ags run --log-file /tmp/ags.log &
    
    log "AGS restarted successfully"
}

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    get_monitor_state > "$STATE_FILE"
    log "Initialized monitor state: $(cat "$STATE_FILE")"
fi

# Monitor for changes
monitor_changes() {
    log "Starting monitor hotplug detection"
    
    while true; do
        current_state=$(get_monitor_state)
        previous_state=$(cat "$STATE_FILE" 2>/dev/null || echo "")
        
        if [ "$current_state" != "$previous_state" ]; then
            log "Monitor configuration changed:"
            log "  Previous: $previous_state"
            log "  Current:  $current_state"
            
            # Update state file
            echo "$current_state" > "$STATE_FILE"
            
            # Wait a moment for monitor setup to stabilize
            sleep 2
            
            # Restart AGS
            restart_ags
            
            # Run multi-monitor auto-configuration
            if [ -x "$MULTI_MONITOR_SCRIPT" ]; then
                log "Running multi-monitor auto-configuration"
                "$MULTI_MONITOR_SCRIPT" auto >> "$LOG_FILE" 2>&1
            fi
        fi
        
        # Check every 2 seconds
        sleep 2
    done
}

# Handle different modes
case "${1:-}" in
    "monitor")
        monitor_changes
        ;;
    "restart-ags")
        restart_ags
        ;;
    "check")
        current_state=$(get_monitor_state)
        echo "Current monitor state: $current_state"
        ;;
    *)
        echo "Monitor Hotplug Detection Script"
        echo "Usage: $0 [monitor|restart-ags|check]"
        echo "  monitor     - Start monitoring for hotplug events"
        echo "  restart-ags - Restart AGS immediately"
        echo "  check       - Check current monitor state"
        ;;
esac
