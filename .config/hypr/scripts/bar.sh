#!/bin/bash

ags quit

killall gjs

ags bundle /home/ayman/.config/ags/app.tsx /tmp/ags-bin

/tmp/ags-bin &
