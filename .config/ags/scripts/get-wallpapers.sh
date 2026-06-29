#!/bin/bash

# Define the file that contains the wallpaper paths
wallpaper_config="$HOME/.config/hypr/wallpaper-daemon/config"
wallpaper_folder="$HOME/.config/wallpapers"
thumbnail_folder="$HOME/.config/ags/cache/thumbnails"
# Steam Workshop folder for Wallpaper Engine items (read directly, no copying)
we_folder="$HOME/.local/share/Steam/steamapps/workshop/content/431960"

# Initialize an empty array for the wallpaper paths
wallpaper_paths=()
# Parallel map of "<preview path>": "<project type>" for Wallpaper Engine items, so the
# selector can show the wallpaper TYPE (scene/web/video/application) instead of the
# preview file's extension. Emitted under the reserved "__types" key.
wallpaper_types=()

# Image/video extensions we treat as wallpapers
media_glob=(-iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.svg" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov")

# Generate a single 256px thumbnail (skips if it already exists)
make_thumbnail() {
    local src="$1" dst="$2"
    [ -f "$dst" ] && return
    notify-send "Generating Wallpaper Thumbnail" "Generating wallpaper thumbnail for $(basename "$src")" --expire-time=2000 --urgency=low
    mkdir -p "$(dirname "$dst")"
    local ext="${src##*.}"
    ext="${ext,,}"
    case "$ext" in
        mp4|webm|mkv|mov)
            ffmpeg -y -loglevel error -i "$src" -vf "thumbnail,scale=256:-1" -frames:v 1 "$dst" >/dev/null 2>&1
            ;;
        gif)
            magick "${src}[0]" -resize 256x256 -quality 85 -strip "$dst" >/dev/null 2>&1
            ;;
        *)
            magick "$src" -resize 256x256 -quality 85 -strip "$dst" >/dev/null 2>&1
            ;;
    esac
}

generate_thumbnails() {
    local source_dir="$1"
    local thumb_dir="$2"

    mkdir -p "$thumb_dir"

    # Generate missing thumbnails in parallel, preserving folder structure
    find "$source_dir" -type f \( "${media_glob[@]}" \) | while read -r wallpaper; do
        local relative_no_ext="${wallpaper#$source_dir/}"
        relative_no_ext="${relative_no_ext%.*}"
        make_thumbnail "$wallpaper" "$thumb_dir/$relative_no_ext.jpg" &
    done
    wait

    # Remove orphaned thumbnails (skip the wallpaperengine cache, handled below)
    find "$thumb_dir" -type f | while read -r thumb; do
        local relative_no_ext="${thumb#$thumb_dir/}"
        relative_no_ext="${relative_no_ext%.*}"
        case "$relative_no_ext" in wallpaperengine/*) continue ;; esac

        local original_exists=false
        for ext in jpg jpeg png webp bmp gif svg mp4 webm mkv mov; do
            if [ -f "$source_dir/$relative_no_ext.$ext" ]; then
                original_exists=true
                break
            fi
        done
        [ "$original_exists" = false ] && rm "$thumb"
    done
}

# Build the "wallpaperengine" category directly from the Steam Workshop folder.
# Each entry's path is the item's preview image; the daemon recovers the id from
# the parent folder name.
generate_wallpaperengine() {
    [ -d "$we_folder" ] || return
    # Only expose the category when the engine is actually installed.
    command -v linux-wallpaperengine >/dev/null 2>&1 ||
        [ -x "$HOME/linux-wallpaperengine/build/output/linux-wallpaperengine" ] || return
    local we_thumbs="$thumbnail_folder/wallpaperengine"
    local paths=()
    mkdir -p "$we_thumbs"

    # Show only items the user is actually SUBSCRIBED to. Steam drops an item from this manifest on
    # unsubscribe but can leave its content folder on disk until a later cleanup, so listing folders
    # alone keeps showing unsubscribed wallpapers. Falls back to folder listing if the manifest is
    # missing/unreadable. Item ids are the bare numeric keys whose value is an object ("{").
    local acf subscribed=""
    acf="$(dirname "$(dirname "$we_folder")")/appworkshop_431960.acf"
    if [ -f "$acf" ]; then
        subscribed="$(awk '
            prev ~ /^[ \t]*"[0-9]+"[ \t]*$/ && $0 ~ /^[ \t]*\{[ \t]*$/ { gsub(/[^0-9]/, "", prev); print prev }
            { prev = $0 }
        ' "$acf")"
    fi
    is_subscribed() { [ -z "$subscribed" ] && return 0; printf '%s\n' "$subscribed" | grep -qx "$1"; }

    # Newest-download-first: order Workshop items by folder mtime (≈ when Steam fetched or
    # last updated the item) instead of the default glob order (workshop id). Item folder
    # names are numeric ids with no spaces, so word-splitting the ls output here is safe.
    for item in $(ls -dt -- "$we_folder"/*/ 2>/dev/null); do
        local preview
        preview="$(find "$item" -maxdepth 1 -type f -iname 'preview.*' | head -n 1)"
        [ -n "$preview" ] || continue
        local id
        id="$(basename "$item")"
        is_subscribed "$id" || continue
        paths+=("\"$preview\"")
        # Project type (scene/web/video/application), lower-cased; default "scene".
        local wtype="scene"
        if command -v jq >/dev/null 2>&1 && [ -f "$item/project.json" ]; then
            wtype="$(jq -r '(.type // "scene") | ascii_downcase' "$item/project.json" 2>/dev/null)"
            [ -n "$wtype" ] && [ "$wtype" != "null" ] || wtype="scene"
        fi
        wallpaper_types+=("\"$preview\": \"$wtype\"")
        make_thumbnail "$preview" "$we_thumbs/$id.jpg" &
    done
    wait

    # Expose the type map (consumed by the selector for the per-tile badge).
    [ ${#wallpaper_types[@]} -gt 0 ] && wallpaper_paths+=("\"__types\": {$(IFS=,; echo "${wallpaper_types[*]}")}")

    # Prune thumbnails for items that are no longer installed
    for thumb in "$we_thumbs"/*.jpg; do
        [ -f "$thumb" ] || continue
        local id="${thumb##*/}"
        id="${id%.jpg}"
        { [ -d "$we_folder/$id" ] && is_subscribed "$id"; } || rm -f "$thumb"
    done

    [ ${#paths[@]} -gt 0 ] && wallpaper_paths+=("\"wallpaperengine\": [$(IFS=,; echo "${paths[*]}")]")
}

# check if $1 == current
if [ "$1" == "--current" ]; then
    if [ -z "$2" ]; then
        echo "Usage: get-wallpapers.sh --current <monitor>"
        exit 1
    fi
    monitor=$2
    # Read the file line by line (only per-workspace keys: w-1, w-2, ...)
    while IFS='=' read -r key path; do
        case "$key" in w-*) ;; *) continue ;; esac
        path=$(echo "$path" | sed "s~^\$HOME~$HOME~" | xargs)
        wallpaper_paths+=("\"$path\"")
    done <"$wallpaper_config/$monitor/defaults.conf"

    # For --current mode, output as JSON array
    echo "[${wallpaper_paths[@]}]" | sed 's/" "/", "/g'
    exit 0
fi

# Find all directories containing images and preserve full relative path as category
while IFS= read -r -d '' dir; do
    category="${dir#$wallpaper_folder/}"
    paths=()
    while IFS= read -r -d '' file; do
        paths+=("\"$file\"")
    done < <(find "$dir" -maxdepth 1 -type f \( "${media_glob[@]}" \) -print0)
    [ ${#paths[@]} -gt 0 ] && wallpaper_paths+=("\"$category\": [$(IFS=,; echo "${paths[*]}")]")
done < <(find "$wallpaper_folder" -type d -print0)

generate_thumbnails "$wallpaper_folder" "$thumbnail_folder"
generate_wallpaperengine

# Output the categorized wallpapers as a JSON object
(IFS=,; echo "{${wallpaper_paths[*]}}")
