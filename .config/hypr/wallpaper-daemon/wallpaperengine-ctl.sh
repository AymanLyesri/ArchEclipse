#!/bin/bash
#
# wallpaperengine-ctl.sh <command...>
#
# Broadcasts a live control command to every running per-monitor engine so
# option/property/speed changes apply instantly (no restart). Screen-scoped
# commands (scaling/clamp/property) get the monitor inserted automatically;
# everything else (speed/volume/mute/set ...) is passed through as-is.
#
# Exit status (so the caller can surface the failure or fall back to a restart):
#   0  - at least one running engine accepted the command
#   1  - no reachable engine, or every engine rejected it (e.g. an unsupported
#        command, or an orphaned/unresponsive socket). The reason is printed.

[ -n "$1" ] || exit 0

found_socket=0
delivered=0
last_response=""

for sock in "${XDG_RUNTIME_DIR:-/tmp}"/lwe-*.sock; do
    [ -S "$sock" ] || continue
    found_socket=1
    monitor="${sock##*/lwe-}"
    monitor="${monitor%.sock}"

    case "$1" in
        scaling|clamp|property) cmd="$1 $monitor ${*:2}" ;;
        *)                      cmd="$*" ;;
    esac

    response="$(printf '%s\n' "$cmd" | timeout 2 socat - "UNIX-CONNECT:$sock" 2>/dev/null | tr -d '\r\n')"
    last_response="$response"

    case "$response" in
        # No reply (dead/orphaned socket) or an explicit rejection -> not delivered here.
        ""|error*|"unknown command"*) continue ;;
    esac
    delivered=$((delivered + 1))
done

if [ "$found_socket" = 0 ]; then
    echo "no-socket"
    exit 1
fi
if [ "$delivered" -eq 0 ]; then
    echo "${last_response:-rejected}"
    exit 1
fi
exit 0
