#!/bin/bash

ags quit

killall gjs

ags run --gtk 3 --log-file /tmp/ags.log &
