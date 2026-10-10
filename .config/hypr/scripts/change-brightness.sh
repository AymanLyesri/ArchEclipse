#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: $0 [+10|-10]"
    exit 1
fi

DELTA=$(( $1 ))

RUNDIR=${XDG_RUNTIME_DIR:-/tmp}
PENDING="$RUNDIR/brightness.pending"
WORK="$RUNDIR/brightness.work"
LOCK="$RUNDIR/brightness.lock"
CACHE="$RUNDIR/ddc-buses"

# Queue this keypress (small O_APPEND writes are atomic)
echo "$DELTA" >> "$PENDING"

apply() {
    local total=$1 sign=+ val=$1

    # 1. Internal backlight (laptop panels), if any
    if compgen -G "/sys/class/backlight/*" >/dev/null; then
        local dev cur target
        dev=$(/bin/ls -1 /sys/class/backlight | head -1)
        cur=$(brightnessctl -m -d "$dev" | cut -d, -f4 | tr -d '%')
        target=$(( cur + total ))
        [ "$target" -gt 100 ] && target=100
        [ "$target" -lt 0 ] && target=0
        for d in /sys/class/backlight/*; do
            brightnessctl -q --device="$(basename "$d")" set "${target}%"
        done
    fi

    # 2. External monitors via DDC/CI (focused monitor only)
    if command -v ddcutil >/dev/null; then
        # Cache "connector bus" pairs, e.g. "DP-1 5"
        if [ ! -s "$CACHE" ]; then
            ddcutil detect --brief 2>/dev/null | awk '
                /I2C bus:/      { bus=$NF; sub(".*i2c-","",bus) }
                /DRM_connector:/ { c=$NF; sub("^card[0-9]+-","",c); print c, bus }
            ' > "$CACHE"
        fi

        local focused bus
        focused=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        bus=$(awk -v m="$focused" '$1==m {print $2}' "$CACHE")

        if [ -n "$bus" ]; then
            if [ "$total" -lt 0 ]; then sign=-; val=$(( -total )); fi
            ddcutil --bus "$bus" setvcp 10 "$sign" "$val" --noverify --sleep-multiplier .1
        fi
    fi
}

# Become the single worker; if one is already running it will pick up our delta
exec 9>"$LOCK"
while :; do
    flock -n 9 || exit 0

    while mv "$PENDING" "$WORK" 2>/dev/null; do
        total=$(awk '{s+=$1} END{print s+0}' "$WORK")
        rm -f "$WORK"
        [ "$total" -ne 0 ] && apply "$total"
    done

    # Release, then re-check to close the race where a keypress
    # arrived after the last mv but before unlock
    flock -u 9
    [ -s "$PENDING" ] || exit 0
done