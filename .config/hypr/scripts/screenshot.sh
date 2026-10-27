#!/usr/bin/env bash
set -euo pipefail

# Usage: screenshot.sh (--now|--area) [--monitor NAME] [output.png|output.jpg]
#        screenshot.sh --now --all [output-prefix.png|output-prefix.jpg]
# SCREENSHOT_OPTIMIZE=1|0 overrides the saved PNG optimization preference.
settings_file="$HOME/.cache/quickshell/settings/settings.json"

read_setting() {
    local key="$1" fallback="$2" value
    value=$(jq -r --arg key "$key" --arg fallback "$fallback" \
        'if .screenshot[$key] == null then $fallback else .screenshot[$key] end' \
        "$settings_file" 2>/dev/null) || value="$fallback"
    [[ -n "$value" && "$value" != "null" ]] || value="$fallback"
    printf '%s' "$value"
}

load_settings() {
    local home_dir="$HOME"
    screenshot_dir=$(read_setting directory "$HOME/Pictures/Screenshots")
    image_format=$(read_setting format png)
    jpeg_quality=$(read_setting jpegQuality 85)
    png_compression=$(read_setting pngCompression 6)
    optimize_png=$(read_setting optimizePng false)
    copy_to_clipboard=$(read_setting copyToClipboard true)
    notify_on_save=$(read_setting notifyOnSave true)
    freeze_on_area=$(read_setting freezeOnArea true)
    include_cursor=$(read_setting includeCursor false)

    case "$screenshot_dir" in
        "~") screenshot_dir="$home_dir" ;;
        "~/"*) screenshot_dir="$home_dir/${screenshot_dir#~/}" ;;
    esac
    [[ -n "$screenshot_dir" ]] || screenshot_dir="$HOME/Pictures/Screenshots"
    case "$image_format" in png|jpeg) ;; *) image_format=png ;; esac
    if [[ "$jpeg_quality" =~ ^[0-9]{1,3}$ ]]; then
        jpeg_quality=$((10#$jpeg_quality))
        ((jpeg_quality <= 100)) || jpeg_quality=85
    else
        jpeg_quality=85
    fi
    if [[ "$png_compression" =~ ^[0-9]{1,2}$ ]]; then
        png_compression=$((10#$png_compression))
        ((png_compression <= 9)) || png_compression=6
    else
        png_compression=6
    fi
    case "$optimize_png" in true|false) ;; *) optimize_png=false ;; esac
    case "$copy_to_clipboard" in true|false) ;; *) copy_to_clipboard=true ;; esac
    case "$notify_on_save" in true|false) ;; *) notify_on_save=true ;; esac
    case "$freeze_on_area" in true|false) ;; *) freeze_on_area=true ;; esac
    case "$include_cursor" in true|false) ;; *) include_cursor=false ;; esac

    case "${SCREENSHOT_OPTIMIZE:-}" in
        1) optimize_png=true ;;
        0) optimize_png=false ;;
    esac

    screenshot_fullscreen_dir="$screenshot_dir/fullscreen"
    screenshot_area_dir="$screenshot_dir/area"

    capture_args=(-t "$image_format")
    if [[ "$image_format" == jpeg ]]; then
        image_extension=jpg
        image_mime_type=image/jpeg
        capture_args+=(-q "$jpeg_quality")
    else
        image_extension=png
        image_mime_type=image/png
        capture_args+=(-l "$png_compression")
    fi
    [[ "$include_cursor" == true ]] && capture_args+=(-c)
    return 0
}

notify_saved() {
    [[ "$notify_on_save" == true ]] || return 0
    local title="$1" body="$2" icon="${3:-}"
    if [[ -n "$icon" && -f "$icon" ]]; then
        notify-send -a "Screenshot" -i "$icon" "$title" "$body" 2>/dev/null || true
    else
        notify-send -a "Screenshot" "$title" "$body" 2>/dev/null || true
    fi
}

optimize_png_file() {
    local image="$1" image_base temp_image
    command -v magick >/dev/null 2>&1 || return 0
    image_base="${image%.*}"
    temp_image=$(mktemp "${image_base}.opt.XXXXXX.png") || return 0
    if magick "$image" -strip -define "png:compression-level=$png_compression" "$temp_image" \
        && mv -f -- "$temp_image" "$image"; then
        return 0
    fi
    rm -f -- "$temp_image"
    return 0
}

copy_saved_files() {
    [[ "$copy_to_clipboard" == true ]] || return 0
    command -v wl-copy >/dev/null 2>&1 || return 0
    if [[ "$all" -eq 1 ]]; then
        if (for image in "${files[@]}"; do printf 'file://%s\n' "$image"; done) \
            | wl-copy --type text/uri-list 2>/dev/null; then
            clipboard_copied=true
        fi
    else
        if wl-copy --type "$image_mime_type" < "${files[0]}" 2>/dev/null; then
            clipboard_copied=true
        fi
    fi
}

mode=""
monitor=""
custom_out=""
all=0
while (($#)); do
    case "$1" in
        --now|--area)
            if [[ -n "$mode" && "$mode" != "$1" ]]; then
                echo "Choose either --now or --area" >&2
                exit 2
            fi
            mode="$1"
            shift
            ;;
        --monitor)
            if (($# < 2)); then
                echo "--monitor requires a monitor name" >&2
                exit 2
            fi
            monitor="$2"
            shift 2
            ;;
        --all)
            all=1
            shift
            ;;
        --)
            shift
            if (($# > 1)); then
                echo "Only one output path is allowed" >&2
                exit 2
            fi
            custom_out="${1:-}"
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
        *)
            if [[ -n "$custom_out" ]]; then
                echo "Only one output path is allowed" >&2
                exit 2
            fi
            custom_out="$1"
            shift
            ;;
    esac
done

if [[ "$all" -eq 1 && "$mode" == "--area" ]]; then
    echo "--area and --all cannot be combined" >&2
    exit 2
fi
if [[ "$all" -eq 1 && -z "$mode" ]]; then
    mode="--now"
fi
if [[ -z "$mode" ]]; then
    echo "Usage: $0 (--now|--area) [--monitor NAME] [output.png] | --now --all [output-prefix.png]" >&2
    exit 2
fi
load_settings

if [[ -n "$custom_out" ]]; then
    case "$image_format:${custom_out,,}" in
        png:*.png|jpeg:*.jpg|jpeg:*.jpeg) ;;
        *) echo "Output path extension must match the selected screenshot format ($image_format)" >&2; exit 2 ;;
    esac
fi

if [[ "$all" -eq 0 && -z "$monitor" ]]; then
    monitor=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null) || monitor=""
fi
if [[ "$all" -eq 0 && -z "$monitor" ]]; then
    echo "Could not determine the focused monitor" >&2
    exit 1
fi
if ! command -v grim >/dev/null 2>&1; then
    echo "grim is not installed" >&2
    exit 127
fi

mkdir -p -- "$screenshot_fullscreen_dir" "$screenshot_area_dir"
if [[ -n "$custom_out" ]]; then
    custom_dir=$(dirname -- "$custom_out")
    mkdir -p -- "$custom_dir"
fi

timestamp=$(date +%Y%m%d_%H%M%S)
files=()
failed_captures=0
clipboard_copied=false

if [[ "$all" -eq 1 ]]; then
    mapfile -t monitors < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
    if ((${#monitors[@]} == 0)); then
        echo "No monitors found" >&2
        exit 1
    fi

    for current_monitor in "${monitors[@]}"; do
        [[ -n "$current_monitor" ]] || continue
        safe_monitor=$(printf '%s' "$current_monitor" | sed 's/[^[:alnum:]_.-]/_/g')
        if [[ -n "$custom_out" ]]; then
            output_prefix="${custom_out%.*}"
            image="${output_prefix}_${safe_monitor}.${image_extension}"
        else
            image="$screenshot_fullscreen_dir/screenshot_${safe_monitor}_${timestamp}.${image_extension}"
        fi
        if grim "${capture_args[@]}" -o "$current_monitor" "$image"; then
            files+=("$image")
        else
            printf 'Failed to capture monitor %s\n' "$current_monitor" >&2
            failed_captures=$((failed_captures + 1))
        fi
    done
elif [[ "$mode" == "--now" ]]; then
    image="${custom_out:-$screenshot_fullscreen_dir/screenshot_${timestamp}.${image_extension}}"
    if ! grim "${capture_args[@]}" -o "$monitor" "$image"; then
        echo "Failed to capture monitor $monitor" >&2
        exit 1
    fi
    files+=("$image")
else
    if ! command -v slurp >/dev/null 2>&1; then
        echo "slurp is not installed" >&2
        exit 127
    fi
    monitor_info=$(hyprctl monitors -j 2>/dev/null | jq -c --arg name "$monitor" '.[] | select(.name == $name)' 2>/dev/null) || monitor_info=""
    if [[ -z "$monitor_info" ]]; then
        printf "Monitor '%s' is unavailable\n" "$monitor" >&2
        exit 1
    fi

    image="${custom_out:-$screenshot_area_dir/screenshot_area_${timestamp}.${image_extension}}"
    area_lock_fd=""
    freeze_pid=""
    cleanup_area_capture() {
        if [[ -n "$freeze_pid" ]]; then
            kill "$freeze_pid" 2>/dev/null || true
            wait "$freeze_pid" 2>/dev/null || true
            freeze_pid=""
        fi
        if [[ -n "$area_lock_fd" ]]; then
            flock -u "$area_lock_fd" 2>/dev/null || true
            exec {area_lock_fd}>&-
            area_lock_fd=""
        fi
    }

    exec {area_lock_fd}>/tmp/screenshot-area.lock
    if ! flock -n "$area_lock_fd"; then
        exec {area_lock_fd}>&-
        area_lock_fd=""
        exit 0
    fi
    trap cleanup_area_capture EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    hyprctl keyword layerrule "match:selection, no_anim on" >/dev/null 2>&1 || true
    if [[ "$freeze_on_area" == true ]] && command -v hyprpicker >/dev/null 2>&1; then
        hyprpicker -rz >/dev/null 2>&1 & freeze_pid=$!
        sleep 0.2
    fi
    if geometry=$(slurp -f '%x,%y %wx%h' </dev/null); then
        if ! grim "${capture_args[@]}" -g "$geometry" "$image"; then
            echo "Failed to capture selected area" >&2
            exit 1
        fi
    else
        # Escape cancellation is a silent no-op for the Quickshell caller.
        exit 1
    fi
    cleanup_area_capture
    trap - EXIT INT TERM
    files+=("$image")
fi

if ((${#files[@]} == 0)); then
    echo "No screenshots were captured" >&2
    exit 1
fi

if [[ "$optimize_png" == true && "$image_format" == png ]]; then
    for image in "${files[@]}"; do
        optimize_png_file "$image"
    done
fi

copy_saved_files
if [[ "$all" -eq 1 ]]; then
    notification_body="Saved ${#files[@]} screenshot(s)"
    [[ "$clipboard_copied" == true ]] && notification_body+="; file links copied to clipboard"
    if [[ "$failed_captures" -gt 0 ]]; then
        notification_body+="; $failed_captures monitor(s) failed"
    fi
    notify_saved "Screenshots saved" "$notification_body" "${files[0]}"
else
    notification_body="Saved screenshot"
    [[ "$clipboard_copied" == true ]] && notification_body+=" and copied it to clipboard"
    notify_saved "Screenshot saved" "$notification_body" "${files[0]}"
fi
