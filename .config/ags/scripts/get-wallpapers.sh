#!/bin/bash

# Define the file that contains the wallpaper paths
hyprpaper_config="$HOME/.config/hypr/hyprpaper/config"
wallpaper_folder="$HOME/.config/wallpapers"
thumbnail_folder="$HOME/.config/ags/assets/thumbnails"

# Initialize an empty array for the wallpaper paths
wallpaper_paths=()

generate_thumbnails() {
    local source_dir="$1"
    local thumb_dir="$2"
    
    # Ensure thumbnail directory exists
    mkdir -p "$thumb_dir"
    
    # Generate missing thumbnails in parallel, preserving folder structure
    find "$source_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.svg" \) | while read -r wallpaper; do
        # Get relative path from source_dir to preserve folder structure
        relative_path="${wallpaper#$source_dir/}"
        thumbnail="$thumb_dir/$relative_path"
        
        # Create subdirectory if needed
        mkdir -p "$(dirname "$thumbnail")"
        
        # Skip if thumbnail already exists
        if [ ! -f "$thumbnail" ]; then
            magick "$wallpaper" -resize 256x256 -quality 85 -strip "$thumbnail" &
        fi
    done
    
    wait # Ensure all parallel processes finish before proceeding
    
    # Remove orphaned thumbnails
    find "$thumb_dir" -type f | while read -r thumb; do
        # Get relative path from thumb_dir to match with source structure
        relative_path="${thumb#$thumb_dir/}"
        original="$source_dir/$relative_path"
        
        # Delete thumbnail if original wallpaper is missing
        if [ ! -f "$original" ]; then
            rm "$thumb"
        fi
    done
}

# check if $1 == current
if [ "$1" == "--current" ]; then
    # check if $2 is set
    if [ -z "$2" ]; then
        echo "Usage: get-wallpapers.sh --current <monitor>"
        exit 1
    else
        monitor=$2
    fi
    # Read the file line by line
    while IFS='=' read -r key path; do
        # Trim any whitespace from the path and add to the array
        path=$(echo "$path" | sed "s~^\$HOME~$HOME~" | xargs)
        wallpaper_paths+=("\"$path\"")
    done <"$hyprpaper_config/$monitor/defaults.conf"

else

    # Find all directories containing images and preserve full relative path as category
    while IFS= read -r -d '' dir; do
        # Get relative path from wallpaper_folder to preserve full category path
        category="${dir#$wallpaper_folder/}"
        paths=()
        while IFS= read -r -d '' file; do
            paths+=("\"$file\"")
        done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.svg" \) -print0)
        
        # Only add category if it has images
        if [ ${#paths[@]} -gt 0 ]; then
            wallpaper_paths+=("\"$category\": [$(IFS=,; echo "${paths[*]}")]")
        fi
    done < <(find "$wallpaper_folder" -type d -print0)

    # Generate thumbnails based on all wallpapers found
    generate_thumbnails "$wallpaper_folder" "$thumbnail_folder"
    
    # For categorized wallpapers, output as JSON object
    (IFS=,; echo "{${wallpaper_paths[*]}}")
    exit 0
fi

# For --current mode, output as JSON array
echo "[${wallpaper_paths[@]}]" | sed 's/" "/", "/g'
