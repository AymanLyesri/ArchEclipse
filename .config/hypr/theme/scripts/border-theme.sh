#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly WAL_CSS="${HOME}/.cache/wal/colors.css"
readonly BORDER_CONF="${HYPR_DIR}/configs/custom/border.conf"
# readonly SHADOW_CONF="${HYPR_DIR}/configs/custom/shadow.conf"

# Validate CSS file exists
if [[ ! -f "${WAL_CSS}" ]]; then
    echo "Error: Wal colors.css not found. Run wal first." >&2
    exit 1
fi

# Extract hex color codes from CSS file
mapfile -t colors < <(grep -o '#[0-9A-Fa-f]\{6\}' "${WAL_CSS}" | sed 's/^#//')

# Validate we have enough colors
if [[ ${#colors[@]} -lt 7 ]]; then
    echo "Error: Not enough colors extracted from CSS file" >&2
    exit 1
fi

# Create gradient border color string
readonly BORDER_GRADIENT="rgb(${colors[6]}) rgb(${colors[4]}) rgb(${colors[5]}) rgb(${colors[6]}) 270deg"

# Ensure config directory exists
mkdir -p "$(dirname "${BORDER_CONF}")"

# Write border configuration
cat > "${BORDER_CONF}" <<EOF
general {
	col.active_border = ${BORDER_GRADIENT}
}
EOF

# Optional: Shadow configuration
# cat > "${SHADOW_CONF}" <<EOF
# decoration {
# 	col.shadow = rgb(${colors[5]})
# }
# EOF

echo "Border theme updated with pywal colors"
