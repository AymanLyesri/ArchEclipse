#!/bin/bash
screenrecord_dir="$HOME/Videos/ScreenRecords"
screenrecord_fullscreen_dir="$screenrecord_dir/fullscreen"
screenrecord_area_dir="$screenrecord_dir/area"
pid_file="/tmp/screenrecord.pid"
file_name="/tmp/screenrecord_name"
log_file="/tmp/screenrecord.log"

slog() {
    # Append-only diagnostic log (never fails the script).
    echo "$(date +%Y%m%d_%H%M%S) [$$] $*" >> "$log_file" 2>/dev/null || true
}

mkdir -p "$screenrecord_dir"
mkdir -p "$screenrecord_fullscreen_dir"
mkdir -p "$screenrecord_area_dir"

is_recorder_pid() {
    # True if $1 is a live wf-recorder process (protects against stale
    # pid files and PID reuse killing an unrelated process).
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    [[ "$(ps -o comm= -p "$1" 2>/dev/null)" == "wf-recorder" ]]
}

drop_stale_pid() {
    if [[ -f "$pid_file" ]]; then
        old_pid="$(cat "$pid_file" 2>/dev/null)"
        if ! is_recorder_pid "$old_pid"; then
            rm -f "$pid_file" "$file_name"
        fi
    fi
}

start() {
    slog "start args=[$*] wayland=${WAYLAND_DISPLAY:-UNSET} hypr=${HYPRLAND_INSTANCE_SIGNATURE:-UNSET}"
    drop_stale_pid
    if [[ -f "$pid_file" ]]; then
        slog "start abort: already recording pid=$(cat "$pid_file" 2>/dev/null)"
        echo "Already recording (pid $(cat "$pid_file"))" >&2
        exit 1
    fi

    timestamp=$(date +%Y%m%d_%H%M%S)

    # Audio source is optional: a broken value must not kill the recording.
    # NOTE: wf-recorder's -a takes an OPTIONAL arg (getopt "a::"), so the
    # device must be attached ("-afoo") or long-opt ("--audio=foo").
    # "-a foo" with a space leaves optarg NULL and silently records the
    # Pulse default source (here: audiorelay-virtual-mic-sink = silence).
    audio_args=()
    if sink=$(pactl get-default-sink 2>/dev/null) && [[ -n "$sink" ]]; then
        audio_args=("--audio=${sink}.monitor")
    fi
    slog "start audio sink=[${sink:-UNSET}] args=[${audio_args[*]:-none}]"

    if [[ "$1" == "--area" ]]; then
        # A single trigger must never stack two selectors: two slurp
        # instances contend for the compositor overlay and NEITHER
        # displays until one is killed (kill-one-side frees the other).
        # The pgrep check alone races when two starts land within
        # milliseconds, so the check+launch is serialized with an
        # atomic flock (held until this script exits). Duplicates exit
        # silent; the first selection keeps the display.
        exec {area_lock}>/tmp/screenrecord-area.lock
        if ! flock -n "$area_lock"; then
            slog "area: duplicate trigger ignored (selection already in progress)"
            exit 0
        fi
        if pgrep -x slurp >/dev/null 2>&1; then
            slog "area: duplicate trigger ignored (slurp already running)"
            exit 0
        fi
        file="$screenrecord_area_dir/screenrecord_area_${timestamp}.mp4"
        slog "area: invoking slurp..."
        # Parity with grimblast's working area selection (screenshot.sh):
        # freeze the screen and disable the open-animation for slurp's
        # layer namespace — without this the overlay can stay invisible.
        hyprctl keyword layerrule "match:selection, no_anim on" >/dev/null 2>&1 || true
        freeze_pid=""
        if command -v hyprpicker >/dev/null 2>&1; then
            hyprpicker -rz & freeze_pid=$!
            sleep 0.2
        fi
        # NOTE: stdin MUST be /dev/null. Quickshell's Process (and any
        # piped launcher) gives slurp an open-but-empty stdin pipe, and
        # slurp blocks before creating its overlay surface while stdin
        # has no data/EOF — alive, invisible, unresponsive. </dev/null
        # makes the launch context irrelevant.
        geometry=$(slurp </dev/null 2>>"$log_file") || {
            code=$?
            [[ -n "$freeze_pid" ]] && kill "$freeze_pid" 2>/dev/null || true
            slog "area: slurp exited code=${code} (cancel or crash)"
            exit 1  # user cancelled selection
        }
        [[ -n "$freeze_pid" ]] && kill "$freeze_pid" 2>/dev/null || true
        slog "area: geometry=[${geometry}]"
        # Release the selection lock BEFORE spawning the recorder:
        # background children inherit our fds, so a leaked lock would
        # stay held for the whole recording and wrongly reject triggers.
        # From here on the pid file owns mutual exclusion.
        exec {area_lock}>&-
        # shellcheck disable=SC2086
        wf-recorder -g "$geometry" ${audio_args[@]} -p crf=24 -p preset=medium -F fps=60 -f "$file" &
    else
        file="$screenrecord_fullscreen_dir/screenrecord_${timestamp}.mp4"
        # shellcheck disable=SC2086
        wf-recorder ${audio_args[@]} -p crf=24 -p preset=medium -F fps=60 -f "$file" &
    fi

    rec_pid=$!
    echo "$rec_pid" > "$pid_file"
    echo "$file" > "$file_name"

    # Verify it actually survived startup (bad args/codec fail fast).
    sleep 1
    if ! is_recorder_pid "$rec_pid"; then
        slog "start FAILED: wf-recorder pid=${rec_pid} died within 1s file=[${file}]"
        rm -f "$pid_file" "$file_name"
        echo "wf-recorder failed to start — see output above" >&2
        exit 1
    fi
    slog "start OK: pid=${rec_pid} file=[${file}]"
    notify-send -a "Recorder" -i "media-record" "Recording Started" "$(basename "$file")"
}

stop() {
    drop_stale_pid

    target=""
    if [[ -f "$pid_file" ]]; then
        target="$(cat "$pid_file")"
    fi
    # Fallback when the pid file leaked but a recorder is still running.
    if ! is_recorder_pid "$target"; then
        target="$(pgrep -x wf-recorder | head -n 1)"
    fi
    if ! is_recorder_pid "$target"; then
        rm -f "$pid_file" "$file_name"
        echo "No active recording found" >&2
        exit 1
    fi

    file="$(cat "$file_name" 2>/dev/null)"
    kill -INT "$target"

    # `wait` only works for child processes; poll instead so the file
    # is flushed before we announce completion (max ~5s).
    for _ in $(seq 1 50); do
        is_recorder_pid "$target" || break
        sleep 0.1
    done
    if is_recorder_pid "$target"; then
        kill -KILL "$target" 2>/dev/null
        sleep 0.3
    fi

    rm -f "$pid_file" "$file_name"
    if [[ -n "$file" ]]; then
        wl-copy --type text/uri-list "file://${file}" 2>/dev/null
        notify-send -a "Recorder" -i "media-record" "Recording Stopped" "$(basename "$file")"
    else
        notify-send -a "Recorder" -i "media-record" "Recording Stopped" "File copied to clipboard."
    fi
}

case "$1" in
    start) start "$2" ;;
    stop) stop ;;
    *) echo "Usage: $0 start [--area] | stop"; exit 1 ;;
esac