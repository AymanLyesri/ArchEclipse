#!/bin/bash
# Fixed logo height in terminal rows. The terminal scales rows to pixels
# using the live cell height, so the image already grows/shrink proportionally
# with Ctrl+Shift +/- zoom. Scaling rows on top of that double-counts
# (pixels = rows x cell-height) and looks disproportionate.
LOGO_HEIGHT=18
CACHE_DIR="$HOME/.config/fastfetch/cache"

# Shuffle-bag: random without replacement. Queue holds the full shuffled
# set; each run shows the head and rotates it to the tail. Reshuffle once
# when pins change (add/delete) or the queue is missing/empty.
QUEUE_FILE="$CACHE_DIR/.queue"
LIST=$(find "$CACHE_DIR" -maxdepth 1 -type f ! -name ".*" 2>/dev/null | sort)

if [ -z "$LIST" ]; then
    # Fetch system information without logo
    fastfetch
    exit 0
fi

if [ ! -s "$QUEUE_FILE" ] || [ "$(sort "$QUEUE_FILE" 2>/dev/null)" != "$LIST" ]; then
    echo "$LIST" | shuf > "$QUEUE_FILE"
fi

IMAGE_PATH=$(head -n 1 "$QUEUE_FILE")

# Rotate head to tail so each image shows once per cycle (atomic replace)
TMP_FILE=$(mktemp)
if tail -n +2 "$QUEUE_FILE" > "$TMP_FILE" 2>/dev/null; then
    echo "$IMAGE_PATH" >> "$TMP_FILE"
    mv -f "$TMP_FILE" "$QUEUE_FILE"
else
    rm -f "$TMP_FILE"
fi

# Fetch system information with fixed logo size (proportional by design)
fastfetch --logo-type sixel --logo-cache regen --logo-height "$LOGO_HEIGHT" --logo "$IMAGE_PATH"
