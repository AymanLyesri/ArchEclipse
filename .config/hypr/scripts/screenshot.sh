#!/bin/bash
timestamp=$(date +%Y%m%d_%H%M%S)
screenshot_dir="$HOME/Pictures/Screenshots"

# create screenshot directory if it doesn't exist
mkdir -p "$screenshot_dir"

# check if file argument is passed as second argument
if [[ "$2" ]]; then
    file=$2
    echo "File : $file"
fi

# notify and view screenshot

if [[ "$1" == "--now" ]]; then
    img="$screenshot_dir/screenshot_$timestamp.webp"
    # Full output
    grimblast --freeze save screen "$img"
    
    elif [[ "$1" == "--area" ]]; then
    img="$screenshot_dir/screenshot_area_$timestamp.webp"
    # Select region
    grimblast --freeze save area "$img"
    
else
    
    echo -e "Available Options : --now --area --all"
    exit 1
fi

# Convert to WebP (high compression, visually lossless)
magick convert "$img" -define webp:method=6 -quality 90 "$img"

# Send optimized image to clipboard
wl-copy --type image/png < "$img"
