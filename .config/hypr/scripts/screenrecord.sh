#!/bin/bash
timestamp=$(date +%Y%m%d_%H%M%S)
screenshot_dir="$HOME/Videos/ScreenRecords"
notification_id="/tmp/screenrecord_notification_id"
file_name=/tmp/screenrecord_name

# create screenrecord directory if it doesn't exist
mkdir -p "$screenshot_dir"

# --- Automatic Audio Detection ---
# Gets the name of the current default output and appends .monitor
audio_source=$(pactl get-default-sink).monitor

# =========================
# Retriger to stop existing recording
# =========================
# check if a recording is already in progress
if pgrep -x "wf-recorder" > /dev/null; then
    # get the pid of the existing recording process
    existing_pid=$(pgrep -x "wf-recorder")
    # send SIGINT to stop the recording
    kill -INT "$existing_pid"
    # dismiss existing notification
    ags request delete-notification $(cat "$notification_id") 2>/dev/null
    # copy
    wl-copy --type text/uri-list "file://$(cat $file_name)" 2>/dev/null
    exit 0
fi


# =========================
# c: Codec options
# crf: Constant Rate Factor (lower means better quality, range 0-63)
# fps: Frames per second
# =========================

if [[ "$1" == "--now" ]]; then
    file="$screenshot_dir/screenrecord_$timestamp.mp4"
    # Record full screen
    wf-recorder \
    -a "$audio_source" \
    -p crf=35 \
    -F fps=24 \
    -f "$file" &
    rec_pid=$!
    
    elif [[ "$1" == "--area" ]]; then
    file="$screenshot_dir/screenrecord_area_$timestamp.mp4"
    # Record selected area
    wf-recorder -g "$(slurp)" \
    -a "$audio_source" \
    -p crf=35 \
    -F fps=24 \
    -f "$file" &
    rec_pid=$!
    
else
    echo -e "Available Options : --now --area"
    exit 1
fi

id=$(notify-send \
    -p \
    -a "Recorder" \
    -i "media-record" \
    "Recording…" "Retrigger to stop recording."
)

echo $id > $notification_id
echo $file > $file_name
