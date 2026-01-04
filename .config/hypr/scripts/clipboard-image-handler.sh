#!/bin/bash
# Clipboard Image Handler for Claude Code
# This script provides a robust solution for saving clipboard images
# that can be reliably accessed by Claude Code

# Configuration
SAVE_DIR="/tmp/claude-clipboard"
LATEST_IMAGE="$SAVE_DIR/latest.png"
LOG_FILE="/tmp/clipboard-image-handler.log"

# Create save directory if it doesn't exist
mkdir -p "$SAVE_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to save clipboard image
save_clipboard_image() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local image_path="$SAVE_DIR/clipboard_${timestamp}.png"

    # Check if there's an image in clipboard
    if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
        log "Image detected in clipboard"

        # Save the image with explicit format
        if wl-paste --type image/png > "$image_path" 2>/dev/null; then
            local file_size=$(stat -c%s "$image_path" 2>/dev/null || echo 0)

            if [ "$file_size" -gt 0 ]; then
                # Create symlink to latest
                ln -sf "$image_path" "$LATEST_IMAGE"

                log "Image saved: $image_path ($file_size bytes)"
                log "Latest link updated: $LATEST_IMAGE"

                # Also save to a more accessible location
                cp "$image_path" "$HOME/Pictures/Screenshots/clipboard_latest.png" 2>/dev/null

                # Show notification with the path
                notify-send "Clipboard Image Saved" \
                    "Saved to: $LATEST_IMAGE\nTell Claude: 'Read $LATEST_IMAGE'" \
                    -i "$image_path" \
                    -t 5000

                return 0
            else
                log "ERROR: Saved file is empty (0 bytes)"
                rm -f "$image_path"
                return 1
            fi
        else
            log "ERROR: Failed to save image from clipboard"
            return 1
        fi
    else
        log "No image in clipboard"
        return 2
    fi
}

# Main execution
case "${1:-monitor}" in
    save)
        # One-time save
        save_clipboard_image
        exit $?
        ;;
    monitor)
        # Continuous monitoring mode
        log "Starting clipboard image monitor"

        # Use wl-paste to watch for changes
        wl-paste --watch bash -c "
            # Check if image is available
            if wl-paste --list-types 2>/dev/null | grep -q '^image/'; then
                $0 save
            fi
        " &

        log "Monitor started with PID: $!"
        ;;
    status)
        # Check current status
        echo "Clipboard Image Handler Status"
        echo "=============================="
        echo "Save directory: $SAVE_DIR"
        echo "Latest image: $LATEST_IMAGE"

        if [ -f "$LATEST_IMAGE" ]; then
            echo "Latest image exists: $(stat -c%s "$LATEST_IMAGE") bytes"
            echo "Modified: $(stat -c %y "$LATEST_IMAGE" | cut -d. -f1)"
        else
            echo "No latest image found"
        fi

        echo ""
        echo "Recent saves:"
        ls -lah "$SAVE_DIR"/clipboard_*.png 2>/dev/null | tail -5

        echo ""
        echo "To use in Claude Code, tell Claude:"
        echo "  'Read $LATEST_IMAGE'"
        ;;
    clean)
        # Clean up old images (keep last 10)
        log "Cleaning up old images"
        cd "$SAVE_DIR" && ls -t clipboard_*.png 2>/dev/null | tail -n +11 | xargs -r rm -f
        echo "Cleanup complete"
        ;;
    *)
        echo "Usage: $0 {save|monitor|status|clean}"
        echo ""
        echo "  save    - Save current clipboard image"
        echo "  monitor - Start monitoring for clipboard images"
        echo "  status  - Show current status"
        echo "  clean   - Clean up old images"
        exit 1
        ;;
esac