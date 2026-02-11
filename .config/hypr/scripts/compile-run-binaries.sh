#!/bin/bash

BIN_DIR=/tmp
SRC=$HOME/.config/hypr/scripts-c

mkdir -p "$BIN_DIR"

gcc "$SRC/battery-check.c"   -o "$BIN_DIR/battery-check"
gcc "$SRC/updates-check.c"   -o "$BIN_DIR/updates-check"
gcc "$SRC/posture-check.c"   -o "$BIN_DIR/posture-check"
gcc "$SRC/hyprpaper-loop.c"  -o "$BIN_DIR/hyprpaper-loop"

pkill -f "hyprpaper-loop"

"$BIN_DIR/hyprpaper-loop" &

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
            pkexec systemctl enable --now cronie
        ;;
    esac
fi

(crontab -l 2>/dev/null | grep -v "$BIN_DIR"; \
    echo "*/5  * * * * $BIN_DIR/battery-check"; \
    echo "0    * * * * $BIN_DIR/updates-check"; \
echo "0    * * * * $BIN_DIR/posture-check") | crontab -

# Run immediately once
/tmp/battery-check
/tmp/updates-check
/tmp/posture-check
