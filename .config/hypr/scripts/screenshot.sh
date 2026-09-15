#!/usr/bin/env bash
set -euo pipefail

# Usage: screenshot.sh --now [output.png] | --area [output.png]
#   Second arg overrides the destination path (must end in .png).
#   Set SCREENSHOT_OPTIMIZE=1 to run the (slow) ImageMagick strip/recompress.
timestamp=$(date +%Y%m%d_%H%M%S)
screenshot_dir="$HOME/Pictures/Screenshots"
screenshot_fullscreen_dir="$screenshot_dir/fullscreen"
screenshot_area_dir="$screenshot_dir/area"

# create screenshot directory if it doesn't exist
mkdir -p "$screenshot_dir"
mkdir -p "$screenshot_fullscreen_dir"
mkdir -p "$screenshot_area_dir"

mode="${1:-}"
custom_out="${2:-}"

if [[ "$mode" == "--now" ]]; then
    img="${custom_out:-$screenshot_fullscreen_dir/screenshot_$timestamp.png}"
    # Full output (PNG: Qt/Quickshell has no webp plugin, so PNG is
    # required for the notification preview and a correct image/png paste)
    grimblast --freeze save screen "$img" || exit 1

elif [[ "$mode" == "--area" ]]; then
    img="${custom_out:-$screenshot_area_dir/screenshot_area_$timestamp.png}"
    # Select region (non-zero exit = user cancelled, stay silent)
    grimblast --freeze save area "$img" || exit 1

else
    echo "Available Options : --now --area" >&2
    exit 1
fi

# Optional PNG optimize (off by default: magick recompress dominates
# screenshot latency; grim output is already fine for most uses)
if [[ "${SCREENSHOT_OPTIMIZE:-0}" == "1" ]]; then
    if command -v magick >/dev/null 2>&1; then
        magick "$img" -strip -define png:compression-level=6 "$img"
    fi
fi

# Send image to clipboard (bytes must match the declared MIME type)
wl-copy --type image/png < "$img"

# Notify user (quoted icon path so it arrives as a loadable file URL)
notify-send -a "Screenshot" -i "$img" "Screenshot saved" "Saved and copied to clipboard"
