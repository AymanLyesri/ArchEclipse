#!/usr/bin/env bash
set -euo pipefail

TMP=/tmp
SRC=$HOME/.config/hypr/scripts-c

mkdir -p "$TMP"

# Only recompile when the source is newer than the binary (login is hot path).
compile_if_stale() {
    local src="$1" out="$2"
    if [[ ! -x "$out" || "$src" -nt "$out" ]]; then
        echo "Compiling $(basename "$out")..."
        gcc -O2 -Wall -o "$out" "$src"
    else
        echo "$(basename "$out") up to date, skipping compile."
    fi
}

compile_if_stale "$SRC/battery-check.c" "$TMP/battery-check"
compile_if_stale "$SRC/updates-check.c" "$TMP/updates-check"
compile_if_stale "$SRC/wallpaper-loop.c" "$TMP/wallpaper-loop"

# Restart only the wallpaper daemon (exact-name match: -f would also match
# this script's own command line). Leave hyprpaper running to avoid flicker.
pkill -x "wallpaper-loop" 2>/dev/null || true
sleep 0.3

"$TMP/wallpaper-loop" &

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

# Install cron entries only when missing (rewriting crontab on every login
# races with concurrent logins and drops unrelated user edits in between).
if ! crontab -l 2>/dev/null | grep -q "$TMP/battery-check"; then
    {
        crontab -l 2>/dev/null || true
        # XDG_RUNTIME_DIR so notify-send can reach the desktop session
        echo "*/5 * * * * XDG_RUNTIME_DIR=/run/user/$(id -u) $TMP/battery-check" # Check battery every 5 minutes
        echo "0 */6 * * * XDG_RUNTIME_DIR=/run/user/$(id -u) $TMP/updates-check" # Check for updates every 6 hours
    } | crontab - || notify-send "Error" "Failed to update crontab"
fi

