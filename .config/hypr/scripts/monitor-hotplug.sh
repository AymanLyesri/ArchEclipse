#!/bin/bash

# Monitor Hotplug Detection Script for AGS Multi-Monitor Support
# Automatically restarts AGS and reloads hyperpaper when monitors are connected/disconnected

SCRIPT_DIR="$(dirname "$0")"
HYPR_DIR="$HOME/.config/hypr"
MULTI_MONITOR_SCRIPT="$SCRIPT_DIR/multi-monitor-manager.sh"
HYPERPAPER_RELOAD="$HYPR_DIR/hyprpaper/reload.sh"
WORKSPACE_STATE_MANAGER="$SCRIPT_DIR/workspace-state-manager.sh"
BAR_VALIDATOR="$SCRIPT_DIR/validate-bar.sh"
LOG_FILE="/tmp/hyprland-monitor-hotplug.log"
STATE_FILE="/tmp/hyprland-monitor-state"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get current monitor configuration
get_monitor_state() {
    local state
    local exit_code
    
    # Try to get monitor state, handle jq parse errors gracefully
    state=$(hyprctl monitors -j 2>&1 | jq -r 'sort_by(.name) | map(.name) | join(",")' 2>&1)
    exit_code=$?
    
    # If jq fails or returns empty, try a simpler approach
    if [ -z "$state" ] || [ $exit_code -ne 0 ]; then
        state=$(hyprctl monitors 2>&1 | awk '/Monitor/ {print $2}' | sort | tr '\n' ',' | sed 's/,$//')
    fi
    
    echo "$state"
}

# Restart AGS safely
restart_ags() {
    log "Restarting AGS due to monitor configuration change"
    
    # Kill existing AGS and related processes more aggressively
    pkill -9 -f "ags" 2>/dev/null || true
    pkill -9 -f "astal" 2>/dev/null || true
    
    # Also kill any stale gjs processes from AGS
    pgrep -f "gjs.*ags" | xargs -r kill -9 2>/dev/null || true
    
    # Wait for cleanup
    sleep 2
    
    # Verify processes are dead
    if pgrep -x "ags" > /dev/null; then
        log "Warning: AGS processes still running, forcing kill"
        pkill -9 "ags" 2>/dev/null || true
        sleep 1
    fi
    
    # Restart AGS (GDK_BACKEND=wayland required for gtk4-layer-shell multi-monitor)
    log "Starting AGS"
    killall gjs 2>/dev/null || true
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so GDK_BACKEND=wayland ags run --gtk 3 --log-file /tmp/ags.log >> "$LOG_FILE" 2>&1 &
    
    # Give it a moment to start
    sleep 1
    
    # Verify AGS started
    if pgrep -x "ags" > /dev/null; then
        log "AGS restarted successfully (PID: $(pgrep -x ags))"
    else
        log "ERROR: AGS failed to start"
    fi
}

# Validate bar after AGS restart
validate_bar() {
    log "Validating AGS bar configuration"

    if [ -x "$BAR_VALIDATOR" ]; then
        # Run validation with auto-retry (will restart AGS if needed)
        local result=$("$BAR_VALIDATOR" validate-retry 2>&1)
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log "Bar validation successful"
        else
            log "Bar validation failed: $result"
        fi

        return $exit_code
    else
        log "Warning: Bar validator not found or not executable: $BAR_VALIDATOR"
        return 1
    fi
}

# Reload hyperpaper safely
reload_hyperpaper() {
    log "Reloading hyperpaper due to monitor configuration change"
    
    # Execute hyperpaper reload script
    if [ -x "$HYPERPAPER_RELOAD" ]; then
        bash "$HYPERPAPER_RELOAD" >> "$LOG_FILE" 2>&1 &
        log "Hyperpaper reload initiated"
    else
        log "Warning: Hyperpaper reload script not found or not executable: $HYPERPAPER_RELOAD"
    fi
}

# Convert monitor state string to profile name (e.g., "eDP-1,DP-4" -> "eDP-1_DP-4")
state_to_profile() {
    echo "$1" | tr ',' '_'
}

# Save workspace state for the OLD profile before monitor changes
save_workspace_state_for_profile() {
    local old_profile="$1"
    local new_profile="$2"

    log "Saving workspace state for outgoing profile '$old_profile'"

    if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
        # Use handle-change which saves state for the old profile
        local result=$("$WORKSPACE_STATE_MANAGER" handle-change "$old_profile" "$new_profile" 2>&1)
        log "Workspace state: $result"
    else
        log "Warning: Workspace state manager not found or not executable: $WORKSPACE_STATE_MANAGER"
    fi
}

# Restore workspace state for the NEW profile after monitor changes
restore_workspace_state() {
    log "Checking for workspace state to restore"

    if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
        local current_profile=$("$WORKSPACE_STATE_MANAGER" profile 2>/dev/null)
        log "Current profile: $current_profile"

        # Check if restore is pending for current profile
        if [ "$("$WORKSPACE_STATE_MANAGER" pending 2>/dev/null)" = "true" ]; then
            log "Pending restore flag detected for '$current_profile', restoring..."
            local result=$("$WORKSPACE_STATE_MANAGER" auto-restore 2>&1)
            log "Workspace restore: $result"
        else
            log "No pending restore for profile '$current_profile'"
        fi
    else
        log "Warning: Workspace state manager not found or not executable: $WORKSPACE_STATE_MANAGER"
    fi
}

# Initialize state file with retry logic
initialize_state() {
    log "Initializing monitor state..."
    local retry_count=0
    local max_retries=10
    local state=""
    
    while [ $retry_count -lt $max_retries ]; do
        state=$(get_monitor_state)
        
        # Check if we got a valid state (not empty)
        if [ -n "$state" ]; then
            echo "$state" > "$STATE_FILE"
            log "Initialized monitor state: $state"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        log "Failed to get monitor state (attempt $retry_count/$max_retries), retrying in 2 seconds..."
        sleep 2
    done
    
    log "ERROR: Failed to initialize monitor state after $max_retries attempts"
    return 1
}

# Initialize state file if it doesn't exist or is empty
if [ ! -f "$STATE_FILE" ] || [ ! -s "$STATE_FILE" ]; then
    initialize_state || exit 1
fi

# Periodic state save counter (save every N iterations when stable)
PERIODIC_SAVE_INTERVAL=30  # Save every 60 seconds (30 iterations * 2 seconds)
periodic_counter=0

# Monitor for changes
monitor_changes() {
    log "Starting monitor hotplug detection"

    while true; do
        current_state=$(get_monitor_state)
        previous_state=$(cat "$STATE_FILE" 2>/dev/null || echo "")

        # Skip if current state is empty (hyprctl might have failed)
        if [ -z "$current_state" ]; then
            log "Warning: Could not get current monitor state (output was empty), skipping this check"
            log "Debug: Trying manual hyprctl call..."
            hyprctl monitors 2>&1 | head -5 >> "$LOG_FILE"
            sleep 2
            continue
        fi

        # Only process if there's an actual change AND both states are non-empty
        if [ "$current_state" != "$previous_state" ] && [ -n "$previous_state" ]; then
            log "Monitor configuration changed:"
            log "  Previous: $previous_state"
            log "  Current:  $current_state"

            # Convert states to profile names
            local old_profile=$(state_to_profile "$previous_state")
            local new_profile=$(state_to_profile "$current_state")
            log "  Profile change: '$old_profile' -> '$new_profile'"

            # NOTE: We don't save here anymore because Hyprland has already
            # moved windows when we detect the change. Instead, we rely on
            # periodic saves that happen while the configuration is stable.
            log "Using last periodic save for profile '$old_profile'"

            # Create pending restore flag for the NEW profile
            # (so it will restore when we check after reconfiguration)
            local pending_flag="$HOME/.cache/hypr/workspace-states/pending-${new_profile}"
            if [ -f "$HOME/.cache/hypr/workspace-states/state-${new_profile}.json" ]; then
                touch "$pending_flag"
                log "Created pending restore flag for '$new_profile'"
            fi

            # Update state file
            echo "$current_state" > "$STATE_FILE"

            # Reset periodic counter after a change
            periodic_counter=0

            # Wait a moment for monitor setup to stabilize
            sleep 2

            # Run multi-monitor auto-configuration first
            if [ -x "$MULTI_MONITOR_SCRIPT" ]; then
                log "Running multi-monitor auto-configuration"
                "$MULTI_MONITOR_SCRIPT" auto >> "$LOG_FILE" 2>&1
            fi

            # Wait for monitor configuration to apply
            sleep 1

            # Determine if monitor was added or removed
            local old_count=$(echo "$previous_state" | tr ',' '\n' | wc -l)
            local new_count=$(echo "$current_state" | tr ',' '\n' | wc -l)

            # Redistribute workspaces based on new monitor configuration
            # This moves all workspaces to external monitor except btop's workspace
            if [ -x "$MULTI_MONITOR_SCRIPT" ]; then
                log "Redistributing workspaces (monitors: $old_count -> $new_count)"
                "$MULTI_MONITOR_SCRIPT" redistribute >> "$LOG_FILE" 2>&1
            fi

            # Wait for workspace redistribution
            sleep 1

            # Restart AGS
            restart_ags

            # Validate bar is correctly displayed (with auto-retry)
            sleep 1
            validate_bar

            # Reload hyperpaper
            reload_hyperpaper
        else
            # No change - increment periodic save counter
            periodic_counter=$((periodic_counter + 1))

            # Periodic save when stable (silent, no notifications)
            if [ $periodic_counter -ge $PERIODIC_SAVE_INTERVAL ]; then
                periodic_counter=0
                if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
                    # Silent save - uses "silent" argument to suppress notifications
                    local current_profile=$(state_to_profile "$current_state")
                    "$WORKSPACE_STATE_MANAGER" save silent >/dev/null 2>&1
                    log "Periodic workspace state save for profile '$current_profile'"
                fi
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
    "reload-hyperpaper")
        reload_hyperpaper
        ;;
    "reload-all")
        restart_ags
        sleep 1
        validate_bar
        reload_hyperpaper
        ;;
    "validate-bar")
        validate_bar
        ;;
    "check")
        current_state=$(get_monitor_state)
        echo "Current monitor state: $current_state"
        ;;
    "save-workspace")
        if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
            "$WORKSPACE_STATE_MANAGER" save
        fi
        ;;
    "restore-workspace")
        restore_workspace_state
        ;;
    "workspace-status")
        if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
            "$WORKSPACE_STATE_MANAGER" status
        fi
        ;;
    "workspace-profiles")
        if [ -x "$WORKSPACE_STATE_MANAGER" ]; then
            "$WORKSPACE_STATE_MANAGER" profiles
        fi
        ;;
    *)
        echo "Monitor Hotplug Detection Script"
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  monitor             - Start monitoring for hotplug events"
        echo "  restart-ags         - Restart AGS immediately"
        echo "  reload-hyperpaper   - Reload hyperpaper immediately"
        echo "  reload-all          - Restart AGS, validate bar, and reload hyperpaper"
        echo "  validate-bar        - Validate bar is correctly displayed (with auto-retry)"
        echo "  check               - Check current monitor state"
        echo ""
        echo "Workspace commands:"
        echo "  save-workspace      - Save current workspace layout"
        echo "  restore-workspace   - Restore workspace layout for current profile"
        echo "  workspace-status    - Show workspace state manager status"
        echo "  workspace-profiles  - List all saved workspace profiles"
        ;;
esac
