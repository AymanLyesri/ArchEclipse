#!/bin/bash

set -euo pipefail

readonly HYPR_DIR="${HOME}/.config/hypr"
readonly SCRIPTS_DIR="${HYPR_DIR}/theme/scripts"
readonly THEME_CONF_FILE="${HYPR_DIR}/theme/theme.conf"

# Theme switching is enabled by default unless theme.conf is explicitly set to false.
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

# Get current theme from system color scheme preference
get_current_theme() {
    local color_scheme
    color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
    
    # Default to dark if gsettings fails or returns empty
    if [[ -z "$color_scheme" ]]; then
        echo "dark"
        return
    fi
    
    # Parse the color scheme (format: 'prefer-dark' or 'prefer-light' or 'default')
    if [[ "$color_scheme" == *"light"* ]]; then
        echo "light"
    else
        echo "dark"
    fi
}

# Apply all theme components (cursor, wal, gtk, qt)
apply_theme_components() {
    # Apply all theme components in parallel for faster execution
    {
        "${SCRIPTS_DIR}/cursor-theme.sh" &
        "${SCRIPTS_DIR}/gtk-theme.sh" &
        "${SCRIPTS_DIR}/wal-theme.sh" &
        "${SCRIPTS_DIR}/qt-theme.sh" &
        wait
    } 2>/dev/null
    
    echo "All theme components applied successfully"
}

# Switch theme in system settings
switch_theme() {
    local target_theme="$1"
    local current_theme
    current_theme=$(get_current_theme)
    
    # If no theme specified, toggle current theme
    if [[ -z "$target_theme" ]]; then
        if [[ "$current_theme" == "dark" ]]; then
            target_theme="light"
        else
            target_theme="dark"
        fi
    fi
    
    # Validate theme
    if [[ "$target_theme" != "dark" && "$target_theme" != "light" ]]; then
        echo "Error: Invalid theme. Use 'dark' or 'light'" >&2
        return 1
    fi
    
    # Set the system color scheme
    if [[ "$target_theme" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    else
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    fi
    
    echo "Theme switched to: $target_theme"
    
    # Apply all theme components (cursor, wal, gtk, qt)
    apply_theme_components
    
    # Send notification if notify-send is available
    if command -v notify-send &>/dev/null; then
        sleep 1 && notify-send -u normal "Theme Changed" "Current theme: ${target_theme^}"
    fi
}

# Main script logic
main() {
    case "${1:-}" in
        get)
            get_current_theme
        ;;
        switch)
            if ! is_theme_enabled; then
                echo "Theme switching disabled in ${THEME_CONF_FILE}"
                exit 0
            fi
            switch_theme "${2:-}"
        ;;
        apply)
            if ! is_theme_enabled; then
                echo "Theme switching disabled in ${THEME_CONF_FILE}"
                exit 0
            fi
            apply_theme_components
        ;;
        *)
            echo "Usage: $0 {get|switch|apply} [dark|light]" >&2
            echo "  get          - Display current theme" >&2
            echo "  switch       - Toggle theme (dark <-> light)" >&2
            echo "  switch dark  - Switch to dark theme" >&2
            echo "  switch light - Switch to light theme" >&2
            echo "  apply        - Apply current theme components (cursor, wal, gtk, qt)" >&2
            exit 1
        ;;
    esac
}

main "$@"
