#!/bin/bash
# Fixed Clipboard Monitor - Handles images correctly for Claude Code

# Configuration
CLAUDE_DIR="/tmp/claude-clipboard"
LATEST_IMAGE="$CLAUDE_DIR/latest.png"
LOG_FILE="/tmp/clipboard-monitor.log"

# Create directory for Claude
mkdir -p "$CLAUDE_DIR"

# Simple lock to prevent concurrent executions
LOCK_FILE="/tmp/clipboard-monitor-exec.lock"

# Try to acquire lock (non-blocking)
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    echo "[$(date '+%H:%M:%S')] SKIP: Already running" >> /tmp/clip-count.log
    exit 0
fi

# Clean up lock on exit
trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT

echo "[$(date '+%H:%M:%S')] EXEC" >> /tmp/clip-count.log

# Check what types are available in the clipboard
available_types=$(wl-paste --list-types 2>/dev/null)

# Check if there's an image in the clipboard first
if echo "$available_types" | grep -q "^image/"; then
    # Image detected, save it properly
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Save to multiple locations for redundancy
    image_path="/tmp/clipboard_image_${timestamp}.png"
    claude_image="$CLAUDE_DIR/clipboard_${timestamp}.png"

    # Save the image (without timeout initially to debug)
    if wl-paste --type image/png > "$image_path" 2>/dev/null; then
        file_size=$(stat -c%s "$image_path" 2>/dev/null || echo 0)

        if [ "$file_size" -gt 0 ]; then
            # Copy to Claude directory
            cp "$image_path" "$claude_image"

            # Update the latest symlink
            ln -sf "$claude_image" "$LATEST_IMAGE"

            # Also save to Screenshots for easy access
            cp "$image_path" "$HOME/Pictures/Screenshots/clipboard_latest.png" 2>/dev/null

            # Show notification with instructions
            notify-send "Clipboard Image Captured" \
                "Saved for Claude Code\nUse: Read $LATEST_IMAGE" \
                -i "$image_path" \
                -t 5000

            echo "[$(date '+%H:%M:%S')] IMAGE: $image_path ($file_size bytes)" >> /tmp/clip-count.log
            echo "[$(date '+%H:%M:%S')] CLAUDE: $LATEST_IMAGE" >> /tmp/clip-count.log
        else
            # File is empty, this is the bug we're fixing
            echo "[$(date '+%H:%M:%S')] ERROR: Image file is 0 bytes" >> /tmp/clip-count.log

            # Try alternative method: save without redirection
            wl-paste --type image/png > "$image_path.retry" 2>&1
            retry_size=$(stat -c%s "$image_path.retry" 2>/dev/null || echo 0)

            if [ "$retry_size" -gt 0 ]; then
                mv "$image_path.retry" "$image_path"
                cp "$image_path" "$claude_image"
                ln -sf "$claude_image" "$LATEST_IMAGE"

                notify-send "Clipboard Image Captured (Retry)" \
                    "Saved for Claude Code\nUse: Read $LATEST_IMAGE" \
                    -i "$image_path" \
                    -t 5000

                echo "[$(date '+%H:%M:%S')] IMAGE_RETRY: $image_path ($retry_size bytes)" >> /tmp/clip-count.log
            else
                rm -f "$image_path" "$image_path.retry"
                echo "[$(date '+%H:%M:%S')] ERROR: Could not save image" >> /tmp/clip-count.log
            fi
        fi
    else
        echo "[$(date '+%H:%M:%S')] ERROR: wl-paste failed for image" >> /tmp/clip-count.log
    fi
else
    # No image, try text
    clipboard_content=$(wl-paste --no-newline 2>/dev/null)

    if [ -n "$clipboard_content" ]; then
        # We have text content, show it
        notify-send "Clipboard" "$clipboard_content"
        echo "[$(date '+%H:%M:%S')] TEXT: ${clipboard_content:0:50}" >> /tmp/clip-count.log
    else
        echo "[$(date '+%H:%M:%S')] EMPTY: No clipboard content" >> /tmp/clip-count.log
    fi
fi

echo "[$(date '+%H:%M:%S')] DONE" >> /tmp/clip-count.log