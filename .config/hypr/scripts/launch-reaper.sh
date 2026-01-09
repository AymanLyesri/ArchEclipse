#!/bin/bash
# REAPER XWayland Window Creation Fix
# Problem: REAPER occasionally starts as zombie - audio engine runs but GUI never appears
# Solution: Launch with window creation monitoring and auto-restart if needed

REAPER_BIN="/usr/bin/reaper"
WINDOW_TIMEOUT=5  # seconds to wait for window creation
MAX_RETRIES=3
REAPER_ARGS="$@"  # Pass any arguments (like project files)

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

kill_reaper() {
    if pgrep -f "/usr/lib/REAPER/reaper" > /dev/null 2>&1; then
        log "Killing existing REAPER process..."
        pkill -9 -f "/usr/lib/REAPER/reaper"
        sleep 0.5
    fi
}

check_window_exists() {
    hyprctl clients -j | jq -e '.[] | select(.class == "REAPER" or .class == "reaper")' > /dev/null 2>&1
}

launch_reaper() {
    log "Launching REAPER..."
    $REAPER_BIN $REAPER_ARGS &
    REAPER_PID=$!

    # Wait for window creation with timeout
    local elapsed=0
    while [ $elapsed -lt $WINDOW_TIMEOUT ]; do
        sleep 0.5
        elapsed=$((elapsed + 1))

        if check_window_exists; then
            log "REAPER window detected successfully!"
            return 0
        fi

        # Check if process died
        if ! kill -0 $REAPER_PID 2>/dev/null; then
            log "REAPER process died unexpectedly"
            return 1
        fi
    done

    # Timeout reached - process running but no window (zombie state)
    log "REAPER window not detected after ${WINDOW_TIMEOUT}s - zombie state"
    return 1
}

main() {
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        log "Attempt $attempt of $MAX_RETRIES"

        kill_reaper

        if launch_reaper; then
            log "REAPER started successfully on attempt $attempt"
            exit 0
        fi

        log "Attempt $attempt failed"
        attempt=$((attempt + 1))
    done

    log "ERROR: Failed to start REAPER after $MAX_RETRIES attempts"
    notify-send -u critical "REAPER" "Failed to start after $MAX_RETRIES attempts"
    exit 1
}

main
