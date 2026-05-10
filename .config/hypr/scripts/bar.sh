#!/bin/bash

AGS_TMP="/tmp/ags-${USER}"
mkdir -p "$AGS_TMP"

ags quit

killall gjs >/dev/null 2>&1

ags bundle $HOME/.config/ags/app.tsx $AGS_TMP/ags-bin

nohup $AGS_TMP/ags-bin > /dev/null 2>&1 &

exit 0
