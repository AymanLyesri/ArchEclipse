#!/bin/bash

set -u

AGS_TMP="/tmp/ags-${USER:-$(id -un)}"
mkdir -p "$AGS_TMP"

if ! ags bundle "$HOME/.config/ags/app.tsx" "$AGS_TMP/ags-bin.new"; then
    echo "bar.sh: bundle failed; leaving the running shell alone" >&2
    rm -f "$AGS_TMP/ags-bin.new"
    exit 1
fi

mv -f "$AGS_TMP/ags-bin.new" "$AGS_TMP/ags-bin"

ags quit >/dev/null 2>&1

killall gjs >/dev/null 2>&1

nohup "$AGS_TMP/ags-bin" > "$AGS_TMP/ags-bin.log" 2>&1 &

exit 0
