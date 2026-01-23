#!/usr/bin/env bash

# Try multiple patterns to find keyboard device
KEYBOARD_DEVICE=$(
    ls -1 /dev/input/by-id/*-event-kbd 2>/dev/null | head -n1 || \
    ls -1 /dev/input/by-id/*-kbd 2>/dev/null | head -n1 || \
    ls -1 /dev/input/by-path/*-event-kbd 2>/dev/null | head -n1 || \
    ls -1 /dev/input/by-path/*-kbd 2>/dev/null | head -n1
)

# Fallback: find keyboard by capabilities in /proc/bus/input/devices
if [[ -z "$KEYBOARD_DEVICE" ]]; then
    # Look for devices with keyboard capabilities (EV=120013 or similar)
    KEYBOARD_EVENT=$(awk '
        /^I:/ { bus=$0 }
        /^N: Name=/ { name=$0 }
        /^H: Handlers=/ { 
            if ($0 ~ /kbd/ || $0 ~ /event/) {
                handlers=$0
            }
        }
        /^B: EV=/ { 
            # Check if it has keyboard event bit (bit 1)
            if ($0 ~ /EV=120013|EV=120003|EV=12001[0-9]/) {
                match(handlers, /event([0-9]+)/, arr)
                if (arr[1] != "") {
                    print "event" arr[1]
                    exit
                }
            }
        }
    ' /proc/bus/input/devices)
    [[ -n "$KEYBOARD_EVENT" ]] && KEYBOARD_DEVICE="/dev/input/$KEYBOARD_EVENT"
fi

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