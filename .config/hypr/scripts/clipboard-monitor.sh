#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config
# =========================
TMP_DIR="/tmp"
PREVIEW_CMD="swayimg --class preview-image"
EDIT_CMD="gimp"

# =========================
# Timestamped image path
# =========================
timestamp=$(date +%Y%m%d_%H%M%S)
image_path="$TMP_DIR/clipboard_image_${timestamp}.png"

# =========================
# Try image from clipboard
# =========================
if wl-paste --type image/png >"$image_path" 2>/dev/null; then
    action=$(notify-send "Clipboard" "Image copied" \
        -i "$image_path" \
        --action=preview:Preview \
        --action=edit:Edit \
        --action=delete:Delete)

    echo "ACTION RECEIVED: $action" >> /tmp/notify.log

    case "$action" in
  0)  # preview
    swayimg --class preview-image "$image_path"
    ;;
  1)  # edit
    gimp "$image_path"
    ;;
  2)  # delete
    rm -f "$image_path"
    ;;
esac


    exit 0
fi

# =========================
# Fallback: text clipboard
# =========================
if clipboard_text=$(wl-paste --no-newline --type text 2>/dev/null) && [[ -n "$clipboard_text" ]]; then
    notify-send "Clipboard" "$clipboard_text"
fi
