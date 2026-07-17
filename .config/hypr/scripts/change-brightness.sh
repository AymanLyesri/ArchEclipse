#!/usr/bin/env bash

# Check if an argument was provided (e.g., +10 or -10)
if [ -z "$1" ]; then
    echo "Usage: $0 [+10|-10]"
    exit 1
fi

STEP=$1

# 1. Grab the primary backlight device safely
PRIMARY_DEV=$(/bin/ls -1 /sys/class/backlight | head -1)

# If no backlight devices exist, exit gracefully
if [ -z "$PRIMARY_DEV" ]; then
    exit 0
fi

# 2. Get the current absolute percentage of the primary device
# Ex: "50"
CURRENT_PERC=$(brightnessctl -m -d "$PRIMARY_DEV" | cut -d, -f4 | tr -d '%')

# 3. Calculate the new target absolute percentage safely using bash arithmetic
TARGET_PERC=$((CURRENT_PERC ${STEP}))

# Bound the percentage between 0 and 100
if [ $TARGET_PERC -gt 100 ]; then
    TARGET_PERC=100
elif [ $TARGET_PERC -lt 0 ]; then
    TARGET_PERC=0
fi

# 4. Broadcast the exact absolute percentage to ALL available devices
# This instantly fixes any boot-time out-of-sync bugs
for dev in /sys/class/backlight/*; do
    DEV_NAME=$(basename "$dev")
    brightnessctl -q --device="$DEV_NAME" set "${TARGET_PERC}%"
done