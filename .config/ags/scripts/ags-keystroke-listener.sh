#!/bin/bash

# Key code to key name mapping
declare -A KEY_MAP=(
    [1]="ESC" [2]="1" [3]="2" [4]="3" [5]="4" [6]="5" [7]="6" [8]="7" [9]="8" [10]="9" [11]="0"
    [12]="-" [13]="=" [14]="BACKSPACE" [15]="TAB"
    [16]="Q" [17]="W" [18]="E" [19]="R" [20]="T" [21]="Y" [22]="U" [23]="I" [24]="O" [25]="P"
    [26]="[" [27]="]" [28]="ENTER" [29]="CTRL"
    [30]="A" [31]="S" [32]="D" [33]="F" [34]="G" [35]="H" [36]="J" [37]="K" [38]="L"
    [39]=";" [40]="'" [41]="\`" [42]="SHIFT"
    [43]="\\" [44]="Z" [45]="X" [46]="C" [47]="V" [48]="B" [49]="N" [50]="M"
    [51]="," [52]="." [53]="/" [54]="RSHIFT" [55]="*" [56]="ALT" [57]="SPACE"
    [58]="CAPS" [59]="F1" [60]="F2" [61]="F3" [62]="F4" [63]="F5" [64]="F6"
    [65]="F7" [66]="F8" [67]="F9" [68]="F10" [69]="NUM" [70]="SCROLL"
    [71]="KP7" [72]="KP8" [73]="KP9" [74]="KP-" [75]="KP4" [76]="KP5" [77]="KP6" [78]="KP+"
    [79]="KP1" [80]="KP2" [81]="KP3" [82]="KP0" [83]="KP."
    [87]="F11" [88]="F12"
    [96]="KPENTER" [97]="RCTRL" [98]="KP/" [99]="SYSRQ" [100]="RALT"
    [102]="HOME" [103]="UP" [104]="PGUP" [105]="LEFT" [106]="RIGHT"
    [107]="END" [108]="DOWN" [109]="PGDN" [110]="INSERT" [111]="DELETE"
    [113]="MUTE" [114]="VOLDOWN" [115]="VOLUP" [116]="POWER"
    [119]="PAUSE" [125]="LSUPER" [126]="RSUPER" [127]="MENU"
)

# Auto-detect keyboard device
KEYBOARD_DEVICE=$(ls -1 /dev/input/by-id/*-event-kbd | head -n1)

if [ -z "$KEYBOARD_DEVICE" ]; then
    echo "Error: No keyboard device found!"
    notify-send "AGS Keystroke Listener" "Error: No keyboard device found!"
    exit 1
fi

stdbuf -o0 hexdump -v -e '1/8 "%d " 1/8 "%d " 1/2 "%d " 1/2 "%d " 1/4 "%d\n"' "$KEYBOARD_DEVICE" | \
while read sec usec type code value; do
    if [ "$type" -eq 1 ] && [ "$value" -eq 1 ]; then
        # Get key name from map, or use code if not found
        key="${KEY_MAP[$code]:-CODE_$code}"
        echo $key
    fi
done