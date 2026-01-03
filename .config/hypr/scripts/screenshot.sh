#!/bin/bash

file="$(date +'%s_hyprshot.webp')"
screenshot_dir="$HOME/Pictures/Screenshots"

# check if file argument is passed as second argument
if [[ "$2" ]]; then
    file=$2
    echo "File : $file"
fi

# notify and view screenshot

img="$screenshot_dir/$file"

echo "Saving screenshot to $img"

if [[ "$1" == "--now" ]]; then
    # Full output
    grim "$img"
    
    elif [[ "$1" == "--area" ]]; then
    # Select region
    grim -g "$(slurp)" "$img"
    
else
    
    echo -e "Available Options : --now --area --all"
fi

# Convert to WebP (high compression, visually lossless)
convert "$img" -define webp:method=6 -quality 80 "$img"

# Send optimized image to clipboard
wl-copy --type image/png < "$img"
