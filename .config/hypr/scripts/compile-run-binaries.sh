#!/bin/bash

TMP=/tmp
AGS_TMP="$TMP/ags-${USER}"
SRC=$HOME/.config/hypr/scripts-c
CONFIG_DIR=$HOME/.config
USER=$(whoami)

mkdir -p "$TMP"
mkdir -p "$AGS_TMP"

gcc "$SRC/battery-check.c"   -o "$TMP/battery-check"
gcc "$SRC/updates-check.c"   -o "$TMP/updates-check"
gcc "$SRC/wallpaper-loop.c"  -o "$TMP/wallpaper-loop"

ags bundle "$CONFIG_DIR/ags/app.tsx" "$AGS_TMP/ags-bin"

# Run in background after kill any existing loop
pkill -f "wallpaper-loop" 2>/dev/null

"$TMP/wallpaper-loop" &
# Launch AGS under a watchdog so a GTK4 surface-assertion crash self-heals instead of
# leaving the desktop without bar/panels until a manual relaunch.
chmod +x "$HOME/.config/hypr/scripts/ags-watchdog.sh" 2>/dev/null
"$HOME/.config/hypr/scripts/ags-watchdog.sh" "$AGS_TMP/ags-bin" > "$AGS_TMP/ags-bin.log" 2>&1 &

# Run immediately once
"$TMP/battery-check" &
"$TMP/updates-check" &

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
    crontab -l 2>/dev/null | grep -v "$TMP"
    # Added XDG_RUNTIME_DIR so notify-send can reach your desktop
    echo "*/5 * * * * XDG_RUNTIME_DIR=/run/user/$(id -u) $TMP/battery-check" # Check battery every 5 minutes
    echo "0 */6 * * * XDG_RUNTIME_DIR=/run/user/$(id -u) $TMP/updates-check" # Check for updates every 6 hours
} | crontab - || notify-send "Error" "Failed to update crontab"

