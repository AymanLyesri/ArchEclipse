#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly THEME_SCRIPT="${HYPR_DIR}/theme/scripts/system-theme.sh"

# Get current theme from system
current_theme="$(${THEME_SCRIPT} get)"

# Icon theme follows lowercase light/dark variants
icon_name="WhiteSur-${current_theme}"

# Set Icon theme
if gsettings set org.gnome.desktop.interface icon-theme "${icon_name}" 2>/dev/null; then
    echo "Icon theme set to ${icon_name}"
else
    echo "Error: Failed to set Icon theme" >&2
    exit 1
fi
