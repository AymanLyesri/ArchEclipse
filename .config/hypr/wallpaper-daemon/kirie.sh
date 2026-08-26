#!/bin/bash

# Render a Wallpaper Engine item with kirie.
#
#   kirie.sh <monitor> <item-dir>   render the item on that monitor
#   kirie.sh --stop [monitor]       drop one monitor (or the whole engine)
#   kirie.sh --restart              relaunch with the same screens
#
# One engine process serves every monitor, so switching workspaces is a `bg`
# command over its control socket rather than a restart. The engine is only
# relaunched when the set of screens it must own changes, or when a setting
# that can only be given on the command line was edited.

hyprDir="$HOME/.config/hypr"
settingsFile="$HOME/.config/ags/cache/settings/settings.json"
overrideDir="$HOME/.config/ags/cache/wallpaper-engine"
runtime="${XDG_RUNTIME_DIR:-/tmp}"
socket="$runtime/lwe.sock"
pidFile="$runtime/kirie.pid"
logFile="$runtime/kirie.log"
lockFile="$runtime/kirie.lock"

# One engine serves every screen, so only one invocation may decide whether to
# launch one. Applying a wallpaper to two monitors at once — which is exactly
# what happens at login — otherwise has both calls find no engine running and
# start their own, leaving a process per monitor, each owning one screen.
exec 9>"$lockFile"
flock 9

# The engine is installed per user, and the session PATH does not always carry
# ~/.local/bin when the compositor spawns the wallpaper daemon.
kirieBin="$(command -v kirie 2>/dev/null)"
[ -n "$kirieBin" ] || kirieBin="$HOME/.local/bin/kirie"

# Send one line to the control socket and print the reply. python3 is already a
# hard dependency of the maintenance scripts, so this needs no extra package.
send() {
    python3 -c '
import socket, sys
try:
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(float(sys.argv[3]))
    s.connect(sys.argv[1])
    s.sendall(sys.argv[2].encode() + b"\n")
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        sys.stdout.write(chunk.decode(errors="replace"))
except OSError:
    sys.exit(1)
' "$socket" "$1" "${2:-20}"
}

alive() { send ping 2 2>/dev/null | grep -q '^pong'; }

# One engine setting, or the given fallback. `tostring` rather than jq's `//`
# operator, which treats a stored `false` as absent.
setting() {
    local value
    [ -f "$settingsFile" ] || {
        printf '%s' "$2"
        return
    }
    value="$(jq -r --arg k "$1" \
        '.wallpaperEngine[$k].value | if . == null then "" else tostring end' \
        "$settingsFile" 2>/dev/null)"
    [ -n "$value" ] && printf '%s' "$value" || printf '%s' "$2"
}

# `--flag=value` when the setting has one, nothing when it is empty/default.
#
# The `=` form is deliberate: an engine that predates a flag skips the whole
# token, while `--flag value` leaves the value behind as a positional argument,
# where it is read as a background id and kills the launch.
flag_value() {
    local value
    value="$(setting "$2" "$3")"
    [ -n "$value" ] && [ "$value" != "default" ] && printf '%s=%s\n' "$1" "$value"
}

# `--flag` when the boolean setting is on.
flag_bool() {
    [ "$(setting "$2" false)" = "true" ] && printf '%s\n' "$1"
}

# The screens the running engine owns, as `<monitor> <item>` lines.
screens() {
    local out
    # A freshly launched engine answers `ping` before it has registered its
    # screens, so an immediate `status` comes back empty — and a caller adding
    # a second monitor would then relaunch with only its own, dropping the
    # wallpaper that was already up. Give it a moment to name them.
    for _ in $(seq 1 10); do
        out="$(send status 5 2>/dev/null | sed -n 's/^screen=\(.*\) bg=\(.*\)$/\1 \2/p')"
        [ -n "$out" ] && break
        alive || break
        sleep 0.3
    done
    printf '%s' "$out"
}

# The property overrides saved for an item, as `<key> <value>` lines.
overrides() {
    local file="$overrideDir/$(basename "$1").json"
    [ -f "$file" ] || return 0
    jq -r 'to_entries[] | "\(.key) \(.value|tostring)"' "$file" 2>/dev/null
}

stop_engine() {
    local pid
    pid="$(cat "$pidFile" 2>/dev/null)"
    if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
        kill "$pid" 2>/dev/null
    else
        pkill -x kirie 2>/dev/null
    fi
    rm -f "$pidFile"
    # The engine unlinks its own socket on the way out; do not outrun it.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ -S "$socket" ] || break
        sleep 0.2
    done
}

# Launch ONE engine owning every `<monitor> <item>` line in $1: each becomes a
# `--screen-root`/`--bg` pair. kirie drives every screen from one process, and
# a second instance would fight it for the same control socket.
launch() {
    local lines="$1"
    local args=() globals=() first=1 monitor item
    args+=("--control-socket=$socket")

    mapfile -t globals < <(
        flag_value --fps fps 30
        flag_value --playback-speed playbackSpeed 1
        flag_value --render-scale renderScale 1
        flag_value --battery-fps batteryFps 10
        # --silent is the muted form of --volume; passing both is contradictory.
        [ "$(setting mute false)" = "true" ] || flag_value --volume volume 15
        flag_value --audio-device audioDevice ""
        flag_value --layer layer bottom
        flag_value --gpu gpu auto
        flag_value --assets-dir assetsDir ""
        flag_bool --silent mute
        flag_bool --noautomute noAutomute
        flag_bool --no-audio-processing noAudioProcessing
        flag_bool --disable-mouse disableMouse
        flag_bool --disable-parallax disableParallax
        flag_bool --disable-particles disableParticles
        flag_bool --no-fullscreen-pause noFullscreenPause
        flag_bool --fullscreen-pause-only-active fullscreenPauseOnlyActive
    )
    args+=("${globals[@]}")

    local scaling clamp
    scaling="$(setting scaling default)"
    clamp="$(setting clamp clamp)"

    while read -r monitor item; do
        [ -n "$monitor" ] && [ -n "$item" ] || continue
        args+=("--screen-root=$monitor" "--bg=$item")
        args+=("--scaling=$scaling" "--clamp=$clamp")
        # Per-screen property overrides cannot be expressed on the command
        # line, so only the first screen's are inlined; the rest are staged
        # into their own `bg` below.
        if [ "$first" = 1 ]; then
            first=0
            while read -r key value; do
                [ -n "$key" ] && args+=("--set-property=$key=$value")
            done < <(overrides "$item")
        fi
    done <<<"$lines"

    # 9>&- closes the lock fd in the engine: it inherits every open descriptor,
    # and an engine holding the lock for its whole life blocks every later
    # invocation of this script forever.
    setsid "$kirieBin" "${args[@]}" >"$logFile" 2>&1 9>&- &

    local ready=1
    for _ in $(seq 1 50); do
        alive && {
            ready=0
            break
        }
        sleep 0.2
    done
    [ "$ready" = 0 ] || return 1
    # setsid detaches, so its own pid is not the engine's; ask for the real one.
    pgrep -nx kirie >"$pidFile"

    # Per-screen overrides the command line cannot carry.
    first=1
    while read -r monitor item; do
        [ -n "$monitor" ] && [ -n "$item" ] || continue
        if [ "$first" = 1 ]; then
            first=0
            continue
        fi
        [ -n "$(overrides "$item")" ] && apply_over_socket "$monitor" "$item"
    done <<<"$lines"
    return 0
}

# Apply an item on a screen the engine already owns: stage the saved overrides
# so they land in the same rebuild as the wallpaper itself.
apply_over_socket() {
    local monitor="$1" item="$2" key value
    while read -r key value; do
        [ -n "$key" ] && send "stage $key $value" 5 >/dev/null
    done < <(overrides "$item")
    send "bg $monitor $item" 60 >/dev/null
}

# Hand the item's preview to the theme scripts: everything downstream expects
# an image, and a wallpaper directory is not one.
theme_from_preview() {
    local preview
    preview="$(find "$1" -maxdepth 1 -iname 'preview.*' | head -n 1)"
    [ -n "$preview" ] || return 0
    printf '%s\n' "$preview" >"$hyprDir/wallpaper-daemon/config/current.conf"
    "$hyprDir/theme/scripts/wal-theme.sh" "$preview" >/dev/null 2>&1
}

case "$1" in
    --stop)
        monitor="$2"
        if [ -z "$monitor" ] || ! alive; then
            stop_engine
            exit 0
        fi
        remaining="$(screens | grep -v "^$monitor ")"
        stop_engine
        [ -n "$remaining" ] && launch "$remaining"
        exit 0
        ;;
    --restart)
        alive || exit 0
        current="$(screens)"
        stop_engine
        [ -n "$current" ] && launch "$current"
        exit $?
        ;;
esac

monitor="$1"
item="$2"

if [ -z "$monitor" ] || [ -z "$item" ]; then
    echo "Usage: kirie.sh <monitor> <item-dir> | --stop [monitor] | --restart" >&2
    exit 1
fi

if [ ! -x "$kirieBin" ]; then
    notify-send -u critical "Wallpaper Engine" "kirie is not installed"
    exit 1
fi

if alive && screens | grep -q "^$monitor "; then
    apply_over_socket "$monitor" "$item"
else
    others="$(screens | grep -v "^$monitor ")"
    stop_engine
    lines="$monitor $item"
    [ -n "$others" ] && lines="$lines"$'\n'"$others"
    launch "$lines" ||
        notify-send -u critical "Wallpaper Engine" "kirie failed to start, see $logFile"
fi

theme_from_preview "$item"
