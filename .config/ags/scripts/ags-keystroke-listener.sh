#!/usr/bin/env bash

KEYBOARD_DEVICE=$(ls -1 /dev/input/by-id/*-event-kbd 2>/dev/null | head -n1)

if [[ -z "$KEYBOARD_DEVICE" ]]; then
    echo "No keyboard device found" >&2
    exit 1
fi

if [[ ! -r "$KEYBOARD_DEVICE" ]]; then
    echo "No permission to read keyboard device" >&2
    exit 1
fi

# Get layout from Hyprland and map to XKB layout/variant
HYPR_LAYOUT=$(hyprctl devices -j | jq -r '.keyboards[0].active_keymap' 2>/dev/null)

case "$HYPR_LAYOUT" in
    "English (Dvorak)")
        LAYOUT="us"
        VARIANT="dvorak"
        ;;
    "English (US)")
        LAYOUT="us"
        VARIANT=""
        ;;
    "English (UK)")
        LAYOUT="gb"
        VARIANT=""
        ;;
    "French")
        LAYOUT="fr"
        VARIANT=""
        ;;
    *)
        LAYOUT="us"
        VARIANT=""
        ;;
esac

# Build xkbcli command
XKB_CMD="xkbcli interactive-evdev --short --enable-compose --rules evdev --model pc105 --layout $LAYOUT"
[[ -n "$VARIANT" ]] && XKB_CMD="$XKB_CMD --variant $VARIANT"

stdbuf -oL -eL $XKB_CMD < "$KEYBOARD_DEVICE" 2>/dev/null | while read -r line; do
    if [[ "$line" =~ key\ down.*keysyms\ \[\ ([^]]+) ]]; then
        key="${BASH_REMATCH[1]}"
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        
        case "$key" in
            Return) echo "ENTER" ;;
            Escape) echo "󱊷" ;;
            BackSpace) echo "󰌍" ;;
            Tab) echo "󰌒" ;;
            Shift_L|Shift_R) echo "󰘶" ;;
            Control_L|Control_R) echo "CTRL" ;;
            Alt_L|Alt_R) echo "ALT" ;;
            Super_L|Super_R) echo "SUPER" ;;
            Up|Down|Left|Right) echo "${key^^}" ;;
            space) echo "󱁐" ;;
            *) [[ -n "$key" ]] && echo "$key" ;;
        esac
    fi
done