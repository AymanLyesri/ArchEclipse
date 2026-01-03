#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly THEME_SCRIPT="${HYPR_DIR}/theme/scripts/system-theme.sh"

# Get current theme from system
current_theme="$("${THEME_SCRIPT}" get)"

# Capitalize first letter for theme name
theme_name="WhiteSur-${current_theme^}"

# Set Qt theme using kvantum
if command -v kvantummanager &>/dev/null; then
    # Set Kvantum theme
    if kvantummanager --set "${theme_name}" 2>/dev/null; then
        echo "Kvantum Qt theme set to ${theme_name}"
    else
        echo "Warning: Failed to set Kvantum theme" >&2
    fi
fi

# Set Qt style via qt5ct/qt6ct settings
if command -v qt5ct &>/dev/null || command -v qt6ct &>/dev/null; then
    # Set QT_QPA_PLATFORMTHEME environment variable
    export QT_QPA_PLATFORMTHEME=qt5ct
    echo "Qt platform theme set to qt5ct"
fi

# Set Qt color scheme via gsettings (for Qt apps that respect it)
if [[ "$current_theme" == "light" ]]; then
    gsettings set org.kde.kdeglobals.General ColorScheme 'WhiteSurLight' 2>/dev/null || true
else
    gsettings set org.kde.kdeglobals.General ColorScheme 'WhiteSurDark' 2>/dev/null || true
fi

echo "Qt theme set to ${theme_name}"
