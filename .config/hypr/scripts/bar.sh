#!/bin/bash

ags quit

killall gjs

ags run --log-file /tmp/ags.log &
