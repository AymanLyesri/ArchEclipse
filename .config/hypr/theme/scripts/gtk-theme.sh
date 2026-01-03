#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly THEME_SCRIPT="${HYPR_DIR}/theme/scripts/system-theme.sh"

# Get current theme from system
current_theme="$("${THEME_SCRIPT}" get)"

# Capitalize first letter for theme name
theme_name="WhiteSur-${current_theme^}"

# Set GTK theme
if gsettings set org.gnome.desktop.interface gtk-theme "${theme_name}" 2>/dev/null; then
    echo "GTK theme set to ${theme_name}"
else
    echo "Error: Failed to set GTK theme" >&2
    exit 1
fi
