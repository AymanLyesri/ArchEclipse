#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly SCRIPTS_DIR="${HYPR_DIR}/theme/scripts"
readonly THEME_SCRIPT="${HYPR_DIR}/theme/scripts/system-theme.sh"
readonly THEME_CONF_FILE="${HYPR_DIR}/theme/theme.conf"
readonly THEME_CONFIG_SCRIPT="${HYPR_DIR}/theme/scripts/theme-config.sh"
readonly CURRENT_WALLPAPER_FILE="${HYPR_DIR}/wallpaper-daemon/config/current.conf"
tmp_img=""

source "${THEME_CONFIG_SCRIPT}"

is_autocolor_enabled() {
    [[ "$(get_theme_bool "autocolor" "true")" == "true" ]]
}

is_autovariant_enabled() {
    [[ "$(get_theme_bool "autovariant" "true")" == "true" ]]
}

if ! is_autocolor_enabled; then
    echo "Auto color generation disabled in ${THEME_CONF_FILE} (autocolor=false)"
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

# Choose target theme based on wallpaper brightness when autovariant is enabled.
target_theme="$current_theme"
if is_autovariant_enabled; then
    target_theme="$(detect_variant_from_wallpaper "${wallpaper}")"
    echo "Detected wallpaper variant: ${target_theme}"
fi

# Kill existing wal process if running
killall -q wal 2>/dev/null || true

# Generate color scheme based on theme
wal_args=(--backend colorthief -e -n -i "${wallpaper}")
[[ "${target_theme}" == "light" ]] && wal_args+=(-l)

if wal "${wal_args[@]}" >/dev/null 2>&1; then
    echo "Color scheme generated for ${target_theme} theme"
else
    echo "Error: Failed to generate color scheme" >&2
    exit 1
fi

# Apply variant if changed without re-invoking wal-theme recursively.
if [[ "${target_theme}" != "${current_theme}" ]]; then
    echo "Auto-switching theme from ${current_theme} to ${target_theme}"
    if [[ "${target_theme}" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    else
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    fi
    "${SCRIPTS_DIR}/cursor-theme.sh" || true
    "${SCRIPTS_DIR}/gtk-theme.sh" || true
    "${SCRIPTS_DIR}/qt-theme.sh" || true
fi

# Update pywalfox if available
# command -v pywalfox &>/dev/null && pywalfox update 2>/dev/null || true
