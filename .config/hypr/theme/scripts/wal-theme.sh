#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly THEME_SCRIPT="${HYPR_DIR}/theme/scripts/system-theme.sh"
readonly CURRENT_WALLPAPER_FILE="${HYPR_DIR}/hyprpaper/config/current.conf"

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
