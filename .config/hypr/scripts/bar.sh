#!/bin/bash

AGS_TMP="/tmp/ags-${USER}"
mkdir -p "$AGS_TMP"

ags quit

killall gjs >/dev/null 2>&1

ags bundle $HOME/.config/ags/app.tsx $AGS_TMP/ags-bin

# output log to $AGS_TMP/ags-bin.log
nohup $AGS_TMP/ags-bin > "$AGS_TMP/ags-bin.log" 2>&1 &

exit 0
