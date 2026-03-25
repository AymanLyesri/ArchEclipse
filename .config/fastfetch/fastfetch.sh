#!/bin/bash
# Path to cache directory
CACHE_DIR="$HOME/.config/fastfetch/cache"

# Pick a random file from cache directory
IMAGE_PATH=$(find "$CACHE_DIR" -maxdepth 1 -type f 2>/dev/null | shuf -n 1)

if [ -z "$IMAGE_PATH" ]; then
    # Fetch system information without logo
    fastfetch
    exit 0
fi

# Fetch system information with fixed logo size
fastfetch --logo-type kitty --logo-recache --logo-height 25 --logo "$IMAGE_PATH"
