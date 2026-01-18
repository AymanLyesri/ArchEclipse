#!/bin/bash
timestamp=$(date +%Y%m%d_%H%M%S)
screenshot_dir="$HOME/Videos/ScreenRecords"

# create screenrecord directory if it doesn't exist
mkdir -p "$screenshot_dir"

# --- Automatic Audio Detection ---
# Gets the name of the current default output and appends .monitor
audio_source=$(pactl get-default-sink).monitor

# =========================
# c: Codec options
# crf: Constant Rate Factor (lower means better quality, range 0-63)
# fps: Frames per second
# =========================

if [[ "$1" == "--now" ]]; then
    file="$screenshot_dir/screenrecord_$timestamp.webm"
    # Record full screen
    wf-recorder \
    -a "$audio_source" \
    -C libopus \
    -c libvpx-vp9 \
    -p crf=45 \
    -r fps=24 \
    -f "$file" &
    rec_pid=$!
    
    elif [[ "$1" == "--area" ]]; then
    file="$screenshot_dir/screenrecord_area_$timestamp.webm"
    # Record selected area
    wf-recorder -g "$(slurp)" \
    -a "$audio_source" \
    -C libopus \
    -c libvpx-vp9 \
    -p crf=45 \
    -r fps=24 \
    -f "$file" &
    rec_pid=$!
    
else
    echo -e "Available Options : --now --area"
    exit 1
fi

notify-send \
-a "Recorder" \
-i media-record \
-A stop=Stop\ \&\ Copy \
"Recording…" "Click to stop and copy" \
| while read -r action; do
    [ "$action" = stop ] && kill -INT "$rec_pid"
done

wait "$rec_pid"
wl-copy --type text/uri-list "file://$file"