#!/bin/bash
# Clipboard Monitor - Singleton Launcher
# Ensures ONLY ONE instance runs at a time across all monitors
# 
# This script is the ONLY entry point for the clipboard monitor.
# It guarantees no duplicate notifications by using multiple protection layers.

set -euo pipefail

# Configuration
PIDFILE="/tmp/clipboard-monitor.pid"
LOCKFILE="/tmp/clipboard-monitor.lock"
SCRIPT_DIR="$HOME/.config/hypr/scripts"
LOG_FILE="/tmp/clipboard-monitor-startup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "========== CLIPBOARD MONITOR STARTUP =========="

# Cleanup function
cleanup() {
    log "Cleanup: Removing PID and lock files"
    rm -f "$PIDFILE" "$LOCKFILE"
    rmdir "$LOCKFILE.d" 2>/dev/null || true
}

# Step 1: Check for and handle existing processes
log "Step 1: Checking for existing clipboard monitor processes"
EXISTING_PIDS=$(pgrep -f "wl-paste.*clipboard" 2>/dev/null || true)
if [ -n "$EXISTING_PIDS" ]; then
    log "Found existing processes: $EXISTING_PIDS"
    # Check if PID file exists and matches
    if [ -f "$PIDFILE" ]; then
        STORED_PID=$(cat "$PIDFILE" 2>/dev/null || echo "")
        if echo "$EXISTING_PIDS" | grep -q "^${STORED_PID}$"; then
            log "Process $STORED_PID is already running and managed. Exiting."
            # Exit without cleanup since we didn't start anything
            exit 0
        fi
    fi
    # Kill unmanaged processes
    log "Killing unmanaged processes"
    pkill -9 -f "wl-paste.*clipboard" 2>/dev/null || true
    sleep 0.5
else
    log "No existing processes found"
fi

# Set up cleanup trap AFTER checking for existing processes
trap cleanup EXIT INT TERM

# Step 2: Acquire exclusive lock using mkdir (atomic operation)
log "Step 2: Acquiring exclusive lock"
if ! mkdir "$LOCKFILE.d" 2>/dev/null; then
    log "ERROR: Could not acquire lock. Another instance may be starting."
    exit 1
fi

# Step 3: Double-check PID file
log "Step 3: Checking PID file"
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        log "ERROR: Another instance is running (PID: $OLD_PID)"
        rmdir "$LOCKFILE.d" 2>/dev/null || true
        exit 1
    else
        log "Stale PID file found, removing"
        rm -f "$PIDFILE"
    fi
fi

# Step 4: Write our PID
echo $$ > "$PIDFILE"
log "Step 4: Written PID $$ to $PIDFILE"

# Step 5: Verify no other wl-paste processes started in the meantime
log "Step 5: Checking for concurrent wl-paste processes"
sleep 0.2
WL_PIDS=$(pgrep -f "wl-paste.*clipboard" 2>/dev/null || true)
if [ -z "$WL_PIDS" ]; then
    WL_COUNT=0
else
    WL_COUNT=$(echo "$WL_PIDS" | wc -l | xargs)
fi
log "Found $WL_COUNT wl-paste processes"
if [ "$WL_COUNT" -gt 0 ]; then
    log "WARNING: Found $WL_COUNT wl-paste processes. Killing them."
    pkill -9 -f "wl-paste.*clipboard" 2>/dev/null || true
    sleep 0.3
fi

# Step 6: Start the clipboard monitor
log "Step 6: Starting clipboard monitor with wl-paste"
log "Command: wl-paste --watch bash $SCRIPT_DIR/clipboard-monitor.sh"

# Clear the clipboard log
> /tmp/clip-count.log

# Remove trap before exec (exec will replace this process)
trap - EXIT INT TERM

# Start the enhanced monitor (exec replaces this process)
# Use enhanced version if it exists, otherwise fall back to original
if [ -f "$SCRIPT_DIR/clipboard-monitor-enhanced.sh" ]; then
    exec wl-paste --watch bash "$SCRIPT_DIR/clipboard-monitor-enhanced.sh"
else
    exec wl-paste --watch bash "$SCRIPT_DIR/clipboard-monitor.sh"
fi
