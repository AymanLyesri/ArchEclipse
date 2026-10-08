#!/bin/bash
# Fixed logo height in terminal rows. The terminal scales rows to pixels
# using the live cell height, so the image already grows/shrink proportionally
# with Ctrl+Shift +/- zoom. Scaling rows on top of that double-counts
# (pixels = rows x cell-height) and looks disproportionate.
LOGO_HEIGHT=16
CACHE_DIR="$HOME/.config/fastfetch/cache"

# Pick a random file from cache directory
IMAGE_PATH=$(find "$CACHE_DIR" -maxdepth 1 -type f 2>/dev/null | shuf -n 1)

if [ -z "$IMAGE_PATH" ]; then
    # Fetch system information without logo
    fastfetch
    exit 0
fi

# Fetch system information with fixed logo size (proportional by design)
fastfetch --logo-type kitty --logo-cache regen --logo-height "$LOGO_HEIGHT" --logo "$IMAGE_PATH"
