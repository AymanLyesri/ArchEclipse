#!/bin/bash

# Define the file that contains the wallpaper paths
wallpaper_config="$HOME/.config/hypr/wallpaper-daemon/config"
wallpaper_folder="$HOME/.config/wallpapers"

# Self-healing structure (fresh clones no longer carry the skeleton dirs
# since wallpapers left the repo): the download writers mkdir -p their own
# subdir, but the first read must not fail or spam stderr when nothing
# exists yet.
mkdir -p "$wallpaper_folder/custom" "$wallpaper_folder/wallhaven" "$wallpaper_folder/defaults"

# Initialize an empty array for the wallpaper paths
wallpaper_paths=()

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
    done <"$wallpaper_config/$monitor/defaults.conf"

else

    # Find all directories containing images and preserve full relative path as category
    while IFS= read -r -d '' dir; do
        # Get relative path from wallpaper_folder to preserve full category path
        category="${dir#$wallpaper_folder/}"
        paths=()
        while IFS= read -r -d '' file; do
            paths+=("\"$file\"")
        done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.svg" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \) -print0)
        
        # Only add category if it has images
        if [ ${#paths[@]} -gt 0 ]; then
            wallpaper_paths+=("\"$category\": [$(IFS=,; echo "${paths[*]}")]")
        fi
    done < <(find "$wallpaper_folder" -type d -print0)

    # For categorized wallpapers, output as JSON object
    (IFS=,; echo "{${wallpaper_paths[*]}}")
    exit 0
fi

# For --current mode, output as JSON array
echo "[${wallpaper_paths[@]}]" | sed 's/" "/", "/g'
