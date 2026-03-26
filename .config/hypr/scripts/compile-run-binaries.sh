#!/bin/bash

BIN_DIR=/tmp
SRC=$HOME/.config/hypr/scripts-c
CONFIG_DIR=$HOME/.config

mkdir -p "$BIN_DIR"

gcc "$SRC/battery-check.c"   -o "$BIN_DIR/battery-check"
gcc "$SRC/updates-check.c"   -o "$BIN_DIR/updates-check"
gcc "$SRC/posture-check.c"   -o "$BIN_DIR/posture-check"
gcc "$SRC/wallpaper-loop.c"  -o "$BIN_DIR/wallpaper-loop"

ags bundle "$CONFIG_DIR/ags/app.tsx" "$BIN_DIR/ags-bin"

# Run in background after kill any existing loop
pkill -f "wallpaper-loop" 2>/dev/null

"$BIN_DIR/wallpaper-loop" &
"$BIN_DIR/ags-bin" &

# Run immediately once
/tmp/battery-check &
/tmp/updates-check &

# Check if cronie is running
if ! systemctl is-active --quiet cronie; then
    
    action=$(notify-send \
        --app-name="Hypr Scripts" \
        --expire-time=0 \
        --action=enable:"Enable Cronie" \
        "Cronie not running" \
    "Cron jobs will not execute")
    
    # FIRST action = index 0
    case "$action" in
        0)
            echo "Enabling Cronie..."
            pkexec systemctl enable --now cronie && systemctl start cronie
        ;;
    esac
fi

# Update crontab with session variables
{
    crontab -l 2>/dev/null | grep -v "$BIN_DIR"
    # Added XDG_RUNTIME_DIR so notify-send can reach your desktop
    echo "*/5 * * * * XDG_RUNTIME_DIR=/run/user/$(id -u) $BIN_DIR/battery-check" # Check battery every 5 minutes
    echo "0 */6 * * * XDG_RUNTIME_DIR=/run/user/$(id -u) $BIN_DIR/updates-check" # Check for updates every 6 hours
    echo "0 * * * * XDG_RUNTIME_DIR=/run/user/$(id -u) $BIN_DIR/posture-check" # Check posture every hour
} | crontab - || notify-send "Error" "Failed to update crontab"

