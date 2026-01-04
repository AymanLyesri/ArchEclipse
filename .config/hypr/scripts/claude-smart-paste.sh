#!/bin/bash
# Claude Smart Paste - Automatic image path injection for Claude Code
# This script intercepts paste attempts and automatically inserts image paths

# Configuration
CLAUDE_DIR="/tmp/claude-clipboard"
LATEST_IMAGE="$CLAUDE_DIR/latest.png"
SCREENSHOT_LATEST="$HOME/Pictures/Screenshots/latest.png"
LOG_FILE="/tmp/claude-smart-paste.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to check if Windsurf/Claude is focused
is_windsurf_focused() {
    # Get the currently focused window class
    focused_class=$(hyprctl activewindow -j | jq -r '.class // ""')

    # Check if it's Windsurf (case-insensitive)
    if [[ "${focused_class,,}" == *"windsurf"* ]]; then
        return 0
    fi
    return 1
}

# Function to check if clipboard has an image
has_clipboard_image() {
    wl-paste --list-types 2>/dev/null | grep -q "^image/"
}

# Function to get the latest available image path
get_latest_image() {
    # Priority order:
    # 1. Claude clipboard latest (if exists and recent)
    # 2. Screenshot latest (if exists and recent)
    # 3. Most recent clipboard image in /tmp/claude-clipboard

    if [ -L "$LATEST_IMAGE" ] && [ -e "$LATEST_IMAGE" ]; then
        # Check if file is less than 5 minutes old
        if [ $(find "$LATEST_IMAGE" -mmin -5 2>/dev/null | wc -l) -gt 0 ]; then
            echo "$LATEST_IMAGE"
            return
        fi
    fi

    if [ -L "$SCREENSHOT_LATEST" ] && [ -e "$SCREENSHOT_LATEST" ]; then
        # Check if file is less than 5 minutes old
        if [ $(find "$SCREENSHOT_LATEST" -mmin -5 2>/dev/null | wc -l) -gt 0 ]; then
            echo "$SCREENSHOT_LATEST"
            return
        fi
    fi

    # Find most recent clipboard image
    latest=$(ls -t "$CLAUDE_DIR"/clipboard_*.png 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        echo "$latest"
        return
    fi

    # Find most recent screenshot
    latest=$(ls -t "$HOME/Pictures/Screenshots/"*_hyprshot.png 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        echo "$latest"
        return
    fi

    return 1
}

# Function to type text using wtype (Wayland typing tool)
type_text() {
    local text="$1"
    # Check if wtype is installed
    if ! command -v wtype &> /dev/null; then
        log "ERROR: wtype not installed. Install with: pacman -S wtype"
        notify-send "Smart Paste Error" "wtype not installed\nInstall with: pacman -S wtype" -u critical
        return 1
    fi

    # Type the text
    wtype "$text"
    log "Typed text: $text"
}

# Function to inject Claude command
inject_claude_command() {
    local image_path="$1"

    # Format the command for Claude
    local command="Read $image_path"

    log "Injecting command: $command"

    # Send notification
    notify-send "Claude Smart Paste" "Image path inserted:\n$image_path" -i "$image_path" -t 3000

    # Type the command
    type_text "$command"

    # Optionally, simulate Enter key to submit (uncomment if desired)
    # sleep 0.1
    # wtype -k Return
}

# Main execution
main() {
    log "Smart Paste triggered"

    # Check if Windsurf is focused
    if ! is_windsurf_focused; then
        log "Windsurf not focused, passing through normal paste"
        # Let normal paste happen
        wl-paste 2>/dev/null
        return
    fi

    log "Windsurf is focused"

    # Check if clipboard has an image
    if has_clipboard_image; then
        log "Clipboard has an image"

        # Try to save the current clipboard image first
        timestamp=$(date +%Y%m%d_%H%M%S)
        new_image="$CLAUDE_DIR/clipboard_${timestamp}.png"
        mkdir -p "$CLAUDE_DIR"

        if wl-paste --type image/png > "$new_image" 2>/dev/null; then
            if [ -s "$new_image" ]; then
                ln -sf "$new_image" "$LATEST_IMAGE"
                log "Saved new clipboard image: $new_image"
                inject_claude_command "$LATEST_IMAGE"
            else
                rm -f "$new_image"
                # Try to find existing image
                if image_path=$(get_latest_image); then
                    log "Using existing image: $image_path"
                    inject_claude_command "$image_path"
                else
                    log "No valid image found"
                    notify-send "Claude Smart Paste" "No recent image found" -u warning
                fi
            fi
        else
            # Try to find existing image
            if image_path=$(get_latest_image); then
                log "Using existing image: $image_path"
                inject_claude_command "$image_path"
            else
                log "No valid image found"
                notify-send "Claude Smart Paste" "No recent image found" -u warning
            fi
        fi
    else
        log "No image in clipboard, performing normal paste"
        # Perform normal text paste
        text=$(wl-paste 2>/dev/null)
        if [ -n "$text" ]; then
            type_text "$text"
        fi
    fi
}

# Handle different modes
case "${1:-paste}" in
    paste)
        main
        ;;
    test)
        echo "Testing Claude Smart Paste..."
        echo "Windsurf focused: $(is_windsurf_focused && echo 'Yes' || echo 'No')"
        echo "Clipboard has image: $(has_clipboard_image && echo 'Yes' || echo 'No')"
        if image_path=$(get_latest_image); then
            echo "Latest image: $image_path"
        else
            echo "No recent image found"
        fi
        ;;
    *)
        echo "Usage: $0 {paste|test}"
        exit 1
        ;;
esac