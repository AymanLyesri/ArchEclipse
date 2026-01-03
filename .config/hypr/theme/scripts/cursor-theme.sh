#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly THEME_SCRIPT="${HYPR_DIR}/theme/scripts/system-theme.sh"
readonly CURSOR_CONF="${HYPR_DIR}/configs/cursor.conf"
readonly CURSOR_SIZE=24

# Get current theme from system
current_theme="$("${THEME_SCRIPT}" get)"

readonly CURSOR_THEME="phinger-cursors-${current_theme}"
readonly HYPR_CURSOR_THEME="theme_${CURSOR_THEME}"

# Set cursor theme via hyprctl
if command -v hyprctl &>/dev/null; then
    hyprctl setcursor "${HYPR_CURSOR_THEME}" "${CURSOR_SIZE}" 2>/dev/null || true
fi

# Set cursor theme via gsettings
gsettings set org.gnome.desktop.interface cursor-theme "${CURSOR_THEME}" 2>/dev/null || true

# Write cursor config file
cat > "${CURSOR_CONF}" <<EOF
env = HYPRCURSOR_THEME,${HYPR_CURSOR_THEME}
env = XCURSOR_THEME,${CURSOR_THEME}
EOF

echo "Cursor theme set to ${CURSOR_THEME}"
