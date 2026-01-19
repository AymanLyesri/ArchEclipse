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
image_path="$TMP_DIR/clipboard_image_${timestamp}.webp"

# =========================
# Try image from clipboard
# =========================
if wl-paste --type image/png >"$image_path" 2>/dev/null; then
echo "Image saved to $image_path"
    action=$(notify-send "Clipboard Image" "Image copied" \
    -a "ScreenShot" \
        -i "$image_path" \
        --action=preview:Preview \
        --action=edit:Edit \
        --action=save:Save)

    echo "ACTION RECEIVED: $action" >> /tmp/notify.log

    case "$action" in
  0)  # preview
    swayimg --class preview-image "$image_path"
    ;;
  1)  # edit
    gimp "$image_path"
    ;;
  2) # Save
    save_path=$(zenity --file-selection \
      --save \
      --confirm-overwrite \
      --filename="$HOME/Pictures/clipboard_$(date +%Y%m%d_%H%M%S).png" \
      --title="Save Image")

    [ -z "$save_path" ] && exit 0

    cp "$image_path" "$save_path"
    notify-send "Info" "Saved to $(basename "$save_path")"
    ;;
esac
    exit 0
fi

# =========================
# Timestamped video path
# =========================
timestamp=$(date +%Y%m%d_%H%M%S)
video_path="$TMP_DIR/clipboard_video_${timestamp}.webm"

# =========================
# Try video uri-list from clipboard
# =========================
if clipboard_uri=$(wl-paste --no-newline --type text/uri-list 2>/dev/null) && [[ -n "$clipboard_uri" ]]; then
    # Extract file full path from uri-list (e.g., file:///home/user/Videos/clip.webm) to /home/user/Videos/clip.webm
    file_path="${clipboard_uri#file://}"
    # Extract extension (mp4, webm, mkv, etc.)
    extension="${file_path##*.}"

    # Vlc action
    notify-send -i "edit-copy" "Video Copied" "$file_path" \
        -a "ScreenRecord" \
        --action=play:Play \
        --action=save:Save | while read -r action; do
        case "$action" in
      0)  # play
        vlc "$file_path"
        ;;
      1)  # Save
        save_path=$(zenity --file-selection \
          --save \
          --confirm-overwrite \
          --filename="$HOME/Videos/clipboard_$(date +%Y%m%d_%H%M%S).$extension" \
          --title="Save Video")

        [ -z "$save_path" ] && exit 0

        cp "$file_path" "$save_path"
        notify-send "Info" "Saved to $(basename "$save_path")"
        ;;
    esac
    done
    exit 0
fi


# =========================
# Fallback: text clipboard
# =========================
if clipboard_text=$(wl-paste --no-newline --type text 2>/dev/null) && [[ -n "$clipboard_text" ]]; then
    notify-send -i "edit-copy" -a "Clipboard" "Text Copied" "$clipboard_text"
fi
