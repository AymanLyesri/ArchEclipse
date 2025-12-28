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


# screenshotAll() {
#     ScreenshotsDir="$HOME/Pictures/WorkspaceShots"
#     screenshots=()

#     # active workspaces
#     workspace_ids=()
#     while IFS= read -r line; do
#         id=$(echo "$line" | awk '{print $3}')
#         if [[ $id =~ ^[0-9]+$ ]]; then
#             workspace_ids+=("$id")
#         fi
#     done < <(hyprctl workspaces | grep '^workspace ID' | sort -n)

#     hyprctl dispatch workspace 11

#     # create directory if not exists
#     mkdir -p "$ScreenshotsDir"

#     # take screenshots
#     for id in "${workspace_ids[@]}"; do
#         hyprctl dispatch workspace "$id"
#         sleep 2
#         file="$ScreenshotsDir/$(date +'%s_hyprshot.jpg')"
#         $HOME/.config/hypr/scripts/screenshot.sh --now "$file" && screenshots+=("$file")
#     done

#     # Reorder the screenshots array to append the first screenshot (0) as the last one (10)
#     screenshots=("${screenshots[@]:1}" "${screenshots[0]}")

#     # merge screenshots
#     convert -append ${screenshots[@]} "$ScreenshotsDir/$(date +'%s_hyprshot_result.jpg')"

#     # copy to clipboard
#     wl-copy -t image/jpg <"$ScreenshotsDir/$(date +'%s_hyprshot_result.jpg')"
# }
