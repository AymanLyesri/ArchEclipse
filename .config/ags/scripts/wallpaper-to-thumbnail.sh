#!/bin/bash

default_wallpapers="$HOME/.config/wallpapers/defaults"                       # all wallpapers directory
default_wallpapers_thumbnails="$HOME/.config/ags/assets/thumbnails/defaults" # thumbnails wallpapers directory
custom_wallpapers="$HOME/.config/wallpapers/custom"                          # custom wallpapers directory
custom_wallpapers_thumbnails="$HOME/.config/ags/assets/thumbnails/custom"    # thumbnails custom wallpapers directory

# Ensure thumbnail directories exist
mkdir -p "$default_wallpapers_thumbnails" "$custom_wallpapers_thumbnails"

# Function to create and clean up thumbnails
generate_thumbnails() {
    local source_dir="$1"
    local thumb_dir="$2"
    
    # Generate missing thumbnails in parallel
    find "$source_dir" -type f | while read -r wallpaper; do
        thumbnail="$thumb_dir/$(basename "$wallpaper")"
        
        # Skip if thumbnail already exists
        if [ ! -f "$thumbnail" ]; then
            magick "$wallpaper" -resize 256x256 -quality 85 -strip "$thumbnail" &
        fi
    done
    
    wait # Ensure all parallel processes finish before proceeding
    
    # Remove orphaned thumbnails
    find "$thumb_dir" -type f | while read -r thumb; do
        original="$source_dir/$(basename "$thumb")"
        
        # Delete thumbnail if original wallpaper is missing
        if [ ! -f "$original" ]; then
            rm "$thumb"
        fi
    done
}

# Process both directories
generate_thumbnails "$default_wallpapers" "$default_wallpapers_thumbnails"
generate_thumbnails "$custom_wallpapers" "$custom_wallpapers_thumbnails"

echo "Thumbnails updated!"
