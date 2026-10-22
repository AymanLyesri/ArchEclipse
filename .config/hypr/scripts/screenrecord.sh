#!/bin/bash
screenrecord_dir="$HOME/Videos/ScreenRecords"
screenrecord_fullscreen_dir="$screenrecord_dir/fullscreen"
screenrecord_area_dir="$screenrecord_dir/area"
pid_file="/tmp/screenrecord.pid"
file_name="/tmp/screenrecord_name"
monitor_file="/tmp/screenrecord_monitor"
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
        alive=0
        while IFS= read -r p; do
            if is_recorder_pid "$p"; then
                alive=1
                break
            fi
        done < "$pid_file" 2>/dev/null || true
        if [[ $alive -eq 0 ]]; then
            rm -f "$pid_file" "$file_name" "$monitor_file"
        fi
    fi
}

# Sets global array codec_args to HW (VAAPI) or fast SW x264.
# Env override: SCREENRECORD_CODEC=vaapi|software. Logs choice via slog.
# Returns 0 for HW, 1 for SW (so callers can auto-fallback).
pick_codec_args() {
    local force="${SCREENRECORD_CODEC:-auto}"
    local render_dev=""

    for d in /dev/dri/renderD*; do
        [[ -e "$d" ]] && { render_dev="$d"; break; }
    done

    local have_vaapi=1
    # grep exit 0 = found. 0 means VAAPI encoder available.
    if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q " h264_vaapi "; then
        have_vaapi=0
    else
        have_vaapi=1
    fi

    if [[ "$force" == "software" ]]; then
        codec_args=(-p preset=veryfast -p crf=23 -p tune=zerolatency -r 60)
        slog "codec: forced software x264 veryfast (SCREENRECORD_CODEC=software)"
        return 1
    fi

    if [[ "$force" == "vaapi" || "$force" == "auto" ]] && [[ -n "$render_dev" && "$have_vaapi" -eq 0 ]]; then
        codec_args=(-c h264_vaapi -d "$render_dev" -F scale_vaapi=format=nv12 -r 60)
        slog "codec: VAAPI h264_vaapi via ${render_dev}"
        return 0
    fi

    if [[ "$force" == "vaapi" ]]; then
        slog "codec: VAAPI requested but unavailable (dev=[${render_dev:-none}] have_vaapi=${have_vaapi}), falling back to software"
    else
        slog "codec: VAAPI unavailable (dev=[${render_dev:-none}] have_vaapi=${have_vaapi}), using software x264 veryfast"
    fi
    codec_args=(-p preset=veryfast -p crf=23 -p tune=zerolatency -r 60)
    return 1
}

start() {
    local area=0 monitor="" all=0
    while (($#)); do
        case "$1" in
            --area) area=1; shift ;;
            --monitor)
                monitor="${2:-}"
                shift 2
                ;;
            --all)
                all=1; shift ;;
            *)
                echo "Unknown start option: $1" >&2
                exit 2
                ;;
        esac
    done

    if [[ "$all" -eq 0 && -z "$monitor" ]]; then
        monitor="$(hyprctl activeworkspace -j | jq -r '.monitor')"
    fi
    if [[ "$all" -eq 0 && ( -z "$monitor" || "$monitor" == "null" ) ]]; then
        echo "Could not determine the focused monitor" >&2
        exit 1
    fi

    slog "start monitor=[$monitor] area=[$area] all=[$all] wayland=${WAYLAND_DISPLAY:-UNSET} hypr=${HYPRLAND_INSTANCE_SIGNATURE:-UNSET}"
    drop_stale_pid
    if [[ -f "$pid_file" ]]; then
        slog "start abort: already recording pid=$(cat "$pid_file" 2>/dev/null | tr '\n' ' ')"
        echo "Already recording (pid $(cat "$pid_file" | tr '\n' ' '))" >&2
        exit 1
    fi

    timestamp=$(date +%Y%m%d_%H%M%S)

    # Audio source is optional: a broken value must not kill the recording.
    audio_args=()
    if sink=$(pactl get-default-sink 2>/dev/null) && [[ -n "$sink" ]]; then
        audio_args=("--audio=${sink}.monitor")
    fi
    slog "start audio sink=[${sink:-UNSET}] args=[${audio_args[*]:-none}]"

    if [[ "$area" -eq 1 && "$all" -eq 1 ]]; then
        echo "--area and --all cannot be combined" >&2
        exit 1
    fi

    if [[ "$area" -eq 1 ]]; then
        exec {area_lock}>/tmp/screenrecord-area.lock
        if ! flock -n "$area_lock"; then
            slog "area: duplicate trigger ignored (selection already in progress)"
            exec {area_lock}>&-
            exit 0
        fi
        if pgrep -x slurp >/dev/null 2>&1; then
            slog "area: duplicate trigger ignored (slurp already running)"
            exec {area_lock}>&-
            exit 0
        fi
        file="$screenrecord_area_dir/screenrecord_area_${timestamp}.mp4"
        slog "area: opening free-form selection on monitor=[$monitor]"
        hyprctl keyword layerrule "match:selection, no_anim on" >/dev/null 2>&1 || true
        freeze_pid=""
        if command -v hyprpicker >/dev/null 2>&1; then
            hyprpicker -rz & freeze_pid=$!
            sleep 0.2
        fi
        # Same free-form region drag as screenshot.sh --area: slurp without
        # window-rects restriction (the old window-list slurp failed with
        # "No visible windows" whenever the active workspace had no matches).
        selection=$(slurp -f '%x,%y %wx%h' 2>>"$log_file") || {
            code=$?
            if [[ -n "$freeze_pid" ]]; then
                kill "$freeze_pid" 2>/dev/null || true
                wait "$freeze_pid" 2>/dev/null || true
            fi
            slog "area: slurp exited code=${code} (cancel or crash)"
            exit 1
        }
        if [[ -n "$freeze_pid" ]]; then
            kill "$freeze_pid" 2>/dev/null || true
            wait "$freeze_pid" 2>/dev/null || true
        fi
        geometry="$selection"
        slog "area: selected region geometry=[$geometry]"
        exec {area_lock}>&-
        # The selected coordinates are compositor-global, so pass geometry
        # without -o; wf-recorder captures the corresponding region directly.
        geom_args=(-g "$geometry")
        output_args=()
    else
        geom_args=()
    fi

    # Pick codec once and reuse for launches
    codec_args=()
    if pick_codec_args; then
        used_hw=1
    else
        used_hw=0
    fi

    if [[ "$all" -eq 1 ]]; then
        monitors=( $(hyprctl monitors -j | jq -r '.[].name') )
        if [[ ${#monitors[@]} -eq 0 ]]; then
            echo "No monitors found" >&2
            exit 1
        fi
        pids=()
        files=()
        mons_out=()
        for m in "${monitors[@]}"; do
            safe_m=$(echo "$m" | tr '/ ' '__')
            file="$screenrecord_fullscreen_dir/screenrecord_${safe_m}_${timestamp}.mp4"
            output_args=( -o "$m" )
            slog "start cmd: wf-recorder ${output_args[*]} ${geom_args[*]:-} ${audio_args[*]:-none} ${codec_args[*]} -f [${file}]"
            wf-recorder "${output_args[@]}" "${geom_args[@]}" "${audio_args[@]}" "${codec_args[@]}" -f "$file" &
            rec_pid=$!
            pids+=("$rec_pid")
            files+=("$file")
            mons_out+=("$m")
            sleep 0.15
        done
        # Persist pid/file/monitor lists
        printf "%s\n" "${pids[@]}" > "$pid_file"
        printf "%s\n" "${files[@]}" > "$file_name"
        printf "%s\n" "${mons_out[@]}" > "$monitor_file"

        # Verify startup; try software fallback for any dead pid
        sleep 1
        for idx in "${!pids[@]}"; do
            pid=${pids[$idx]}
            file=${files[$idx]}
            mon=${mons_out[$idx]}
            if ! is_recorder_pid "$pid"; then
                if [[ "$used_hw" -eq 1 ]]; then
                    slog "start HW FAILED for monitor $mon: pid=${pid} died, retrying software"
                    codec_args_sw=( -p preset=veryfast -p crf=23 -p tune=zerolatency -r 60 )
                    wf-recorder -o "$mon" "${geom_args[@]}" "${audio_args[@]}" "${codec_args_sw[@]}" -f "$file" &
                    newpid=$!
                    pids[$idx]="$newpid"
                    sleep 0.2
                fi
            fi
        done
        # Rewrite pid file with updated pids
        printf "%s\n" "${pids[@]}" > "$pid_file"
        slog "start OK: pids=$(cat "$pid_file" | tr '\n' ' ') files=$(cat "$file_name" | tr '\n' ' ')"
        notify-send -a "Recorder" -i "media-record" "Recording Started" "${#pids[@]} monitors"
        exit 0
    fi

    # Single-monitor fullscreen or selected-window start
    if [[ "$area" -eq 1 ]]; then
        file="$screenrecord_area_dir/screenrecord_area_${timestamp}.mp4"
    else
        file="$screenrecord_fullscreen_dir/screenrecord_${timestamp}.mp4"
        output_args=( -o "$monitor" )
    fi

    slog "start cmd: wf-recorder ${output_args[*]} ${geom_args[*]:-} ${audio_args[*]:-none} ${codec_args[*]} -f [${file}]"

    wf-recorder "${output_args[@]}" "${geom_args[@]}" "${audio_args[@]}" "${codec_args[@]}" -f "$file" &
    rec_pid=$!
    echo "$rec_pid" > "$pid_file"
    echo "$file" > "$file_name"
    echo "$monitor" > "$monitor_file"

    sleep 1
    if ! is_recorder_pid "$rec_pid"; then
        if [[ "$used_hw" -eq 1 ]]; then
            slog "start HW FAILED: pid=${rec_pid} died within 1s, retrying software fallback"
            wait "$rec_pid" 2>/dev/null || true
            codec_args=(-p preset=veryfast -p crf=23 -p tune=zerolatency -r 60)
            slog "start retry cmd: wf-recorder ${output_args[*]} ${geom_args[*]:-} ${audio_args[*]:-none} ${codec_args[*]} -f [${file}]"
            wf-recorder "${output_args[@]}" "${geom_args[@]}" "${audio_args[@]}" "${codec_args[@]}" -f "$file" &
            rec_pid=$!
            echo "$rec_pid" > "$pid_file"
            echo "$file" > "$file_name"
            echo "$monitor" > "$monitor_file"
            sleep 1
        fi
    fi
    if ! is_recorder_pid "$rec_pid"; then
        slog "start FAILED: wf-recorder pid=${rec_pid} died within 1s file=[${file}]"
        rm -f "$pid_file" "$file_name" "$monitor_file"
        echo "wf-recorder failed to start — see output above" >&2
        exit 1
    fi
    slog "start OK: pid=${rec_pid} hw=${used_hw} file=[${file}]"
    notify-send -a "Recorder" -i "media-record" "Recording Started" "$(basename "$file")"
}


stop() {
    drop_stale_pid

    if [[ ! -f "$pid_file" ]]; then
        # Try to find any running wf-recorder as a fallback
        if ! pgrep -x wf-recorder >/dev/null 2>&1; then
            echo "No active recording found" >&2
            exit 1
        fi
    fi

    files=()
    # read and kill each pid listed
    if [[ -f "$pid_file" ]]; then
        while IFS= read -r target; do
            if is_recorder_pid "$target"; then
                kill -INT "$target" 2>/dev/null || true
            fi
        done < "$pid_file"
    else
        # No pid file: kill any wf-recorder we can find (best-effort)
        for p in $(pgrep -x wf-recorder || true); do
            kill -INT "$p" 2>/dev/null || true
        done
    fi

    # Wait for processes to exit (max ~5s)
    for _ in $(seq 1 50); do
        if pgrep -x wf-recorder >/dev/null 2>&1; then
            sleep 0.1
        else
            break
        fi
    done
    # Force-kill any remaining wf-recorder
    for p in $(pgrep -x wf-recorder || true); do
        kill -KILL "$p" 2>/dev/null || true
    done
    sleep 0.2

    if [[ -f "$file_name" ]]; then
        while IFS= read -r f; do
            files+=("$f")
        done < "$file_name"
    fi

    rm -f "$pid_file" "$file_name" "$monitor_file"

    if [[ ${#files[@]} -gt 0 ]]; then
        (for f in "${files[@]}"; do echo "file://$f"; done) | wl-copy --type text/uri-list 2>/dev/null || true
        notify-send -a "Recorder" -i "media-record" "Recording Stopped" "Saved ${#files[@]} file(s)"
    else
        notify-send -a "Recorder" -i "media-record" "Recording Stopped" "Files copied to clipboard"
    fi
}

case "$1" in
    start) shift; start "$@" ;;
    toggle)
        # Keybind convenience: stop when a recorder is up, else start with
        # the remaining args. Runs the script directly from Hyprland — no
        # quickshell dependency (the bar island mirrors state via pgrep).
        shift
        drop_stale_pid
        if [[ -f "$pid_file" ]]; then
            stop
        else
            start "$@"
        fi
        ;;
    stop) stop ;;
    *) echo "Usage: $0 start [--area] [--monitor NAME] [--all] | stop | toggle"; exit 1 ;;
esac
