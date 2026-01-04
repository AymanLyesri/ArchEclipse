#!/bin/bash

# Workspace State Manager for Hyprland (v4.0)
# Saves and restores window positions across monitor changes (KVM switch support)
#
# v4.0 Features:
# - Workspace-to-monitor NAME mapping (not just ID)
# - Restores workspaces to correct monitors after reconnection
# - Stores monitor names (eDP-1, DP-3) instead of volatile IDs
#
# v3.0 Features:
# - Multiple profiles based on monitor configuration
# - Separate state for "laptop only" vs "laptop + external"
# - Seamless switching between KVM and direct laptop use
# - Flag-based restore (no timeout)
# - Better window matching (PID + title + multiple instances)
# - Floating window positions and sizes

STATE_DIR="$HOME/.cache/hypr/workspace-states"
LOG_FILE="/tmp/hyprland-workspace-state.log"
MAX_BACKUPS=5
NOTIFY_ENABLED=true
WORKSPACE_PREFS_FILE="$STATE_DIR/workspace-monitor-prefs.json"

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
}

# Send desktop notification
# Usage: notify "title" "body" "icon" [urgency]
notify() {
    [ "$NOTIFY_ENABLED" != "true" ] && return

    local title="$1"
    local body="$2"
    local icon="${3:-display}"
    local urgency="${4:-normal}"

    notify-send \
        --app-name="Workspace Manager" \
        --urgency="$urgency" \
        --icon="$icon" \
        --hint=string:x-canonical-private-synchronous:workspace-manager \
        "$title" "$body" 2>/dev/null &
}

# ============================================================================
# WORKSPACE-MONITOR PREFERENCES (v5.0)
# These preferences persist across sessions and aren't overwritten when
# monitors disconnect. They remember which workspace SHOULD be on which monitor.
# ============================================================================

# Initialize workspace preferences file if it doesn't exist
init_workspace_prefs() {
    if [ ! -f "$WORKSPACE_PREFS_FILE" ]; then
        echo '{}' > "$WORKSPACE_PREFS_FILE"
        log "Initialized workspace preferences file"
    fi
}

# Get current workspace preferences
get_workspace_prefs() {
    init_workspace_prefs
    cat "$WORKSPACE_PREFS_FILE" 2>/dev/null || echo '{}'
}

# Save a workspace-monitor preference
# Only called when user explicitly moves workspace OR when external monitor is connected
# Args: profile, workspace_id, monitor_name
save_workspace_pref() {
    local profile="$1"
    local ws_id="$2"
    local mon_name="$3"

    init_workspace_prefs

    # Only save preference if this is a multi-monitor profile
    local monitor_count=$(echo "$profile" | tr '_' '\n' | wc -l)
    if [ "$monitor_count" -lt 2 ]; then
        log "Skipping pref save for single-monitor profile '$profile'"
        return 0
    fi

    local prefs=$(get_workspace_prefs)
    local updated=$(echo "$prefs" | jq --arg profile "$profile" --arg ws "$ws_id" --arg mon "$mon_name" '
        .[$profile] = ((.[$profile] // {}) | .[$ws] = $mon)
    ')

    echo "$updated" > "$WORKSPACE_PREFS_FILE"
    log "Saved preference: WS $ws_id -> $mon_name (profile: $profile)"
}

# Get preferred monitor for a workspace in a profile
# Returns empty string if no preference exists
get_workspace_pref() {
    local profile="$1"
    local ws_id="$2"

    local prefs=$(get_workspace_prefs)
    echo "$prefs" | jq -r --arg profile "$profile" --arg ws "$ws_id" '.[$profile][$ws] // ""'
}

# Update preferences based on CURRENT workspace layout
# Only call this when monitors are stable and user has arranged workspaces
update_all_workspace_prefs() {
    local profile=$(get_monitor_profile)

    # Only update for multi-monitor profiles
    local monitor_count=$(echo "$profile" | tr '_' '\n' | wc -l)
    if [ "$monitor_count" -lt 2 ]; then
        log "Skipping pref update for single-monitor profile"
        return 0
    fi

    log "Updating workspace preferences for profile '$profile'"

    # Get current workspace-to-monitor mapping
    local ws_map=$(hyprctl workspaces -j 2>/dev/null | jq -c '[.[] | select(.id > 0) | {key: (.id | tostring), value: .monitor}] | from_entries')

    # Update each workspace preference
    echo "$ws_map" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read ws_id mon_name; do
        if [ -n "$ws_id" ] && [ -n "$mon_name" ]; then
            save_workspace_pref "$profile" "$ws_id" "$mon_name"
        fi
    done

    log "Workspace preferences updated"
}

# Get the preferred workspace-monitor map for a profile
# Falls back to saved state if no preferences exist
get_preferred_workspace_map() {
    local profile="$1"
    local state_file=$(get_state_file "$profile")

    local prefs=$(get_workspace_prefs)
    local profile_prefs=$(echo "$prefs" | jq -c --arg profile "$profile" '.[$profile] // {}')

    # If we have preferences for this profile, use them
    if [ "$profile_prefs" != "{}" ] && [ "$profile_prefs" != "null" ]; then
        log "Using saved workspace preferences for '$profile'"
        echo "$profile_prefs"
        return 0
    fi

    # Fall back to state file
    if [ -f "$state_file" ]; then
        local state_map=$(jq -c '.workspaceMonitorMap // {}' "$state_file" 2>/dev/null)
        if [ "$state_map" != "{}" ] && [ "$state_map" != "null" ]; then
            log "Using workspace map from state file for '$profile'"
            echo "$state_map"
            return 0
        fi
    fi

    echo '{}'
}

# Get the default external monitor for a profile (first non-eDP monitor)
get_default_external_monitor() {
    local profile="$1"
    # Extract monitor names from profile and find the external one
    echo "$profile" | tr '_' '\n' | grep -v "^eDP" | head -1
}

# Get the internal monitor name
get_internal_monitor() {
    echo "eDP-1"
}

# Get a friendly profile name for notifications
get_friendly_profile_name() {
    local profile="$1"
    local monitor_count=$(echo "$profile" | tr '_' '\n' | wc -l)

    if [ "$monitor_count" -eq 1 ]; then
        echo "Laptop Only"
    elif [ "$monitor_count" -eq 2 ]; then
        echo "Dual Monitor"
    elif [ "$monitor_count" -gt 2 ]; then
        echo "${monitor_count} Monitors"
    else
        echo "$profile"
    fi
}

# Get current monitor configuration as a profile name
# Returns sorted monitor names joined by underscore (e.g., "eDP-1_DP-4")
get_monitor_profile() {
    local profile=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[].name] | sort | join("_")')
    if [ -z "$profile" ] || [ "$profile" = "null" ]; then
        echo "unknown"
    else
        echo "$profile"
    fi
}

# Get state file path for a specific profile
get_state_file() {
    local profile="${1:-$(get_monitor_profile)}"
    echo "$STATE_DIR/state-${profile}.json"
}

# Get pending flag file path for a specific profile
get_pending_flag() {
    local profile="${1:-$(get_monitor_profile)}"
    echo "$STATE_DIR/pending-${profile}"
}

# Get current workspace state with enhanced window information
# Optional: pass a profile name to override auto-detection
get_workspace_state() {
    local override_profile="$1"
    log "Capturing current workspace state..."

    local profile
    if [ -n "$override_profile" ]; then
        profile="$override_profile"
        log "Using override profile: $profile"
    else
        profile=$(get_monitor_profile)
    fi

    # Get monitor info with name mapping (id -> name)
    local monitor_info=$(hyprctl monitors -j 2>/dev/null | jq -c '[.[] | {name: .name, id: .id, width: .width, height: .height}]')

    # Create monitor ID to name lookup
    local monitor_id_to_name=$(hyprctl monitors -j 2>/dev/null | jq -c '[.[] | {key: (.id | tostring), value: .name}] | from_entries')

    # Get workspace to monitor mapping (workspace id -> monitor name)
    local workspace_monitor_map=$(hyprctl workspaces -j 2>/dev/null | jq -c '[.[] | select(.id > 0) | {key: (.id | tostring), value: .monitor}] | from_entries')

    # Get all clients with extended info, including MONITOR NAME instead of just ID
    local windows=$(hyprctl clients -j 2>/dev/null | jq -c --argjson mon_map "$monitor_id_to_name" '[.[] | {
        address: .address,
        class: .class,
        initialClass: .initialClass,
        title: .title,
        initialTitle: .initialTitle,
        workspace: .workspace.id,
        monitor: .monitor,
        monitorName: ($mon_map[.monitor | tostring] // "unknown"),
        pid: .pid,
        floating: .floating,
        at: .at,
        size: .size,
        fullscreen: .fullscreen,
        fullscreenMode: .fullscreenMode,
        mapped: .mapped,
        hidden: .hidden,
        pinned: .pinned
    }]')

    if [ $? -eq 0 ] && [ -n "$windows" ] && [ "$windows" != "null" ] && [ "$windows" != "[]" ]; then
        local final_state=$(jq -n \
            --argjson windows "$windows" \
            --argjson monitors "$monitor_info" \
            --argjson workspaceMonitorMap "$workspace_monitor_map" \
            --arg timestamp "$(date -Iseconds)" \
            --arg profile "$profile" \
            '{
                version: 4,
                profile: $profile,
                timestamp: $timestamp,
                monitors: $monitors,
                workspaceMonitorMap: $workspaceMonitorMap,
                windows: $windows
            }')

        echo "$final_state"
        log "State captured: $(echo "$windows" | jq length) windows for profile '$profile'"
        return 0
    else
        error "Failed to capture workspace state"
        return 1
    fi
}

# Save current workspace state to the appropriate profile
# Optional: pass "silent" as first argument to suppress notifications
save_state() {
    local silent="${1:-}"
    local profile=$(get_monitor_profile)
    local state_file=$(get_state_file "$profile")
    local pending_flag=$(get_pending_flag "$profile")

    log "=== Saving workspace state for profile '$profile' ==="

    local state=$(get_workspace_state)

    if [ $? -eq 0 ] && [ -n "$state" ]; then
        # Save current state
        echo "$state" > "$state_file"

        # Create pending restore flag for THIS profile
        touch "$pending_flag"

        log "State saved to $state_file"
        log "Pending flag created: $pending_flag"

        # Create timestamped backup
        local backup="$STATE_DIR/backup-${profile}-$(date +%Y%m%d-%H%M%S).json"
        echo "$state" > "$backup"

        # Keep only last N backups per profile
        ls -t "$STATE_DIR"/backup-${profile}-*.json 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm

        # NOTE: We do NOT update workspace preferences during regular saves
        # because this could overwrite correct preferences right after a restore.
        # Preferences should only be updated via explicit 'update-prefs' command.

        local window_count=$(echo "$state" | jq '.windows | length')
        local friendly_name=$(get_friendly_profile_name "$profile")

        # Send notification (unless silent mode)
        if [ "$silent" != "silent" ]; then
            notify "💾 Workspace Saved" \
                "$friendly_name\n$window_count windows preserved" \
                "document-save"
        fi

        echo "State saved for profile '$profile' ($window_count windows)"
        return 0
    else
        error "Failed to save workspace state"
        if [ "$silent" != "silent" ]; then
            notify "❌ Workspace Save Failed" \
                "Could not save workspace state" \
                "dialog-error" "critical"
        fi
        return 1
    fi
}

# Save state for a specific profile (used during monitor change)
# This captures the CURRENT window positions and saves them under the specified profile
save_state_for_profile() {
    local target_profile="$1"
    local state_file=$(get_state_file "$target_profile")
    local pending_flag=$(get_pending_flag "$target_profile")

    log "=== Saving state for profile '$target_profile' (pre-change) ==="

    # Pass the target profile to get_workspace_state so it gets recorded correctly
    local state=$(get_workspace_state "$target_profile")

    if [ $? -eq 0 ] && [ -n "$state" ]; then
        echo "$state" > "$state_file"
        touch "$pending_flag"

        local window_count=$(echo "$state" | jq '.windows | length')
        local friendly_name=$(get_friendly_profile_name "$target_profile")

        # Send notification for profile change
        notify "🔄 Monitor Change Detected" \
            "Saving $friendly_name\n$window_count windows stored" \
            "system-switch-user"

        log "State saved for profile '$target_profile'"
        return 0
    fi
    return 1
}

# Find matching window in current windows using fingerprinting
find_matching_window() {
    local saved_window="$1"
    local current_windows="$2"
    local used_addresses="$3"

    local saved_class=$(echo "$saved_window" | jq -r '.class // ""')
    local saved_initial=$(echo "$saved_window" | jq -r '.initialClass // ""')
    local saved_title=$(echo "$saved_window" | jq -r '.title // ""')
    local saved_pid=$(echo "$saved_window" | jq -r '.pid // 0')

    # Strategy 1: Exact PID match (best case - same process still running)
    if [ "$saved_pid" != "0" ] && [ "$saved_pid" != "null" ]; then
        local pid_match=$(echo "$current_windows" | jq -r \
            --arg pid "$saved_pid" \
            --arg used "$used_addresses" \
            '[.[] | select(.pid == ($pid | tonumber) and (.address | inside($used) | not))] | .[0].address // ""')

        if [ -n "$pid_match" ] && [ "$pid_match" != "null" ]; then
            echo "$pid_match"
            return 0
        fi
    fi

    # Strategy 2: initialClass + title prefix match
    local title_prefix=$(echo "$saved_title" | cut -c1-30)
    local class_title_match=$(echo "$current_windows" | jq -r \
        --arg initial "$saved_initial" \
        --arg class "$saved_class" \
        --arg title_prefix "$title_prefix" \
        --arg used "$used_addresses" \
        '[.[] | select(
            ((.initialClass == $initial and $initial != "") or (.class == $class and $class != "")) and
            ((.title // "") | startswith($title_prefix)) and
            (.address | inside($used) | not)
        )] | .[0].address // ""')

    if [ -n "$class_title_match" ] && [ "$class_title_match" != "null" ]; then
        echo "$class_title_match"
        return 0
    fi

    # Strategy 3: initialClass or class match only
    local class_match=$(echo "$current_windows" | jq -r \
        --arg initial "$saved_initial" \
        --arg class "$saved_class" \
        --arg used "$used_addresses" \
        '[.[] | select(
            ((.initialClass == $initial and $initial != "") or (.class == $class and $class != "")) and
            (.address | inside($used) | not)
        )] | .[0].address // ""')

    if [ -n "$class_match" ] && [ "$class_match" != "null" ]; then
        echo "$class_match"
        return 0
    fi

    echo ""
    return 1
}

# Check if a workspace exists
workspace_exists() {
    local ws="$1"
    hyprctl workspaces -j 2>/dev/null | jq -e --arg ws "$ws" '.[] | select(.id == ($ws | tonumber))' > /dev/null 2>&1
}

# Create workspace if it doesn't exist
ensure_workspace() {
    local ws="$1"
    if ! workspace_exists "$ws"; then
        log "Creating workspace $ws"
        hyprctl dispatch workspace "$ws" > /dev/null 2>&1
        sleep 0.1
    fi
}

# Get current monitor name to ID mapping
get_current_monitor_map() {
    hyprctl monitors -j 2>/dev/null | jq -c '[.[] | {key: .name, value: .id}] | from_entries'
}

# Move a workspace to a specific monitor by name
move_workspace_to_monitor() {
    local workspace_id="$1"
    local target_monitor="$2"

    # Check if monitor exists
    local monitor_exists=$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$target_monitor" '.[] | select(.name == $mon) | .name')

    if [ -n "$monitor_exists" ]; then
        log "Moving workspace $workspace_id to monitor $target_monitor"
        hyprctl dispatch moveworkspacetomonitor "$workspace_id" "$target_monitor" > /dev/null 2>&1
        return 0
    else
        log "Monitor $target_monitor not available, skipping workspace $workspace_id move"
        return 1
    fi
}

# Restore windows from a specific profile's state
restore_state() {
    local profile="${1:-$(get_monitor_profile)}"
    local state_file=$(get_state_file "$profile")
    local pending_flag=$(get_pending_flag "$profile")

    log "=== Restoring workspace state for profile '$profile' ==="

    if [ ! -f "$state_file" ]; then
        warn "No saved state found for profile '$profile'"
        echo "No saved state for profile '$profile'"
        return 1
    fi

    # Wait for monitor setup to stabilize
    sleep 2

    local saved_state=$(cat "$state_file")
    local current_windows=$(hyprctl clients -j 2>/dev/null)

    if [ -z "$saved_state" ] || [ -z "$current_windows" ]; then
        error "Could not read state or current windows"
        return 1
    fi

    # Check state version and extract windows
    local version=$(echo "$saved_state" | jq -r '.version // 1')
    local saved_windows

    if [ "$version" -ge 2 ] 2>/dev/null; then
        saved_windows=$(echo "$saved_state" | jq -c '.windows')
    else
        saved_windows="$saved_state"
    fi

    # For v4+, first restore workspace-to-monitor assignments
    # Use PREFERENCES first (sticky), fall back to state file
    log "Restoring workspace-to-monitor mappings..."

    # Get preferred workspace map (uses preferences file first, then state)
    local workspace_monitor_map=$(get_preferred_workspace_map "$profile")

    # Get current available monitors
    local current_monitors=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' | tr '\n' ' ')
    log "Current monitors: $current_monitors"

    # Get default external monitor for workspaces without preferences
    local default_external=$(get_default_external_monitor "$profile")
    local internal_monitor=$(get_internal_monitor)
    log "Default external monitor: $default_external, Internal: $internal_monitor"

    # Get ALL current workspaces (not just those in preferences)
    local all_workspaces=$(hyprctl workspaces -j 2>/dev/null | jq -r '.[] | select(.id > 0) | .id')

    log "Workspace map from preferences: $workspace_monitor_map"

    # Move ALL workspaces to their correct monitors
    for ws_id in $all_workspaces; do
        # Check if this workspace has a preference
        local preferred_monitor=""
        if [ "$workspace_monitor_map" != "{}" ] && [ "$workspace_monitor_map" != "null" ]; then
            preferred_monitor=$(echo "$workspace_monitor_map" | jq -r --arg ws "$ws_id" '.[$ws] // ""')
        fi

        local target_monitor=""
        if [ -n "$preferred_monitor" ] && [ "$preferred_monitor" != "null" ]; then
            target_monitor="$preferred_monitor"
            log "WS $ws_id has preference: $target_monitor"
        else
            # No preference - use default (external for all except internal-only workspaces)
            # By default, send to external monitor
            if [ -n "$default_external" ]; then
                target_monitor="$default_external"
                log "WS $ws_id has NO preference, defaulting to external: $target_monitor"
            fi
        fi

        # Move workspace if we have a target and it's available
        if [ -n "$target_monitor" ]; then
            if echo "$current_monitors" | grep -q "$target_monitor"; then
                move_workspace_to_monitor "$ws_id" "$target_monitor"
                sleep 0.1
            else
                log "Target monitor '$target_monitor' not connected for workspace $ws_id"
            fi
        fi
    done

    local total=$(echo "$saved_windows" | jq length)
    log "Attempting to restore $total windows for profile '$profile'..."

    local used_addresses=""
    local restored=0
    local skipped=0
    local not_found=0
    local ws_moved=0

    while IFS= read -r saved_window; do
        [ -z "$saved_window" ] && continue

        local saved_class=$(echo "$saved_window" | jq -r '.class // "unknown"')
        local saved_workspace=$(echo "$saved_window" | jq -r '.workspace')
        local saved_floating=$(echo "$saved_window" | jq -r '.floating // false')
        local saved_at=$(echo "$saved_window" | jq -c '.at // [0,0]')
        local saved_size=$(echo "$saved_window" | jq -c '.size // [0,0]')
        local saved_monitor_name=$(echo "$saved_window" | jq -r '.monitorName // "unknown"')

        # Skip special workspaces (negative numbers)
        if [ "$saved_workspace" = "null" ] || [ "$saved_workspace" -lt 1 ] 2>/dev/null; then
            log "Skipping window in special workspace: $saved_class (ws: $saved_workspace)"
            ((skipped++))
            continue
        fi

        local current_address=$(find_matching_window "$saved_window" "$current_windows" "$used_addresses")

        if [ -n "$current_address" ] && [ "$current_address" != "null" ]; then
            used_addresses="${used_addresses}${current_address},"

            local current_workspace=$(echo "$current_windows" | jq -r \
                --arg addr "$current_address" \
                '.[] | select(.address == $addr) | .workspace.id')

            ensure_workspace "$saved_workspace"

            if [ "$current_workspace" != "$saved_workspace" ]; then
                log "Moving: $saved_class (ws $current_workspace -> $saved_workspace, target monitor: $saved_monitor_name)"
                hyprctl dispatch movetoworkspacesilent "$saved_workspace,address:$current_address" > /dev/null 2>&1
                ((restored++))
                sleep 0.05
            fi

            # Restore floating window position and size
            if [ "$saved_floating" = "true" ]; then
                local x=$(echo "$saved_at" | jq '.[0]')
                local y=$(echo "$saved_at" | jq '.[1]')
                local w=$(echo "$saved_size" | jq '.[0]')
                local h=$(echo "$saved_size" | jq '.[1]')

                if [ "$x" != "null" ] && [ "$y" != "null" ] && [ "$w" != "null" ] && [ "$h" != "null" ]; then
                    if [ "$w" -gt 0 ] && [ "$h" -gt 0 ] 2>/dev/null; then
                        log "Restoring floating position for $saved_class: ${w}x${h} at ${x},${y}"
                        hyprctl dispatch focuswindow "address:$current_address" > /dev/null 2>&1
                        hyprctl dispatch resizewindowpixel "exact $w $h,address:$current_address" > /dev/null 2>&1
                        hyprctl dispatch movewindowpixel "exact $x $y,address:$current_address" > /dev/null 2>&1
                        sleep 0.05
                    fi
                fi
            fi
        else
            log "Could not find matching window for: $saved_class"
            ((not_found++))
        fi
    done < <(echo "$saved_windows" | jq -c '.[]')

    # Remove pending flag after successful restore
    if [ -f "$pending_flag" ]; then
        rm "$pending_flag"
        log "Pending flag removed for profile '$profile'"
    fi

    local friendly_name=$(get_friendly_profile_name "$profile")

    # Send notification with results
    if [ "$restored" -gt 0 ]; then
        notify "✨ Workspace Restored" \
            "$friendly_name\n$restored windows repositioned" \
            "view-restore"
    elif [ "$not_found" -eq 0 ]; then
        notify "✅ Workspace Ready" \
            "$friendly_name\nAll windows in place" \
            "dialog-ok"
    else
        notify "⚠️ Workspace Partially Restored" \
            "$friendly_name\n$not_found windows not found" \
            "dialog-warning" "normal"
    fi

    log "Restoration complete for '$profile': $restored moved, $skipped skipped, $not_found not found"
    echo "Profile '$profile': $restored moved, $skipped skipped, $not_found not found"
    return 0
}

# Auto-restore: check if current profile has a pending restore
auto_restore() {
    local profile=$(get_monitor_profile)
    local pending_flag=$(get_pending_flag "$profile")
    local state_file=$(get_state_file "$profile")

    log "Auto-restore check for profile '$profile'..."

    if [ -f "$pending_flag" ]; then
        if [ -f "$state_file" ]; then
            log "Pending flag found for '$profile', restoring..."
            restore_state "$profile"
            return $?
        else
            warn "Pending flag exists but no state file for '$profile', clearing flag"
            rm "$pending_flag"
            return 1
        fi
    else
        log "No pending restore for profile '$profile'"
        return 0
    fi
}

# Show saved state for current or specified profile
show_state() {
    local profile="${1:-$(get_monitor_profile)}"
    local state_file=$(get_state_file "$profile")
    local pending_flag=$(get_pending_flag "$profile")

    if [ ! -f "$state_file" ]; then
        echo "No saved state for profile '$profile'"
        return 1
    fi

    echo "=== Saved State for Profile '$profile' ==="
    local state=$(cat "$state_file")
    local version=$(echo "$state" | jq -r '.version // 1')

    if [ "$version" -ge 2 ] 2>/dev/null; then
        echo "Version: $version"
        echo "Saved at: $(echo "$state" | jq -r '.timestamp')"
        echo "Monitors: $(echo "$state" | jq -r '.monitors | map(.name) | join(", ")')"

        # Show workspace-to-monitor mapping for v4+
        if [ "$version" -ge 4 ] 2>/dev/null; then
            echo ""
            echo "Workspace -> Monitor Mapping:"
            echo "$state" | jq -r '.workspaceMonitorMap | to_entries | sort_by(.key | tonumber) | .[] | "  WS \(.key) -> \(.value)"'
        fi

        echo ""
        echo "Windows:"
        if [ "$version" -ge 4 ] 2>/dev/null; then
            echo "$state" | jq -r '.windows[] | "  WS \(.workspace) [\(.monitorName)]: \(.class) - \(.title | .[0:40])"' | sort -t':' -k1 -V
        else
            echo "$state" | jq -r '.windows[] | "  WS \(.workspace): \(.class) - \(.title | .[0:50]) [floating=\(.floating)]"' | sort -t':' -k1 -V
        fi
    else
        echo "Version: 1 (legacy)"
        echo "$state" | jq -r '.[] | "  WS \(.workspace): \(.class) - \(.title | .[0:50])"' | sort -t':' -k1 -V
    fi

    echo ""
    if [ -f "$pending_flag" ]; then
        echo "Status: PENDING RESTORE"
    else
        echo "Status: No pending restore"
    fi
}

# Show current live state
show_current() {
    echo "=== Current Live State ==="
    echo "Profile: $(get_monitor_profile)"
    echo ""
    hyprctl clients -j | jq -r '.[] | "  WS \(.workspace.id): \(.class) - \(.title | .[0:50]) [floating=\(.floating)]"' | sort -t':' -k1 -V
}

# List all saved profiles
list_profiles() {
    echo "=== Saved Profiles ==="
    echo ""

    local current_profile=$(get_monitor_profile)

    for state_file in "$STATE_DIR"/state-*.json; do
        [ -f "$state_file" ] || continue

        local filename=$(basename "$state_file")
        local profile=$(echo "$filename" | sed 's/state-//; s/.json//')
        local pending_flag=$(get_pending_flag "$profile")
        local window_count=$(jq '.windows | length // length' "$state_file" 2>/dev/null || echo "?")
        local timestamp=$(jq -r '.timestamp // "unknown"' "$state_file" 2>/dev/null)

        local marker=""
        [ "$profile" = "$current_profile" ] && marker=" (CURRENT)"

        local pending=""
        [ -f "$pending_flag" ] && pending=" [PENDING]"

        echo "  $profile$marker$pending"
        echo "    Windows: $window_count"
        echo "    Saved: $timestamp"
        echo ""
    done

    if [ ! -f "$STATE_DIR"/state-*.json ] 2>/dev/null; then
        echo "  No profiles saved yet"
    fi
}

# Clear state for current or specified profile
clear_state() {
    local profile="${1:-$(get_monitor_profile)}"
    local state_file=$(get_state_file "$profile")
    local pending_flag=$(get_pending_flag "$profile")
    local cleared=false

    if [ -f "$state_file" ]; then
        rm "$state_file"
        log "Cleared state for profile '$profile'"
        cleared=true
    fi

    if [ -f "$pending_flag" ]; then
        rm "$pending_flag"
        log "Cleared pending flag for profile '$profile'"
        cleared=true
    fi

    if [ "$cleared" = true ]; then
        echo "State cleared for profile '$profile'"
    else
        echo "No state to clear for profile '$profile'"
    fi
}

# Clear all profiles
clear_all() {
    rm -f "$STATE_DIR"/state-*.json
    rm -f "$STATE_DIR"/pending-*
    log "Cleared all profiles"
    echo "All profiles cleared"
}

# Check if restore is pending for current profile
is_pending() {
    local profile=$(get_monitor_profile)
    local pending_flag=$(get_pending_flag "$profile")

    if [ -f "$pending_flag" ]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

# Show overall status
status() {
    local current_profile=$(get_monitor_profile)
    local current_state=$(get_state_file "$current_profile")
    local current_pending=$(get_pending_flag "$current_profile")

    echo "=== Workspace State Manager Status ==="
    echo ""
    echo "Current profile: $current_profile"
    echo ""

    echo "Current monitors:"
    hyprctl monitors -j | jq -r '.[] | "  \(.name): \(.width)x\(.height)"'
    echo ""

    if [ -f "$current_state" ]; then
        local state=$(cat "$current_state")
        local window_count=$(echo "$state" | jq '.windows | length // length')
        local timestamp=$(echo "$state" | jq -r '.timestamp // "unknown"')
        echo "State for current profile: YES"
        echo "  Windows: $window_count"
        echo "  Saved: $timestamp"
    else
        echo "State for current profile: NO"
    fi

    if [ -f "$current_pending" ]; then
        echo "  Pending restore: YES"
    else
        echo "  Pending restore: NO"
    fi

    echo ""
    echo "All profiles:"
    local profile_count=0
    for state_file in "$STATE_DIR"/state-*.json; do
        [ -f "$state_file" ] || continue
        local filename=$(basename "$state_file")
        local profile=$(echo "$filename" | sed 's/state-//; s/.json//')
        local pending_flag=$(get_pending_flag "$profile")
        local marker=""
        [ "$profile" = "$current_profile" ] && marker="*"
        [ -f "$pending_flag" ] && marker="${marker}P"
        printf "  %-30s %s\n" "$profile" "[$marker]"
        ((profile_count++))
    done
    [ $profile_count -eq 0 ] && echo "  (none)"
    echo ""
    echo "Legend: * = current, P = pending restore"
}

# Handle monitor change event (called by monitor-hotplug.sh)
# This saves the OLD profile's state before the change completes
handle_monitor_change() {
    local old_profile="$1"
    local new_profile="$2"

    if [ -z "$old_profile" ] || [ -z "$new_profile" ]; then
        log "handle_monitor_change requires old and new profile names"
        return 1
    fi

    log "=== Monitor change: '$old_profile' -> '$new_profile' ==="

    # The current windows are still arranged for the OLD profile
    # Save them to the OLD profile's state file
    save_state_for_profile "$old_profile"

    echo "Saved state for outgoing profile '$old_profile'"
}

# Show workspace preferences
show_prefs() {
    local profile="${1:-$(get_monitor_profile)}"
    echo "=== Workspace-Monitor Preferences ==="
    echo ""

    local prefs=$(get_workspace_prefs)

    if [ "$prefs" = "{}" ] || [ -z "$prefs" ]; then
        echo "No preferences saved yet."
        echo ""
        echo "Preferences are automatically saved when you save workspace state"
        echo "with multiple monitors connected."
        return 0
    fi

    if [ -n "$1" ]; then
        # Show specific profile
        local profile_prefs=$(echo "$prefs" | jq -r --arg profile "$profile" '.[$profile] // {}')
        if [ "$profile_prefs" = "{}" ]; then
            echo "No preferences for profile '$profile'"
        else
            echo "Profile: $profile"
            echo "$profile_prefs" | jq -r 'to_entries | sort_by(.key | tonumber) | .[] | "  WS \(.key) -> \(.value)"'
        fi
    else
        # Show all profiles
        echo "$prefs" | jq -r 'to_entries[] | "Profile: \(.key)\n" + (.value | to_entries | sort_by(.key | tonumber) | map("  WS \(.key) -> \(.value)") | join("\n")) + "\n"'
    fi
}

# Update preferences now (manual command)
update_prefs() {
    local profile=$(get_monitor_profile)
    local monitor_count=$(echo "$profile" | tr '_' '\n' | wc -l)

    if [ "$monitor_count" -lt 2 ]; then
        echo "Cannot update preferences: only one monitor connected."
        echo "Connect multiple monitors and arrange workspaces first."
        return 1
    fi

    echo "Updating workspace preferences for profile '$profile'..."
    update_all_workspace_prefs
    echo "Done. Current preferences:"
    show_prefs "$profile"
}

# Main command handler
case "${1:-}" in
    "save")
        save_state "${2:-}"
        ;;
    "restore")
        restore_state "${2:-}"
        ;;
    "auto-restore")
        auto_restore
        ;;
    "show")
        show_state "${2:-}"
        ;;
    "current")
        show_current
        ;;
    "profiles"|"list")
        list_profiles
        ;;
    "clear")
        clear_state "${2:-}"
        ;;
    "clear-all")
        clear_all
        ;;
    "pending"|"is-pending")
        is_pending
        ;;
    "status")
        status
        ;;
    "profile")
        get_monitor_profile
        ;;
    "handle-change")
        handle_monitor_change "$2" "$3"
        ;;
    "prefs"|"preferences")
        show_prefs "${2:-}"
        ;;
    "update-prefs")
        update_prefs
        ;;
    *)
        echo "Workspace State Manager for Hyprland (v5.0 - Sticky Preferences)"
        echo ""
        echo "Usage: $0 <command> [profile]"
        echo ""
        echo "State Commands:"
        echo "  save              - Save current state for current monitor profile"
        echo "  restore [profile] - Restore state (current profile if not specified)"
        echo "  auto-restore      - Restore if pending flag exists for current profile"
        echo "  show [profile]    - Show saved state for a profile"
        echo "  current           - Show current live state"
        echo "  profiles          - List all saved profiles"
        echo "  status            - Show overall status"
        echo "  pending           - Check if restore is pending for current profile"
        echo "  clear [profile]   - Clear state for a profile"
        echo "  clear-all         - Clear all profiles"
        echo ""
        echo "Preference Commands (v5.0):"
        echo "  prefs [profile]   - Show workspace-monitor preferences"
        echo "  update-prefs      - Update preferences from current layout"
        echo ""
        echo "Internal Commands:"
        echo "  profile           - Show current monitor profile name"
        echo "  handle-change     - Internal: handle monitor config change"
        echo ""
        echo "v5.0 Features:"
        echo "  - Sticky workspace-monitor preferences"
        echo "  - Preferences persist even when monitors disconnect"
        echo "  - Run 'update-prefs' after arranging workspaces to save layout"
        echo ""
        echo "KVM Workflow:"
        echo "  1. Connect external monitor"
        echo "  2. Arrange workspaces (move WS 1, 2, etc. to external)"
        echo "  3. Run 'update-prefs' to save your arrangement"
        echo "  4. Now disconnecting/reconnecting will restore your layout"
        echo ""
        echo "Files:"
        echo "  States: $STATE_DIR/state-*.json"
        echo "  Prefs:  $WORKSPACE_PREFS_FILE"
        echo "  Log:    $LOG_FILE"
        ;;
esac
