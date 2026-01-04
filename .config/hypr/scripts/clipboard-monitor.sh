#!/bin/bash

echo "[$(date '+%H:%M:%S')] EXEC" >> /tmp/clip-count.log

# Try to get text first (most common case)
clipboard_content=$(wl-paste --no-newline 2>/dev/null)

if [ -n "$clipboard_content" ]; then
    # We have text content, show it
    notify-send "Clipboard" "$clipboard_content"
    echo "[$(date '+%H:%M:%S')] SENT: ${clipboard_content:0:15}" >> /tmp/clip-count.log
else
    # No text, try image
    timestamp=$(date +%Y%m%d_%H%M%S)
    image_path="/tmp/clipboard_image_${timestamp}.png"
    if timeout 0.5s wl-paste --type image/png >"$image_path" 2>/dev/null; then
        notify-send "Clipboard" "Image copied" -i "$image_path"
        echo "[$(date '+%H:%M:%S')] IMAGE" >> /tmp/clip-count.log
    fi
fi

echo "[$(date '+%H:%M:%S')] DONE" >> /tmp/clip-count.log
