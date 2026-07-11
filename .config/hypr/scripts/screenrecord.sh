#!/bin/bash
screenshot_dir="$HOME/Videos/ScreenRecords"
pid_file="/tmp/screenrecord.pid"
file_name="/tmp/screenrecord_name"

mkdir -p "$screenshot_dir"

start() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    audio_source=$(pactl get-default-sink).monitor
    
    if [[ "$1" == "--area" ]]; then
        file="$screenshot_dir/screenrecord_area_${timestamp}.mp4"
        geometry=$(slurp) || exit 1  # user cancelled selection
        wf-recorder -g "$geometry" -a"$audio_source" -p crf=24 -p preset=medium -F fps=60 -f "$file" &
    else
        file="$screenshot_dir/screenrecord_${timestamp}.mp4"
        wf-recorder -a"$audio_source" -p crf=24 -p preset=medium -F fps=60 -f "$file" &
    fi
    
    echo $! > "$pid_file"
    echo "$file" > "$file_name"
}

stop() {
    [[ -f "$pid_file" ]] || exit 1
    kill -INT "$(cat "$pid_file")"
    wait "$(cat "$pid_file")" 2>/dev/null   # block until ffmpeg flushes the file
    rm -f "$pid_file"
    wl-copy --type text/uri-list "file://$(cat "$file_name")" 2>/dev/null
    notify-send -a "Recorder" -i "media-record" "Recording Stopped" "File copied to clipboard."
}

case "$1" in
    start) start "$2" ;;
    stop) stop ;;
    *) echo "Usage: $0 start [--area] | stop"; exit 1 ;;
esac