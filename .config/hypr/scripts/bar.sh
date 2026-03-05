#!/bin/bash

ags quit

killall gjs >/dev/null 2>&1

ags bundle $HOME/.config/ags/app.tsx /tmp/ags-bin

nohup /tmp/ags-bin > /dev/null 2>&1 &

exit 0
