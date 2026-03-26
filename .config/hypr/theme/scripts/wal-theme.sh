#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly THEME_SCRIPT="${HYPR_DIR}/theme/scripts/system-theme.sh"
readonly THEME_CONF_FILE="${HYPR_DIR}/theme/theme.conf"
readonly CURRENT_WALLPAPER_FILE="${HYPR_DIR}/wallpaper-daemon/config/current.conf"
tmp_img=""

is_theme_enabled() {
    local conf_value
    
    if [[ ! -f "$THEME_CONF_FILE" ]]; then
        return 0
    fi
    
    conf_value="$(<"$THEME_CONF_FILE")"
    conf_value="${conf_value//[[:space:]]/}"
    conf_value="${conf_value,,}"
    
    [[ "$conf_value" != "false" ]]
}

if ! is_theme_enabled; then
    echo "Theme switching disabled in ${THEME_CONF_FILE}"
    exit 0
fi

# Get current theme from system
current_theme="$("${THEME_SCRIPT}" get)"

# Get wallpaper path (from argument or config file)
if [[ -n "${1:-}" ]]; then
    wallpaper="$1"
    elif [[ -f "${CURRENT_WALLPAPER_FILE}" ]]; then
    wallpaper="$(cat "${CURRENT_WALLPAPER_FILE}")"
else
    echo "Error: No wallpaper specified and current.conf not found" >&2
    exit 1
fi

# Expand $HOME variable if present
wallpaper="${wallpaper/\$HOME/${HOME}}"

# check if wallpaper is an animation/video (mp4, gif, etc.)
if [[ "${wallpaper,,}" =~ \.(mp4|gif|webm|mkv|avi|flv|mpeg|mp3|ogg|wav)$ ]]; then
    echo "Detected animated wallpaper: ${wallpaper}"
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Error: ffmpeg is required to extract a frame from animated wallpapers" >&2
        exit 1
    fi
    
    tmp_img="$(mktemp --suffix=.jpg)"
    trap '[[ -n "${tmp_img}" && -f "${tmp_img}" ]] && rm -f "${tmp_img}"' EXIT
    
    # Extract a representative frame for pywal color generation.
    if ! ffmpeg -y -ss 00:00:01 -i "$wallpaper" -frames:v 1 -q:v 2 "$tmp_img" >/dev/null 2>&1; then
        echo "Error: Failed to extract frame from animated wallpaper: ${wallpaper}" >&2
        exit 1
    fi
    
    wallpaper="$tmp_img"
fi

# Validate wallpaper file exists
if [[ ! -f "${wallpaper}" ]]; then
    echo "Error: Wallpaper file not found: ${wallpaper}" >&2
    exit 1
fi

# Kill existing wal process if running
killall -q wal 2>/dev/null || true

# Generate color scheme based on theme
wal_args=(--backend colorthief -e -n -i "${wallpaper}")
[[ "${current_theme}" == "light" ]] && wal_args+=(-l)

if wal "${wal_args[@]}" >/dev/null 2>&1; then
    echo "Color scheme generated for ${current_theme} theme"
else
    echo "Error: Failed to generate color scheme" >&2
    exit 1
fi

# Update pywalfox if available
# command -v pywalfox &>/dev/null && pywalfox update 2>/dev/null || true
