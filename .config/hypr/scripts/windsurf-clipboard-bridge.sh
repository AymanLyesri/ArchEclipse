#!/bin/bash
# Windsurf Clipboard Bridge for Claude Code
# This script provides a workaround for pasting images in Claude Code on Wayland
# It intercepts clipboard changes and automatically inserts file paths when images are detected

# Configuration
BRIDGE_DIR="/tmp/windsurf-clipboard-bridge"
LATEST_IMAGE="$BRIDGE_DIR/latest.png"
LOG_FILE="/tmp/windsurf-clipboard-bridge.log"
NOTIFICATION_TIMEOUT=3000
CLAUDE_MARKER_FILE="$BRIDGE_DIR/.claude_active"

# Create bridge directory
mkdir -p "$BRIDGE_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to check if Claude Code is active in Windsurf
is_claude_active() {
    # Check if Windsurf is focused
    active_window=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class' 2>/dev/null)
    if [[ "$active_window" == *"windsurf"* ]] || [[ "$active_window" == *"Windsurf"* ]]; then
        return 0
    fi
    return 1
}

# Function to insert text into active window using ydotool or wtype
insert_text() {
    local text="$1"

    # Try wtype first (native Wayland)
    if command -v wtype &>/dev/null; then
        wtype "$text"
        return 0
    fi

    # Fall back to ydotool
    if command -v ydotool &>/dev/null; then
        ydotool type "$text"
        return 0
    fi

    log "ERROR: Neither wtype nor ydotool found"
    return 1
}

# Function to handle clipboard image
handle_clipboard_image() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local image_file="$BRIDGE_DIR/claude_${timestamp}.png"

    # Save the image from clipboard
    if wl-paste --type image/png > "$image_file" 2>/dev/null; then
        local file_size=$(stat -c%s "$image_file" 2>/dev/null || echo 0)

        if [ "$file_size" -gt 0 ]; then
            # Update latest symlink
            ln -sf "$image_file" "$LATEST_IMAGE"

            # Also save to user-friendly location
            cp "$image_file" "$HOME/Pictures/Screenshots/claude_latest.png" 2>/dev/null

            log "Image saved: $image_file ($file_size bytes)"

            # Check if Claude Code is active
            if is_claude_active; then
                # Create a marker that Claude is active
                touch "$CLAUDE_MARKER_FILE"

                # Show notification with auto-insert option
                notify-send -t $NOTIFICATION_TIMEOUT \
                    "Claude Code: Image Ready" \
                    "Image saved. Press Alt+V to insert reference\nOr type: Read $LATEST_IMAGE" \
                    -i "$image_file"

                # Store the path for quick insertion
                echo "$LATEST_IMAGE" > "$BRIDGE_DIR/pending_path.txt"

                return 0
            else
                # Regular notification when not in Windsurf
                notify-send -t $NOTIFICATION_TIMEOUT \
                    "Clipboard Image Saved" \
                    "For Claude Code: Read $LATEST_IMAGE" \
                    -i "$image_file"
            fi
        else
            log "ERROR: Saved image file is empty"
            rm -f "$image_file"
            return 1
        fi
    else
        log "ERROR: Failed to save image from clipboard"
        return 1
    fi
}

# Function to monitor clipboard
monitor_clipboard() {
    log "Starting clipboard monitor for Windsurf bridge"

    wl-paste --watch bash -c '
        # Check clipboard content type
        if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
            '"$0"' handle-image
        fi
    '
}

# Function to handle Alt+V keybind (quick insert)
quick_insert() {
    if [ -f "$BRIDGE_DIR/pending_path.txt" ] && is_claude_active; then
        local path=$(cat "$BRIDGE_DIR/pending_path.txt")

        # Insert "Read " followed by the path
        insert_text "Read $path"

        # Clear the pending path
        rm -f "$BRIDGE_DIR/pending_path.txt"

        log "Inserted path: $path"

        notify-send -t 2000 "Claude Code" "Image path inserted"
    fi
}

# Main execution
case "${1:-monitor}" in
    monitor)
        # Start monitoring
        monitor_clipboard
        ;;

    handle-image)
        # Handle clipboard image
        handle_clipboard_image
        ;;

    insert)
        # Quick insert for keybind
        quick_insert
        ;;

    status)
        echo "Windsurf Clipboard Bridge Status"
        echo "================================="
        echo "Bridge directory: $BRIDGE_DIR"
        echo "Latest image: $LATEST_IMAGE"

        if [ -L "$LATEST_IMAGE" ] && [ -e "$LATEST_IMAGE" ]; then
            actual_file=$(readlink -f "$LATEST_IMAGE")
            echo "Latest image exists: $(stat -c%s "$actual_file") bytes"
            echo "Modified: $(stat -c %y "$actual_file" | cut -d. -f1)"
        else
            echo "No latest image found"
        fi

        if is_claude_active; then
            echo "Claude/Windsurf: ACTIVE"
        else
            echo "Claude/Windsurf: Not active"
        fi

        echo ""
        echo "Recent bridge images:"
        ls -lah "$BRIDGE_DIR"/claude_*.png 2>/dev/null | tail -5
        ;;

    clean)
        # Clean up old images (keep last 10)
        log "Cleaning up old bridge images"
        cd "$BRIDGE_DIR" && ls -t claude_*.png 2>/dev/null | tail -n +11 | xargs -r rm -f
        echo "Cleanup complete"
        ;;

    test)
        echo "Testing Windsurf Clipboard Bridge"
        echo "================================="

        # Test if wtype is available
        if command -v wtype &>/dev/null; then
            echo "✓ wtype is installed (text insertion will work)"
        else
            echo "✗ wtype not found - install it: sudo pacman -S wtype"
        fi

        # Test if Windsurf is active
        if is_claude_active; then
            echo "✓ Windsurf/Claude is active"
        else
            echo "→ Windsurf/Claude is not currently active"
        fi

        # Test clipboard image
        if [ -f "$HOME/Pictures/Screenshots/latest.png" ]; then
            echo "Testing image copy..."
            wl-copy -t image/png < "$HOME/Pictures/Screenshots/latest.png"
            sleep 1

            if [ -L "$LATEST_IMAGE" ]; then
                echo "✓ Image bridge working"
            else
                echo "✗ Image bridge failed"
            fi
        fi
        ;;

    *)
        echo "Usage: $0 {monitor|handle-image|insert|status|clean|test}"
        echo ""
        echo "  monitor      - Start monitoring clipboard for images"
        echo "  handle-image - Process current clipboard image"
        echo "  insert       - Quick insert image path (for keybind)"
        echo "  status       - Show current bridge status"
        echo "  clean        - Clean up old images"
        echo "  test         - Test the bridge functionality"
        exit 1
        ;;
esac