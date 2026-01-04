#!/bin/bash
# Claude Code Paste Helper
# Advanced solution for enabling image pasting in Claude Code on Wayland
# This script provides multiple strategies to work around Electron clipboard limitations

# Configuration
HELPER_DIR="/tmp/claude-code-helper"
SOCKET_PATH="$HELPER_DIR/paste.sock"
LATEST_IMAGE="$HELPER_DIR/latest.png"
LOG_FILE="/tmp/claude-code-helper.log"
PASTE_TEMPLATE="$HELPER_DIR/paste_template.txt"

# Create helper directory
mkdir -p "$HELPER_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to create a VSCode/Windsurf extension configuration
create_extension_config() {
    local ext_dir="$HOME/.windsurf/extensions/claude-paste-helper"
    mkdir -p "$ext_dir"

    # Create a simple extension manifest
    cat > "$ext_dir/package.json" << 'EOF'
{
  "name": "claude-paste-helper",
  "displayName": "Claude Code Paste Helper",
  "description": "Enables image pasting in Claude Code on Wayland",
  "version": "1.0.0",
  "engines": {
    "vscode": "^1.85.0"
  },
  "main": "./extension.js",
  "contributes": {
    "commands": [
      {
        "command": "claude.pasteImage",
        "title": "Paste Image for Claude"
      }
    ],
    "keybindings": [
      {
        "command": "claude.pasteImage",
        "key": "ctrl+shift+v",
        "when": "editorTextFocus"
      }
    ]
  },
  "activationEvents": ["*"]
}
EOF

    # Create extension code
    cat > "$ext_dir/extension.js" << 'EOF'
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

function activate(context) {
    // Register paste command
    let disposable = vscode.commands.registerCommand('claude.pasteImage', async () => {
        const latestImage = '/tmp/claude-code-helper/latest.png';

        if (fs.existsSync(latestImage)) {
            const editor = vscode.window.activeTextEditor;
            if (editor) {
                // Insert the Read command for Claude
                const text = `Read ${latestImage}`;
                editor.edit(editBuilder => {
                    editBuilder.insert(editor.selection.active, text);
                });

                vscode.window.showInformationMessage(`Image reference inserted: ${latestImage}`);
            }
        } else {
            vscode.window.showWarningMessage('No image found in clipboard cache');
        }
    });

    context.subscriptions.push(disposable);

    // Monitor clipboard periodically
    setInterval(async () => {
        try {
            // Check if there's a marker file indicating new clipboard content
            const markerFile = '/tmp/claude-code-helper/.new_image';
            if (fs.existsSync(markerFile)) {
                fs.unlinkSync(markerFile);
                vscode.window.showInformationMessage('New image in clipboard! Use Ctrl+Shift+V to paste reference.');
            }
        } catch (error) {
            console.error('Clipboard check error:', error);
        }
    }, 2000);
}

function deactivate() {}

module.exports = { activate, deactivate };
EOF

    log "Extension configuration created at $ext_dir"
}

# Function to setup XWayland bridge (fallback method)
setup_xwayland_bridge() {
    log "Setting up XWayland clipboard bridge"

    # Check if xclip is installed
    if ! command -v xclip &>/dev/null; then
        log "WARNING: xclip not installed. Install with: sudo pacman -S xclip"
        return 1
    fi

    # Create a bridge that syncs Wayland clipboard to X11
    (
        while true; do
            # Check for image in Wayland clipboard
            if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
                # Save to temp file
                temp_file="$HELPER_DIR/bridge_temp.png"
                if wl-paste --type image/png > "$temp_file" 2>/dev/null; then
                    # Copy to X11 clipboard
                    xclip -selection clipboard -t image/png -i "$temp_file" 2>/dev/null

                    # Also save as latest
                    cp "$temp_file" "$LATEST_IMAGE"

                    log "Synced image to X11 clipboard"
                fi
            fi
            sleep 1
        done
    ) &

    log "XWayland bridge started with PID $!"
}

# Function to create a paste proxy using socat
create_paste_proxy() {
    log "Creating paste proxy socket"

    # Kill any existing proxy
    pkill -f "socat.*$SOCKET_PATH" 2>/dev/null

    # Create socket that listens for paste requests
    socat UNIX-LISTEN:"$SOCKET_PATH",fork EXEC:"$0 handle-paste-request" &
    log "Paste proxy started with PID $!"
}

# Handle paste request from socket
handle_paste_request() {
    if [ -f "$LATEST_IMAGE" ]; then
        echo "IMAGE:$LATEST_IMAGE"
    else
        echo "NO_IMAGE"
    fi
}

# Function to monitor and intercept Ctrl+V in Windsurf
setup_keybind_interceptor() {
    log "Setting up keybind interceptor"

    # Add a Hyprland keybind specifically for Windsurf
    cat > "$HELPER_DIR/windsurf_paste.conf" << 'EOF'
# Claude Code Paste Helper - Dynamic keybind for Windsurf
windowrulev2 = tag +windsurf, class:^(windsurf|Windsurf)$
bind = CTRL, V, submap, paste_check
submap = paste_check
bind = , , exec, ~/.config/hypr/scripts/claude-code-paste-helper.sh paste-action
bind = , , submap, reset
submap = reset
EOF

    # Note: This would need to be included in hyprland.conf
    log "Keybind configuration created at $HELPER_DIR/windsurf_paste.conf"
}

# Paste action when Ctrl+V is pressed in Windsurf
paste_action() {
    # Check if Windsurf is active
    active_window=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class' 2>/dev/null)

    if [[ "$active_window" == *"windsurf"* ]] || [[ "$active_window" == *"Windsurf"* ]]; then
        # Check for image in clipboard
        if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
            # Save image
            timestamp=$(date +%Y%m%d_%H%M%S)
            image_file="$HELPER_DIR/paste_${timestamp}.png"

            if wl-paste --type image/png > "$image_file" 2>/dev/null; then
                ln -sf "$image_file" "$LATEST_IMAGE"

                # Try to insert the path using wtype
                if command -v wtype &>/dev/null; then
                    wtype "Read $LATEST_IMAGE"
                    notify-send "Claude Code" "Image path inserted" -t 2000
                else
                    # Copy path to clipboard instead
                    echo "Read $LATEST_IMAGE" | wl-copy
                    notify-send "Claude Code" "Image path copied - paste again!" -t 3000
                fi

                log "Handled paste action for image"
                return 0
            fi
        fi
    fi

    # Pass through regular paste
    wtype -M ctrl v -m ctrl
}

# WebSocket server for browser extension (experimental)
start_websocket_server() {
    log "Starting WebSocket server for browser integration"

    # This would require a small Node.js server
    cat > "$HELPER_DIR/websocket_server.js" << 'EOF'
const WebSocket = require('ws');
const fs = require('fs');
const { exec } = require('child_process');

const wss = new WebSocket.Server({ port: 18754 });

wss.on('connection', (ws) => {
    console.log('Claude Code connected');

    ws.on('message', (message) => {
        if (message === 'GET_IMAGE') {
            const imagePath = '/tmp/claude-code-helper/latest.png';
            if (fs.existsSync(imagePath)) {
                ws.send(JSON.stringify({
                    type: 'IMAGE_PATH',
                    path: imagePath
                }));
            } else {
                ws.send(JSON.stringify({
                    type: 'NO_IMAGE'
                }));
            }
        }
    });
});

console.log('WebSocket server running on port 18754');
EOF

    # Check if Node.js is available
    if command -v node &>/dev/null; then
        (cd "$HELPER_DIR" && node websocket_server.js >> "$LOG_FILE" 2>&1) &
        log "WebSocket server started"
    else
        log "Node.js not found - WebSocket server not started"
    fi
}

# Main monitoring function
monitor() {
    log "Starting Claude Code Paste Helper monitoring"

    # Setup extension config
    create_extension_config

    # Start XWayland bridge if possible
    setup_xwayland_bridge

    # Start WebSocket server if possible
    start_websocket_server

    # Main clipboard monitoring loop
    wl-paste --watch bash -c '
        # Check if image is in clipboard
        if wl-paste --list-types 2>/dev/null | grep -q "^image/"; then
            # Save the image
            timestamp=$(date +%Y%m%d_%H%M%S)
            image_file="/tmp/claude-code-helper/claude_${timestamp}.png"

            if wl-paste --type image/png > "$image_file" 2>/dev/null; then
                # Update latest symlink
                ln -sf "$image_file" "/tmp/claude-code-helper/latest.png"

                # Create marker for extension
                touch "/tmp/claude-code-helper/.new_image"

                # Show notification
                notify-send "Claude Code Helper" \
                    "Image ready! Use Ctrl+Shift+V in Claude Code\nOr type: Read /tmp/claude-code-helper/latest.png" \
                    -i "$image_file" -t 5000

                echo "[$(date)] Image saved: $image_file" >> "/tmp/claude-code-helper.log"
            fi
        fi
    '
}

# Install helper utilities
install_dependencies() {
    echo -e "${BLUE}Installing dependencies for Claude Code Paste Helper${NC}"

    # Check and install wtype (for typing text)
    if ! command -v wtype &>/dev/null; then
        echo -e "${YELLOW}Installing wtype...${NC}"
        sudo pacman -S --noconfirm wtype
    else
        echo -e "${GREEN}✓ wtype already installed${NC}"
    fi

    # Check and install xclip (for X11 bridge)
    if ! command -v xclip &>/dev/null; then
        echo -e "${YELLOW}Installing xclip...${NC}"
        sudo pacman -S --noconfirm xclip
    else
        echo -e "${GREEN}✓ xclip already installed${NC}"
    fi

    # Check and install socat (for socket communication)
    if ! command -v socat &>/dev/null; then
        echo -e "${YELLOW}Installing socat...${NC}"
        sudo pacman -S --noconfirm socat
    else
        echo -e "${GREEN}✓ socat already installed${NC}"
    fi

    # Check Node.js (optional, for WebSocket)
    if ! command -v node &>/dev/null; then
        echo -e "${YELLOW}Node.js not installed (optional for WebSocket support)${NC}"
        echo "  Install with: sudo pacman -S nodejs npm"
    else
        echo -e "${GREEN}✓ Node.js installed${NC}"
    fi

    echo -e "${GREEN}Dependencies check complete!${NC}"
}

# Main execution
case "${1:-monitor}" in
    monitor)
        monitor
        ;;

    paste-action)
        paste_action
        ;;

    handle-paste-request)
        handle_paste_request
        ;;

    install)
        install_dependencies
        ;;

    status)
        echo -e "${BLUE}Claude Code Paste Helper Status${NC}"
        echo "================================="

        if [ -L "$LATEST_IMAGE" ] && [ -e "$LATEST_IMAGE" ]; then
            echo -e "${GREEN}✓${NC} Latest image: $LATEST_IMAGE"
            echo "  Size: $(stat -c%s "$LATEST_IMAGE") bytes"
        else
            echo -e "${YELLOW}→${NC} No image cached"
        fi

        # Check if monitor is running
        if pgrep -f "claude-code-paste-helper.*monitor" &>/dev/null; then
            echo -e "${GREEN}✓${NC} Monitor is running"
        else
            echo -e "${RED}✗${NC} Monitor not running"
        fi

        # Check dependencies
        echo ""
        echo "Dependencies:"
        for cmd in wtype xclip socat node; do
            if command -v $cmd &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $cmd"
            else
                echo -e "  ${RED}✗${NC} $cmd"
            fi
        done

        # Show recent images
        echo ""
        echo "Recent clipboard images:"
        ls -lah "$HELPER_DIR"/claude_*.png 2>/dev/null | tail -5
        ;;

    test)
        echo -e "${BLUE}Testing Claude Code Paste Helper${NC}"
        echo ""

        # Test clipboard image save
        if [ -f "$HOME/Pictures/Screenshots/latest.png" ]; then
            echo "1. Testing image save..."
            wl-copy -t image/png < "$HOME/Pictures/Screenshots/latest.png"
            sleep 1

            timestamp=$(date +%Y%m%d_%H%M%S)
            test_file="$HELPER_DIR/test_${timestamp}.png"
            if wl-paste --type image/png > "$test_file" 2>/dev/null; then
                echo -e "   ${GREEN}✓${NC} Image saved successfully"
                echo "   Size: $(stat -c%s "$test_file") bytes"
            else
                echo -e "   ${RED}✗${NC} Failed to save image"
            fi
        fi

        # Test wtype
        echo ""
        echo "2. Testing text insertion..."
        if command -v wtype &>/dev/null; then
            echo -e "   ${GREEN}✓${NC} wtype available"
        else
            echo -e "   ${RED}✗${NC} wtype not installed"
        fi

        echo ""
        echo -e "${GREEN}Test complete!${NC}"
        ;;

    help|*)
        echo -e "${BLUE}Claude Code Paste Helper${NC}"
        echo "========================"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  monitor  - Start monitoring clipboard (default)"
        echo "  install  - Install required dependencies"
        echo "  status   - Show current status"
        echo "  test     - Test functionality"
        echo "  help     - Show this help"
        echo ""
        echo "Quick Start:"
        echo "  1. $0 install    # Install dependencies"
        echo "  2. $0 monitor    # Start monitoring"
        echo "  3. Copy an image to clipboard"
        echo "  4. In Claude Code, use Ctrl+Shift+V or type:"
        echo "     Read /tmp/claude-code-helper/latest.png"
        ;;
esac