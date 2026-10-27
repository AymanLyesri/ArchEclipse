#!/usr/bin/env bash
set -euo pipefail

screenrecord_config_dir="$HOME/.cache/quickshell/settings"
settings_file="$screenrecord_config_dir/settings.json"
screenrecord_dir="$HOME/Videos/ScreenRecords"
screenrecord_fullscreen_dir="$screenrecord_dir/fullscreen"
screenrecord_area_dir="$screenrecord_dir/area"
pid_file="/tmp/screenrecord.pid"
file_name="/tmp/screenrecord_name"
monitor_file="/tmp/screenrecord_monitor"
log_file="/tmp/screenrecord.log"

slog() {
    echo "$(date +%Y%m%d_%H%M%S) [$$] $*" >> "$log_file" 2>/dev/null || true
}

read_setting() {
    local key="$1" fallback="$2" value
    value=$(jq -r --arg key "$key" --arg fallback "$fallback" \
        'if .recording[$key] == null then $fallback else .recording[$key] end' \
        "$settings_file" 2>/dev/null) || value="$fallback"
    [[ -n "$value" ]] || value="$fallback"
    printf '%s' "$value"
}

load_settings() {
    local home_dir="$HOME"
    video_codec=$(read_setting videoCodec auto)
    video_quality=$(read_setting quality very_high)
    color_range=$(read_setting colorRange limited)
    audio_codec=$(read_setting audioCodec opus)
    frame_rate=$(read_setting frameRate 60)
    frame_rate_mode=$(read_setting frameRateMode auto)
    record_cursor=$(read_setting recordCursor true)
    output_device=$(read_setting outputDevice default_output)
    input_device=$(read_setting inputDevice none)
    container=$(read_setting container mp4)
    screenrecord_dir=$(read_setting directory "$HOME/Videos/ScreenRecords")

    case "$screenrecord_dir" in
        "~") screenrecord_dir="$home_dir" ;;
        "~/"*) screenrecord_dir="$home_dir/${screenrecord_dir#~/}" ;;
    esac
    [[ -n "$screenrecord_dir" ]] || screenrecord_dir="$HOME/Videos/ScreenRecords"

    case "$video_codec" in
        auto|h264|hevc|av1|vp8|vp9|hevc_hdr|av1_hdr|hevc_10bit|av1_10bit|h264_vulkan|hevc_vulkan|hevc_hdr_vulkan|hevc_10bit_vulkan|av1_vulkan|av1_hdr_vulkan|av1_10bit_vulkan) ;;
        *) video_codec=auto ;;
    esac
    case "$video_quality" in medium|high|very_high|ultra) ;; *) video_quality=very_high ;; esac
    case "$color_range" in limited|full) ;; *) color_range=limited ;; esac
    case "$audio_codec" in aac|opus|mp3) ;; *) audio_codec=opus ;; esac
    case "$frame_rate_mode" in auto|cfr|vfr|content) ;; *) frame_rate_mode=auto ;; esac
    case "$record_cursor" in true|false) ;; *) record_cursor=true ;; esac
    case "$container" in
        mp4|mkv|mov|webm|flv) ;;
        mp3|ts|m3u8|whip) ;;
        *) container=mp4 ;;
    esac
    [[ "$frame_rate" =~ ^[0-9]{1,3}$ ]] && ((frame_rate >= 1 && frame_rate <= 360)) || frame_rate=60
    [[ -n "$output_device" ]] || output_device=default_output
    [[ -n "$input_device" ]] || input_device=none

    screenrecord_fullscreen_dir="$screenrecord_dir/fullscreen"
    screenrecord_area_dir="$screenrecord_dir/area"
}

is_recorder_pid() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    [[ -r "/proc/$1/cmdline" ]] || return 1
    local executable=""
    IFS= read -r -d '' executable < "/proc/$1/cmdline" || true
    [[ "${executable##*/}" == "gpu-screen-recorder" ]]
}

recorder_pids() {
    pgrep -f '(^|/)gpu-screen-recorder([[:space:]]|$)' 2>/dev/null || true
}

drop_stale_pid() {
    if [[ -f "$pid_file" ]]; then
        local alive=0 p
        while IFS= read -r p; do
            if is_recorder_pid "$p"; then
                alive=1
                break
            fi
        done < "$pid_file"
        if [[ $alive -eq 0 ]]; then
            rm -f "$pid_file" "$file_name" "$monitor_file"
        fi
    fi
}

notify() {
    notify-send -a "Recorder" -i "media-record" "$1" "$2" 2>/dev/null || true
}

start() {
    local area=0 monitor="" all=0
    while (($#)); do
        case "$1" in
            --area) area=1; shift ;;
            --monitor)
                if (($# < 2)); then
                    echo "--monitor requires a monitor name" >&2
                    exit 2
                fi
                monitor="$2"
                shift 2
                ;;
            --all) all=1; shift ;;
            *) echo "Unknown start option: $1" >&2; exit 2 ;;
        esac
    done

    if [[ "$area" -eq 1 && "$all" -eq 1 ]]; then
        echo "--area and --all cannot be combined" >&2
        exit 2
    fi
    if [[ "$all" -eq 0 && -z "$monitor" ]]; then
        monitor=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null) || monitor=""
    fi
    if [[ "$all" -eq 0 && -z "$monitor" ]]; then
        echo "Could not determine the focused monitor" >&2
        exit 1
    fi

    load_settings
    local compatibility_error=""
    case "$container" in
        mp4|mkv|mov|webm|flv)
            case "$container:$video_codec" in
                webm:vp8|webm:vp9|webm:av1|webm:av1_hdr|webm:av1_10bit|webm:av1_vulkan|webm:av1_hdr_vulkan|webm:av1_10bit_vulkan) ;;
                webm:*)
                    compatibility_error="WEBM requires VP8, VP9, or AV1; the selected codec '$video_codec' is incompatible. Choose MP4/MKV or an available compatible codec."
                    ;;
                flv:auto|flv:h264|flv:h264_vulkan) ;;
                flv:*)
                    compatibility_error="FLV requires H.264; the selected codec '$video_codec' is incompatible. Choose MP4/MKV or H.264."
                    ;;
            esac
            ;;
        *)
            compatibility_error="'$container' is not a supported video container for this GPU Screen Recorder version. Choose MP4, MKV, MOV, WebM, or FLV."
            ;;
    esac
    if [[ -n "$compatibility_error" ]]; then
        slog "start rejected: $compatibility_error"
        notify "Recording Error" "$compatibility_error"
        echo "$compatibility_error" >&2
        exit 1
    fi
    if [[ "$frame_rate_mode" == "content" && ( -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == "wayland" ) ]]; then
        echo "Sync to content requires X11 or portal capture; this script uses direct Wayland capture" >&2
        exit 1
    fi
    mkdir -p -- "$screenrecord_fullscreen_dir" "$screenrecord_area_dir"
    slog "start monitor=[$monitor] area=[$area] all=[$all] wayland=${WAYLAND_DISPLAY:-UNSET} hypr=${HYPRLAND_INSTANCE_SIGNATURE:-UNSET}"
    drop_stale_pid
    if [[ -f "$pid_file" ]]; then
        slog "start abort: already recording pid=$(tr '\n' ' ' < "$pid_file")"
        echo "Already recording (pid $(tr '\n' ' ' < "$pid_file"))" >&2
        exit 1
    fi
    if ! command -v gpu-screen-recorder >/dev/null 2>&1; then
        echo "gpu-screen-recorder is not installed" >&2
        exit 127
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    local geometry=""
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

        slog "area: opening free-form selection on monitor=[$monitor]"
        hyprctl keyword layerrule "match:selection, no_anim on" >/dev/null 2>&1 || true
        local freeze_pid="" selection="" selection_status=0
        if command -v hyprpicker >/dev/null 2>&1; then
            hyprpicker -rz >/dev/null 2>&1 & freeze_pid=$!
            sleep 0.2
        fi
        if selection=$(slurp -f '%wx%h+%x+%y' </dev/null 2>>"$log_file"); then
            geometry="$selection"
        else
            selection_status=$?
            if [[ -n "$freeze_pid" ]]; then
                kill "$freeze_pid" 2>/dev/null || true
                wait "$freeze_pid" 2>/dev/null || true
            fi
            exec {area_lock}>&-
            slog "area: slurp exited code=${selection_status} (cancel or crash)"
            exit 1
        fi
        if [[ -n "$freeze_pid" ]]; then
            kill "$freeze_pid" 2>/dev/null || true
            wait "$freeze_pid" 2>/dev/null || true
        fi
        slog "area: selected region geometry=[$geometry]"
        exec {area_lock}>&-
    fi

    local -a recorder_options audio_options monitors pids files monitor_names
    recorder_options=(-c "$container" -k "$video_codec" -q "$video_quality" -cr "$color_range" \
        -ac "$audio_codec" -f "$frame_rate" \
        -cursor "$([[ "$record_cursor" == "true" ]] && echo yes || echo no)")
    [[ "$frame_rate_mode" == "auto" ]] || recorder_options+=(-fm "$frame_rate_mode")
    audio_options=()
    audio_source=""
    if [[ "$output_device" != "none" ]]; then
        audio_source="$output_device"
    fi
    if [[ "$input_device" != "none" ]]; then
        if [[ -n "$audio_source" ]]; then
            audio_source+="|$input_device"
        else
            audio_source="$input_device"
        fi
    fi
    [[ -z "$audio_source" ]] || audio_options+=(-a "$audio_source")
    pids=()
    files=()
    monitor_names=()

    launch_one() {
        local capture="$1" target_monitor="$2" output_file="$3" rec_pid
        local -a capture_options=() command
        [[ -z "${4:-}" ]] || capture_options=(-region "$4")
        command=(gpu-screen-recorder -w "$capture" "${capture_options[@]}" "${recorder_options[@]}" "${audio_options[@]}" -o "$output_file")
        local command_log
        printf -v command_log '%q ' "${command[@]}"
        slog "start cmd: ${command_log}[${output_file}]"
        "${command[@]}" &
        rec_pid=$!
        pids+=("$rec_pid")
        files+=("$output_file")
        monitor_names+=("$target_monitor")
    }

    if [[ "$area" -eq 1 ]]; then
        launch_one region "$monitor" "$screenrecord_area_dir/screenrecord_area_${timestamp}.${container}" "$geometry"
    elif [[ "$all" -eq 1 ]]; then
        mapfile -t monitors < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
        if ((${#monitors[@]} == 0)); then
            echo "No monitors found" >&2
            exit 1
        fi
        for monitor in "${monitors[@]}"; do
            [[ -n "$monitor" ]] || continue
            local safe_monitor
            safe_monitor=$(printf '%s' "$monitor" | sed 's/[^[:alnum:]_.-]/_/g')
            launch_one "$monitor" "$monitor" "$screenrecord_fullscreen_dir/screenrecord_${safe_monitor}_${timestamp}.${container}"
            sleep 0.15
        done
    else
        launch_one "$monitor" "$monitor" "$screenrecord_fullscreen_dir/screenrecord_${timestamp}.${container}"
    fi

    if ((${#pids[@]} == 0)); then
        echo "No recording process was started" >&2
        exit 1
    fi
    printf '%s\n' "${pids[@]}" > "$pid_file"
    printf '%s\n' "${files[@]}" > "$file_name"
    printf '%s\n' "${monitor_names[@]}" > "$monitor_file"

    sleep 1
    local failed=0 idx pid
    for idx in "${!pids[@]}"; do
        pid=${pids[$idx]}
        if ! is_recorder_pid "$pid"; then
            slog "start FAILED: gpu-screen-recorder pid=${pid} exited during startup file=[${files[$idx]}]"
            wait "$pid" 2>/dev/null || true
            failed=1
        fi
    done
    if [[ "$failed" -eq 1 ]]; then
        for pid in "${pids[@]}"; do
            is_recorder_pid "$pid" && kill -INT "$pid" 2>/dev/null || true
        done
        for _ in $(seq 1 50); do
            local active=0
            for pid in "${pids[@]}"; do
                if is_recorder_pid "$pid"; then
                    active=1
                    break
                fi
            done
            [[ "$active" -eq 1 ]] || break
            sleep 0.1
        done
        for pid in "${pids[@]}"; do
            is_recorder_pid "$pid" && kill -KILL "$pid" 2>/dev/null || true
        done
        sleep 0.2
        rm -f "$pid_file" "$file_name" "$monitor_file"
        rm -f -- "${files[@]}"
        echo "gpu-screen-recorder failed to start — see output above or $log_file" >&2
        exit 1
    fi

    slog "start OK: pids=$(tr '\n' ' ' < "$pid_file") files=$(tr '\n' ' ' < "$file_name")"
    if ((${#files[@]} == 1)); then
        notify "Recording Started" "$(basename "${files[0]}")"
    else
        notify "Recording Started" "${#files[@]} monitors"
    fi
}

stop() {
    drop_stale_pid
    local -a targets files
    targets=()
    files=()

    if [[ -f "$pid_file" ]]; then
        while IFS= read -r target; do
            is_recorder_pid "$target" && targets+=("$target")
        done < "$pid_file"
    else
        mapfile -t targets < <(recorder_pids)
        if ((${#targets[@]} == 0)); then
            echo "No active recording found" >&2
            exit 1
        fi
    fi

    for target in "${targets[@]}"; do
        kill -INT "$target" 2>/dev/null || true
    done

    for _ in $(seq 1 50); do
        local active=0
        for target in "${targets[@]}"; do
            if is_recorder_pid "$target"; then
                active=1
                break
            fi
        done
        [[ "$active" -eq 1 ]] || break
        sleep 0.1
    done
    for target in "${targets[@]}"; do
        is_recorder_pid "$target" && kill -KILL "$target" 2>/dev/null || true
    done
    sleep 0.2

    if [[ -f "$file_name" ]]; then
        while IFS= read -r file; do
            [[ -n "$file" ]] && files+=("$file")
        done < "$file_name"
    fi
    rm -f "$pid_file" "$file_name" "$monitor_file"

    if ((${#files[@]} > 0)); then
        if command -v wl-copy >/dev/null 2>&1; then
            (for file in "${files[@]}"; do printf 'file://%s\n' "$file"; done) | wl-copy --type text/uri-list 2>/dev/null || true
        fi
        notify "Recording Stopped" "Saved ${#files[@]} file(s)"
    else
        notify "Recording Stopped" "Recording stopped"
    fi
}

case "${1:-}" in
    start) shift; start "$@" ;;
    toggle)
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
