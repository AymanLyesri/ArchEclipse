#!/bin/bash

ags quit

killall gjs

ags bundle $HOME/.config/ags/app.tsx /tmp/ags-bin

/tmp/ags-bin &
