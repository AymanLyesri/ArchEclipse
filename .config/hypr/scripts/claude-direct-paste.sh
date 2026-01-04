#!/bin/bash
# Claude Direct Paste - The Ultimate Solution
# This script implements a direct paste mechanism for Claude Code in Windsurf
# It bypasses Electron's clipboard limitations entirely

# Configuration
PASTE_DIR="/tmp/claude-direct-paste"
LATEST_IMAGE="$PASTE_DIR/latest.png"
PASTE_CACHE="$PASTE_DIR/paste_cache.txt"
LOG_FILE="/tmp/claude-direct-paste.log"
FIFO_PATH="$PASTE_DIR/paste.fifo"

# Create directories and FIFO
mkdir -p "$PASTE_DIR"
[ ! -p "$FIFO_PATH" ] && mkfifo "$FIFO_PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Check if running in Windsurf
is_windsurf_active() {
    local active_class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null)
    [[ "$active_class" == *"indsurf"* ]] || [[ "$active_class" == *"INDSURF"* ]]
}

# Check if Claude Code chat is likely active (heuristic)
is_claude_chat_active() {
    # Check if Windsurf is active
    if ! is_windsurf_active; then
        return 1
    fi

    # Check if there's a marker file (set when user focuses on Claude chat)
    if [ -f "$PASTE_DIR/.claude_chat_active" ]; then
        # Check if marker is recent (within 30 seconds)
        local marker_age=$(($(date +%s) - $(stat -c %Y "$PASTE_DIR/.claude_chat_active" 2>/dev/null || echo 0)))
        if [ "$marker_age" -lt 30 ]; then
            return 0
        fi
    fi

    return 1
}

# Function to save clipboard image
save_clipboard_image() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local image_file="$PASTE_DIR/claude_${timestamp}.png"

    # Check for image in clipboard
    if ! wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
        log "No image in clipboard"
        return 1
    fi

    # Save the image
    if wl-paste --type image/png > "$image_file" 2>/dev/null; then
        local file_size=$(stat -c%s "$image_file" 2>/dev/null || echo 0)

        if [ "$file_size" -gt 0 ]; then
            # Update latest symlink
            ln -sf "$image_file" "$LATEST_IMAGE"

            # Also save to Screenshots for easy access
            cp "$image_file" "$HOME/Pictures/Screenshots/claude_direct_${timestamp}.png" 2>/dev/null

            # Store in cache for quick access
            echo "$LATEST_IMAGE" > "$PASTE_CACHE"

            log "Image saved: $image_file ($file_size bytes)"
            return 0
        else
            log "ERROR: Saved image is empty"
            rm -f "$image_file"
            return 1
        fi
    else
        log "ERROR: Failed to save image"
        return 1
    fi
}

# Function to type text using wtype
type_text() {
    local text="$1"

    if command -v wtype &>/dev/null; then
        # Small delay to ensure focus
        sleep 0.1
        wtype "$text"
        log "Typed: $text"
        return 0
    else
        log "ERROR: wtype not installed"
        return 1
    fi
}

# Function to handle direct paste
handle_direct_paste() {
    log "Handling direct paste request"

    # Check if we're in Windsurf
    if ! is_windsurf_active; then
        log "Not in Windsurf, passing through"
        # Let the original paste go through
        wtype -M ctrl v -m ctrl
        return
    fi

    # Check for image in clipboard
    if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
        log "Image detected in clipboard"

        # Save the image
        if save_clipboard_image; then
            # Get the saved path
            local image_path=$(cat "$PASTE_CACHE" 2>/dev/null || echo "$LATEST_IMAGE")

            # Type the Read command directly
            type_text "Read $image_path"

            # Show success notification
            notify-send -t 3000 \
                "Claude Code: Image Pasted" \
                "Path inserted: $image_path" \
                -i "$image_path"

            log "Successfully inserted image path: $image_path"
        else
            # Fall back to normal paste
            wtype -M ctrl v -m ctrl
            notify-send -t 3000 \
                "Claude Code" \
                "Failed to save image, trying normal paste" \
                -u critical
        fi
    else
        # Not an image, do normal paste
        log "No image in clipboard, normal paste"
        wtype -M ctrl v -m ctrl
    fi
}

# Function to mark Claude chat as active
mark_claude_active() {
    touch "$PASTE_DIR/.claude_chat_active"
    log "Marked Claude chat as active"
}

# Monitor clipboard and save images proactively
monitor_clipboard() {
    log "Starting clipboard monitor"

    wl-paste --watch bash -c '
        # Only process images
        if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
            # Save immediately
            '"$0"' save-image

            # Notify if in Windsurf
            if '"$0"' check-windsurf; then
                notify-send -t 3000 \
                    "Claude Code Ready" \
                    "Image saved! Press Ctrl+V in Claude chat" \
                    -i /tmp/claude-direct-paste/latest.png
            fi
        fi
    ' &

    local monitor_pid=$!
    echo "$monitor_pid" > "$PASTE_DIR/monitor.pid"
    log "Monitor started with PID $monitor_pid"

    # Keep the script running
    wait $monitor_pid
}

# Check if Windsurf is active (for external calls)
check_windsurf() {
    is_windsurf_active && exit 0 || exit 1
}

# Save current clipboard image
save_image() {
    save_clipboard_image
    exit $?
}

# Install dependencies
install_deps() {
    echo -e "${BLUE}Installing dependencies for Claude Direct Paste${NC}"
    echo ""

    local deps_needed=false

    # Check wtype
    if ! command -v wtype &>/dev/null; then
        echo -e "${YELLOW}Installing wtype (required for text input)...${NC}"
        sudo pacman -S --noconfirm wtype
        deps_needed=true
    else
        echo -e "${GREEN}✓${NC} wtype already installed"
    fi

    # Check jq
    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}Installing jq (required for JSON parsing)...${NC}"
        sudo pacman -S --noconfirm jq
        deps_needed=true
    else
        echo -e "${GREEN}✓${NC} jq already installed"
    fi

    # Check wl-clipboard
    if ! command -v wl-paste &>/dev/null; then
        echo -e "${YELLOW}Installing wl-clipboard...${NC}"
        sudo pacman -S --noconfirm wl-clipboard
        deps_needed=true
    else
        echo -e "${GREEN}✓${NC} wl-clipboard already installed"
    fi

    if [ "$deps_needed" = false ]; then
        echo -e "${GREEN}All dependencies are already installed!${NC}"
    else
        echo -e "${GREEN}Dependencies installed successfully!${NC}"
    fi

    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "1. Add the keybind to your Hyprland config"
    echo "2. Start the monitor: $0 monitor"
    echo "3. Copy an image and press Ctrl+V in Claude Code"
}

# Setup Hyprland keybind
setup_keybind() {
    local keybind_file="$HOME/.config/hypr/configs/custom/claude-direct-paste.conf"

    echo -e "${BLUE}Setting up Hyprland keybind for Claude Direct Paste${NC}"
    echo ""

    # Create the keybind configuration
    cat > "$keybind_file" << 'EOF'
# Claude Direct Paste Keybind
# This intercepts Ctrl+V in Windsurf and handles image pasting for Claude Code

# Method 1: Global Ctrl+V override (when Windsurf is active)
# This will intercept ALL Ctrl+V presses in Windsurf
bind = CTRL, V, exec, [ "$(hyprctl activewindow -j | jq -r '.class')" = "windsurf" ] && ~/.config/hypr/scripts/claude-direct-paste.sh paste || wtype -M ctrl v -m ctrl

# Method 2: Alternative keybind (Ctrl+Shift+V) specifically for Claude
bind = CTRL SHIFT, V, exec, ~/.config/hypr/scripts/claude-direct-paste.sh paste

# Method 3: Quick mark Claude chat as active (Super+Alt+C)
bind = SUPER ALT, C, exec, ~/.config/hypr/scripts/claude-direct-paste.sh mark-active
EOF

    echo -e "${GREEN}✓${NC} Keybind configuration created at:"
    echo "   $keybind_file"
    echo ""
    echo "The configuration includes:"
    echo "  • Ctrl+V     - Smart paste (auto-detects images in Windsurf)"
    echo "  • Ctrl+Shift+V - Force Claude paste"
    echo "  • Super+Alt+C  - Mark Claude chat as active"
    echo ""
    echo -e "${YELLOW}To activate:${NC}"
    echo "  1. Reload Hyprland config: hyprctl reload"
    echo "  2. Or restart Hyprland: Super+Shift+R"

    # Check if the config is already sourced in hyprland.conf
    if ! grep -q "claude-direct-paste.conf" "$HOME/.config/hypr/hyprland.conf"; then
        echo ""
        echo -e "${YELLOW}Note:${NC} You may need to add this line to hyprland.conf:"
        echo "  source = ~/.config/hypr/configs/custom/claude-direct-paste.conf"
    fi
}

# Status check
status() {
    echo -e "${BLUE}Claude Direct Paste Status${NC}"
    echo "=============================="
    echo ""

    # Check monitor
    if [ -f "$PASTE_DIR/monitor.pid" ]; then
        local pid=$(cat "$PASTE_DIR/monitor.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Monitor running (PID: $pid)"
        else
            echo -e "${RED}✗${NC} Monitor not running (stale PID)"
        fi
    else
        echo -e "${RED}✗${NC} Monitor not running"
    fi

    # Check latest image
    if [ -L "$LATEST_IMAGE" ] && [ -e "$LATEST_IMAGE" ]; then
        local actual_file=$(readlink -f "$LATEST_IMAGE")
        local size=$(stat -c%s "$actual_file" 2>/dev/null || echo 0)
        local modified=$(stat -c %y "$actual_file" 2>/dev/null | cut -d. -f1)
        echo -e "${GREEN}✓${NC} Latest image: $LATEST_IMAGE"
        echo "   Size: $size bytes"
        echo "   Modified: $modified"
    else
        echo -e "${YELLOW}→${NC} No cached image"
    fi

    # Check Windsurf
    if is_windsurf_active; then
        echo -e "${GREEN}✓${NC} Windsurf is active"
    else
        echo -e "${YELLOW}→${NC} Windsurf is not active"
    fi

    # Check dependencies
    echo ""
    echo "Dependencies:"
    for cmd in wtype jq wl-paste; do
        if command -v "$cmd" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $cmd"
        else
            echo -e "  ${RED}✗${NC} $cmd (required)"
        fi
    done

    # Check keybind config
    if [ -f "$HOME/.config/hypr/configs/custom/claude-direct-paste.conf" ]; then
        echo -e "${GREEN}✓${NC} Keybind config exists"
    else
        echo -e "${YELLOW}→${NC} Keybind not configured (run: $0 setup)"
    fi

    # Show recent images
    echo ""
    echo "Recent clipboard images:"
    ls -lah "$PASTE_DIR"/claude_*.png 2>/dev/null | tail -5 | while read line; do
        echo "  $line"
    done
}

# Test functionality
test_paste() {
    echo -e "${BLUE}Testing Claude Direct Paste${NC}"
    echo "============================"
    echo ""

    # Test 1: Dependencies
    echo "1. Checking dependencies..."
    local all_deps=true
    for cmd in wtype jq wl-paste; do
        if command -v "$cmd" &>/dev/null; then
            echo -e "   ${GREEN}✓${NC} $cmd found"
        else
            echo -e "   ${RED}✗${NC} $cmd missing"
            all_deps=false
        fi
    done

    if [ "$all_deps" = false ]; then
        echo -e "${RED}Missing dependencies! Run: $0 install${NC}"
        exit 1
    fi

    # Test 2: Clipboard image
    echo ""
    echo "2. Testing clipboard image handling..."
    if [ -f "$HOME/Pictures/Screenshots/latest.png" ]; then
        echo "   Using test image: ~/Pictures/Screenshots/latest.png"
        wl-copy -t image/png < "$HOME/Pictures/Screenshots/latest.png"
        sleep 0.5

        if save_clipboard_image; then
            echo -e "   ${GREEN}✓${NC} Image saved successfully"
            echo "   Path: $(cat "$PASTE_CACHE")"
        else
            echo -e "   ${RED}✗${NC} Failed to save image"
        fi
    else
        echo -e "   ${YELLOW}→${NC} No test image available"
        echo "   Take a screenshot first with Super+Shift+S"
    fi

    # Test 3: Text typing
    echo ""
    echo "3. Testing text input..."
    echo -e "   ${YELLOW}Focus on a text field and press Enter to test typing...${NC}"
    read -p "   Press Enter when ready: "
    if type_text "Test: Claude Direct Paste Working!"; then
        echo -e "   ${GREEN}✓${NC} Text typing successful"
    else
        echo -e "   ${RED}✗${NC} Text typing failed"
    fi

    # Test 4: Windsurf detection
    echo ""
    echo "4. Testing Windsurf detection..."
    if is_windsurf_active; then
        echo -e "   ${GREEN}✓${NC} Windsurf is active"
    else
        echo -e "   ${YELLOW}→${NC} Windsurf is not active"
        echo "   Open Windsurf and run the test again"
    fi

    echo ""
    echo -e "${GREEN}Test complete!${NC}"
}

# Main execution
case "${1:-help}" in
    monitor)
        monitor_clipboard
        ;;

    paste)
        handle_direct_paste
        ;;

    save-image)
        save_image
        ;;

    check-windsurf)
        check_windsurf
        ;;

    mark-active)
        mark_claude_active
        ;;

    install)
        install_deps
        ;;

    setup)
        setup_keybind
        ;;

    status)
        status
        ;;

    test)
        test_paste
        ;;

    start)
        # Convenient start command
        echo -e "${BLUE}Starting Claude Direct Paste...${NC}"

        # Kill any existing monitor
        if [ -f "$PASTE_DIR/monitor.pid" ]; then
            old_pid=$(cat "$PASTE_DIR/monitor.pid")
            kill "$old_pid" 2>/dev/null && echo "Stopped old monitor (PID: $old_pid)"
        fi

        # Start monitor in background
        "$0" monitor &
        new_pid=$!
        echo "$new_pid" > "$PASTE_DIR/monitor.pid"

        echo -e "${GREEN}✓${NC} Monitor started (PID: $new_pid)"
        echo ""
        echo "Ready to handle image pasting in Claude Code!"
        echo "Press Ctrl+V in Claude chat after copying an image"
        ;;

    stop)
        if [ -f "$PASTE_DIR/monitor.pid" ]; then
            pid=$(cat "$PASTE_DIR/monitor.pid")
            if kill "$pid" 2>/dev/null; then
                echo -e "${GREEN}✓${NC} Monitor stopped (PID: $pid)"
                rm -f "$PASTE_DIR/monitor.pid"
            else
                echo -e "${YELLOW}Monitor not running${NC}"
            fi
        else
            echo "No monitor PID file found"
        fi
        ;;

    clean)
        echo "Cleaning up old images..."
        cd "$PASTE_DIR" && ls -t claude_*.png 2>/dev/null | tail -n +11 | xargs -r rm -v
        echo "Cleanup complete"
        ;;

    help|*)
        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║          Claude Direct Paste for Windsurf           ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "The ultimate solution for pasting images in Claude Code"
        echo ""
        echo -e "${YELLOW}Usage:${NC} $0 [command]"
        echo ""
        echo -e "${GREEN}Quick Start:${NC}"
        echo "  $0 install    # Install dependencies"
        echo "  $0 setup      # Setup Hyprland keybinds"
        echo "  $0 start      # Start the service"
        echo ""
        echo -e "${GREEN}Commands:${NC}"
        echo "  install   - Install required dependencies"
        echo "  setup     - Configure Hyprland keybinds"
        echo "  start     - Start the clipboard monitor"
        echo "  stop      - Stop the clipboard monitor"
        echo "  status    - Show current status"
        echo "  test      - Test functionality"
        echo "  clean     - Clean up old images"
        echo "  monitor   - Run clipboard monitor (internal)"
        echo "  paste     - Handle paste action (internal)"
        echo ""
        echo -e "${CYAN}How it works:${NC}"
        echo "  1. Monitors clipboard for images"
        echo "  2. Intercepts Ctrl+V in Windsurf"
        echo "  3. Automatically types 'Read /path/to/image'"
        echo "  4. Claude Code receives the image reference"
        echo ""
        echo -e "${CYAN}After setup:${NC}"
        echo "  1. Copy any image (screenshot, browser, etc)"
        echo "  2. Focus on Claude Code chat in Windsurf"
        echo "  3. Press Ctrl+V"
        echo "  4. Image path is inserted automatically!"
        ;;
esac