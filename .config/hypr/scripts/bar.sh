#!/bin/bash

# ArchEclipse status bar launcher.
# Currently migrating: AGS (astal/gjs) -> Quickshell (QtQuick).
# During migration BOTH bars run side by side; comment/uncomment to compare.

AGS_TMP="/tmp/ags-${USER}"
QS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/archeclipse"

run_ags() {
  mkdir -p "$AGS_TMP"
  ags quit
  killall gjs >/dev/null 2>&1
  ags bundle "$HOME/.config/ags/app.tsx" "$AGS_TMP/ags-bin"
  nohup "$AGS_TMP/ags-bin" > "$AGS_TMP/ags-bin.log" 2>&1 &
}

run_quickshell() {
  # qs instances are per-config; kill any stale instance of this config
  qs kill -p "$QS_CONF" >/dev/null 2>&1
  nohup qs -p "$QS_CONF" > "/tmp/qs-bar-${USER}.log" 2>&1 &
}

# ---- active implementation ----
run_quickshell

# To test the AGS bar instead, comment the line above and uncomment:
# run_ags

exit 0
