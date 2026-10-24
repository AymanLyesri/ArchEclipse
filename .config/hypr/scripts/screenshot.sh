#!/usr/bin/env bash
set -euo pipefail

# Usage: screenshot.sh (--now|--area) [--monitor NAME] [output.png]
#   The monitor defaults to the focused Hyprland monitor.
#   An optional output path overrides the destination (must end in .png).
#   Set SCREENSHOT_OPTIMIZE=1 to run the (slow) ImageMagick strip/recompress.
timestamp=$(date +%Y%m%d_%H%M%S)
screenshot_dir="$HOME/Pictures/Screenshots"
screenshot_fullscreen_dir="$screenshot_dir/fullscreen"
screenshot_area_dir="$screenshot_dir/area"

# create screenshot directory if it doesn't exist
mkdir -p "$screenshot_dir"
mkdir -p "$screenshot_fullscreen_dir"
mkdir -p "$screenshot_area_dir"

mode=""
monitor=""
custom_out=""
all=0
while (($#)); do
    case "$1" in
        --now|--area)
            mode="$1"
            shift
            ;;
        --monitor)
            monitor="${2:-}"
            shift 2
            ;;
        --all)
            all=1
            shift
            ;;
        --)
            shift
            custom_out="${1:-}"
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            custom_out="$1"
            shift
            ;;
    esac
done

if [[ -z "$monitor" && "$all" -eq 0 ]]; then
    monitor="$(hyprctl activeworkspace -j | jq -r '.monitor')"
fi
if [[ "$all" -eq 0 && ( -z "$monitor" || "$monitor" == "null" ) ]]; then
    echo "Could not determine the focused monitor" >&2
    exit 1
fi

if [[ "$all" -eq 1 ]]; then
    # Capture each monitor separately
    files=()
    for m in $(hyprctl monitors -j | jq -r '.[].name'); do
        safe_m=$(echo "$m" | tr '/ ' '__')
        img="${custom_out:-$screenshot_fullscreen_dir/screenshot_${safe_m}_$timestamp.png}"
        grim -o "$m" "$img" || {
            echo "Failed to capture monitor $m" >&2
            continue
        }
        files+=("$img")
    done
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No monitors captured" >&2
        exit 1
    fi
    # Copy file URIs to clipboard and notify
    (for f in "${files[@]}"; do echo "file://$f"; done) | wl-copy --type text/uri-list || true
    notify-send -a "Screenshot" -i "${files[0]}" "Screenshots saved" "Saved ${#files[@]} screenshots"
    exit 0

elif [[ "$mode" == "--now" ]]; then
    img="${custom_out:-$screenshot_fullscreen_dir/screenshot_$timestamp.png}"
    # One focused output (PNG: Qt/Quickshell has no webp plugin, so PNG is
    # required for the notification preview and a correct image/png paste).
    grim -o "$monitor" "$img" || exit 1

elif [[ "$mode" == "--area" ]]; then
    img="${custom_out:-$screenshot_area_dir/screenshot_area_$timestamp.png}"
    monitor_info="$(hyprctl monitors -j | jq -c --arg name "$monitor" '.[] | select(.name == $name)')"
    if [[ -z "$monitor_info" ]]; then
        echo "Monitor '$monitor' is unavailable" >&2
        exit 1
    fi
    # Free-form region: plain slurp drag over any area (compositor-global
    # coordinates), so it works even with no visible windows. Previously a
    # window-picker over the visible windows of the active workspace.

    # Freeze while selecting. Escape cancels silently.
    exec {area_lock}>/tmp/screenshot-area.lock
    if ! flock -n "$area_lock"; then
        exec {area_lock}>&-
        exit 0
    fi
    freeze_pid=""
    cleanup_area_capture() {
        if [[ -n "${freeze_pid:-}" ]]; then
            kill "$freeze_pid" 2>/dev/null || true
            wait "$freeze_pid" 2>/dev/null || true
            freeze_pid=""
        fi
        if [[ -n "${area_lock:-}" ]]; then
            # Release before wl-copy: its clipboard owner can outlive this
            # script, so it must not inherit a held screenshot lock.
            flock -u "$area_lock" 2>/dev/null || true
            exec {area_lock}>&-
            area_lock=""
        fi
    }
    trap cleanup_area_capture EXIT
    if command -v hyprpicker >/dev/null 2>&1; then
        hyprpicker -rz & freeze_pid=$!
        sleep 0.2
    fi
    hyprctl keyword layerrule "match:selection, no_anim on" >/dev/null 2>&1 || true
    # slurp switches to "read predefined rectangles from stdin" whenever
    # stdin is not a TTY, and waits forever on a pipe that never closes
    # (measured: spawned from a Quickshell Process the selection never
    # appeared until the shell died and the pipe hit EOF). /dev/null gives
    # it an immediate EOF so it stays interactive.
    geometry="$(slurp -f '%x,%y %wx%h' </dev/null)" || exit 1
    grim -g "$geometry" "$img" || exit 1
    cleanup_area_capture
    trap - EXIT

else
    echo "Available Options : --now --area" >&2
    exit 1
fi

# Optional PNG optimize (off by default: magick recompress dominates
# screenshot latency; grim output is already fine for most uses)
if [[ "${SCREENSHOT_OPTIMIZE:-0}" == "1" ]]; then
    if command -v magick >/dev/null 2>&1; then
        magick "$img" -strip -define png:compression-level=6 "$img"
    fi
fi

# Send image to clipboard (bytes must match the declared MIME type)
wl-copy --type image/png < "$img"

# Notify user (quoted icon path so it arrives as a loadable file URL)
notify-send -a "Screenshot" -i "$img" "Screenshot saved" "Saved and copied to clipboard"
