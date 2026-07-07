#!/bin/bash
#
# wallpaperengine.sh <monitor> <preview>
#
# Applies a Steam Wallpaper Engine item. A persistent per-monitor engine process
# is driven over a Unix control socket, so changing wallpaper is a live swap
# (no restart). A new process is only started when one isn't already running for
# the monitor. <preview> is the item's preview at <workshop>/<id>/preview.*.

hyprdir="$HOME/.config/hypr"
daemon="$hyprdir/wallpaper-daemon"
settings="$HOME/.config/ags/cache/settings/settings.json"

monitor="$1"
preview="$2"
[ -z "$monitor" ] || [ -z "$preview" ] && { echo "usage: wallpaperengine.sh <monitor> <preview>" >&2; exit 1; }

dir="$(dirname "$preview")"          # workshop item folder = the wallpaper
id="$(basename "$dir")"
sock="${XDG_RUNTIME_DIR:-/tmp}/lwe-$monitor.sock"

# Cache of real rendered frames (one PNG per item), produced by asking the live engine to
# screenshot itself. Used as the theme-colour source (so the palette matches what's actually on
# screen, not the workshop preview) and as a static fallback if the engine later can't run.
preview_cache="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaperengine/previews"

# Serialize per monitor: two concurrent applies (e.g. a wallpaper switch racing the shell's
# startup restore) would both pass the "no engine running" check and spawn two engines stacked
# on the same output, fighting over the same control socket. With the lock the second caller
# waits, then sees the live socket and does a live swap instead. Bounded wait so a stuck holder
# can never freeze wallpaper switching outright. The engine launch below MUST close fd 9
# (9>&-) or the long-lived engine inherits the lock and holds it for its whole lifetime.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/lwe-$monitor.lock"
flock -w 15 9 || { echo "wallpaperengine.sh: lock timeout for $monitor" >&2; exit 1; }

bin="$HOME/linux-wallpaperengine/build/output/linux-wallpaperengine"
[ -x "$bin" ] || bin="$(command -v linux-wallpaperengine)" || {
    notify-send -u critical "Wallpaper Engine" "linux-wallpaperengine is not installed" 2>/dev/null; exit 1; }

we()   { jq -r "($1) // empty" "$settings" 2>/dev/null; }
send() { printf '%s\n' "$*" | socat - "UNIX-CONNECT:$sock" 2>/dev/null; }

# Push this wallpaper's saved property overrides to the running engine. The control socket is
# serviced once per render frame, so each round-trip costs up to a frame (seconds on a low-FPS
# wallpaper). Fire them concurrently — the engine drains all pending clients in a single poll — so
# N properties cost one frame instead of N.
push_props() {
    local f="$daemon/config/properties/$id.conf"
    [ -f "$f" ] || return
    while IFS='=' read -r k v; do
        [ -n "$k" ] && send "property $monitor $k $v" &
    done < "$f"
    wait
}

# Engine can't render this item (web/3D-model/asset) or failed to start -> show a static image.
# Prefer a previously cached rendered frame (looks like the actual wallpaper) over the workshop
# preview. The 9>&- matters: these scripts spawn long-lived daemons (mpvpaper) that would otherwise
# inherit the per-monitor lock fd and block every future wallpaper switch.
fallback() {
    notify-send "Wallpaper Engine" "'$id' can't be rendered — showing a static preview." 2>/dev/null
    if [ -s "$preview_cache/$id.png" ]; then
        "$daemon/hyprpaper.sh" "$monitor" "$preview_cache/$id.png" 9>&-
        return
    fi
    case "${preview##*.}" in
        gif|webm|mp4|GIF|WEBM|MP4) "$daemon/mpvpaper.sh" "$monitor" "$preview" 9>&- ;;
        *)                         "$daemon/hyprpaper.sh" "$monitor" "$preview" 9>&- ;;
    esac
}

# Regenerate the desktop colour scheme from the wallpaper — always in a detached, debounced
# background job so it never delays the visible swap or holds the per-monitor lock (otherwise
# back-to-back workspace switches queue behind each other's colour regen). The palette comes from a
# real rendered frame: a cached frame is reused instantly, and only the first view of a wallpaper
# pays for a screenshot. During rapid switching only the final wallpaper themes (marker guards it).
theme_async() {
    local marker="${XDG_RUNTIME_DIR:-/tmp}/lwe-theme-$monitor.target"
    printf '%s' "$id" > "$marker"
    setsid bash -c '
        marker=$1; want=$2; sock=$3; preview=$4; cache=$5; wal=$6
        # Settle briefly so a burst of workspace switches collapses to just the last one.
        sleep 0.4
        [ "$(cat "$marker" 2>/dev/null)" = "$want" ] || exit 0
        out="$cache/$want.png"
        if [ ! -s "$out" ]; then
            mkdir -p "$cache"
            printf "screenshot %s\n" "$out" | socat - "UNIX-CONNECT:$sock" >/dev/null 2>&1
            for _ in $(seq 1 40); do [ -s "$out" ] && break; sleep 0.1; done
        fi
        # Only recolour if this is still the wallpaper on screen.
        [ "$(cat "$marker" 2>/dev/null)" = "$want" ] || exit 0
        [ -s "$out" ] || out="$preview"
        "$wal" "$out" >/dev/null 2>&1
    ' _ "$marker" "$id" "$sock" "$preview" "$preview_cache" "$hyprdir/theme/scripts/wal-theme.sh" \
        >/dev/null 2>&1 9>&- < /dev/null &
    disown
}

# The engine renders every Wallpaper Engine type natively now — 2D scenes, web (CEF),
# video, and 3D model (.mdl) scenes — so no special handling per type is needed here;
# we just hand the item to the engine below. (The old three.js bake for 3D models is
# gone.) fallback() is only for non-WE wallpapers (plain images/videos).

# Already running for this monitor -> swap live. The swap doubles as the liveness probe (saves a
# round-trip, and each round-trip can cost up to a render frame): a live engine answers "ok" or
# "error", a dead socket answers nothing. On "ok" swap; on "error" the engine is up but can't render
# this item -> static fallback; on no answer the socket is stale -> fall through to a fresh start.
if [ -S "$sock" ]; then
    resp="$(send "bg $monitor $dir")"
    if [ "$resp" = ok ]; then
        push_props
        # The swap is on screen now; drop the per-monitor lock before theming so back-to-back
        # workspace switches don't serialise behind colour regeneration.
        exec 9>&-
        theme_async
        exit 0
    elif [ "$resp" = error ]; then
        fallback
        exit 0
    fi
    # empty/other response -> engine gone -> fall through to the fresh-start path below
fi

# Stop any existing engine for THIS monitor and WAIT for it to actually exit before the
# socket file is removed below. A lingering engine keeps listening on the socket inode
# after the file is unlinked, leaving an orphaned/unlinked socket — clients then get
# "No such file or directory" and every live control command silently fails, which forces
# full reloads instead of live changes. The trailing space anchors the match so "HDMI-A-1"
# doesn't also match "HDMI-A-10".
stop_engine_for_monitor () {
    pgrep -f -- "--screen-root $monitor " >/dev/null 2>&1 || return 0
    pkill -f -- "--screen-root $monitor " 2>/dev/null
    for _ in $(seq 1 30); do
        pgrep -f -- "--screen-root $monitor " >/dev/null 2>&1 || return 0
        sleep 0.1
    done
    pkill -9 -f -- "--screen-root $monitor " 2>/dev/null
    sleep 0.2
}

# Otherwise start a fresh engine for this monitor. Stop any stale wallpaper first.
stop_engine_for_monitor
rm -f "$sock"
for pid in $(pgrep -x mpvpaper); do
    tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q -- "$monitor" && kill "$pid" 2>/dev/null
done

args=(--control-socket "$sock" --screen-root "$monitor" --bg "$dir")
sc="$(we .wallpaperEngine.scaling.value)";  [ -n "$sc" ] && args+=(--scaling "$sc")
cl="$(we .wallpaperEngine.clamping.value)"; [ -n "$cl" ] && args+=(--clamp "$cl")
fp="$(we .wallpaperEngine.fps.value)";      [ -n "$fp" ] && args+=(--fps "$fp")
rs="$(we .wallpaperEngine.renderScale.value)"; [ -n "$rs" ] && args+=(--render-scale "$rs")
# Mute the wallpaper's own OUTPUT with volume 0, NOT --silent: --silent turns off
# audio *capture* (audioprocessing) too, which kills sound-reactive wallpapers
# (visualizers, reactive particles). Volume 0 silences output while reactivity
# keeps working off the system audio.
if [ "$(we .wallpaperEngine.mute.value)" = true ]; then
    args+=(--volume 0)
else
    vo="$(we .wallpaperEngine.volume.value)"; [ -n "$vo" ] && args+=(--volume "$vo")
fi
[ "$(we .wallpaperEngine.noAutomute.value)" = true ]        && args+=(--noautomute)
[ "$(we .wallpaperEngine.disableMouse.value)" = true ]      && args+=(--disable-mouse)
[ "$(we .wallpaperEngine.disableParallax.value)" = true ]   && args+=(--disable-parallax)
[ "$(we .wallpaperEngine.noFullscreenPause.value)" = true ] && args+=(--no-fullscreen-pause)
sp="$(we .wallpaper.playbackSpeed.value)"; [ -n "$sp" ] && [ "$sp" != 1 ] && args+=(--playback-speed "$sp")
ad="$(we .wallpaperEngine.audioDevice.value)"; [ -n "$ad" ] && args+=(--audio-device "$ad")

# Saved per-wallpaper property overrides: apply at launch via --set-property so
# they take effect on the initial load (the socket push_props below also handles
# live changes once running). This is what enables e.g. a web wallpaper's
# visualizer / background that ship disabled by default.
propconf="$daemon/config/properties/$id.conf"
if [ -f "$propconf" ]; then
    while IFS='=' read -r k v; do
        [ -n "$k" ] && args+=(--set-property "$k=$v")
    done < "$propconf"
fi

# Launch under a small supervisor that keeps the engine alive across crashes: an abnormal
# exit (segfault in CEF teardown, driver hiccup, ...) relaunches it after a short pause, while
# an intentional stop does not — stop_engine_for_monitor's pkill pattern matches the
# supervisor's own command line too (it carries the same --screen-root args), so a deliberate
# stop kills both. Clean exits and TERM/KILL are treated as intentional.
#
# A watchdog also covers a nastier failure: the compositor can close the engine's layer surface
# (output disable, `hyprctl reload`, monitor hotplug) after which the engine keeps running but
# renders nothing — an invisible wallpaper that no exit-code check can catch. So the engine runs
# in the background and we poll Hyprland: if the monitor is present but the engine has no layer on
# it for a few checks, kill the engine so the loop relaunches it.
launch_supervised() {
    local log="${XDG_CACHE_HOME:-$HOME/.cache}/lwe-$monitor.log"
    mkdir -p "$(dirname "$log")"
    setsid bash -c '
        enginebin="$1"; shift
        log="$1"; shift
        monitor="$1"; shift
        crashes=0

        # True if the engine has a live layer on $monitor. Also true (do not restart) when the
        # monitor itself is gone or hyprctl/jq are unavailable — there is nothing to render on, so
        # the watchdog must never thrash against a missing output or a probe it cannot run.
        engine_layer_ok() {
            command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
            local mons layers
            mons="$(hyprctl monitors -j 2>/dev/null)" || return 0
            printf "%s" "$mons" | jq -e --arg m "$monitor" "any(.[]; .name==\$m)" >/dev/null 2>&1 || return 0
            layers="$(hyprctl layers -j 2>/dev/null)" || return 0
            printf "%s" "$layers" | jq -e --arg m "$monitor" \
                "(.[\$m].levels // {}) | any(.[][]?; .namespace|test(\"wallpaperengine\"))" >/dev/null 2>&1
        }

        while :; do
            # Rotate the log so it never grows unbounded.
            [ -f "$log" ] && [ "$(stat -c%s "$log" 2>/dev/null || echo 0)" -gt 1000000 ] && : > "$log"
            start=$(date +%s)
            "$enginebin" "$@" >>"$log" 2>&1 &
            epid=$!

            misses=0
            while kill -0 "$epid" 2>/dev/null; do
                sleep 15
                kill -0 "$epid" 2>/dev/null || break
                if engine_layer_ok; then
                    misses=0
                else
                    misses=$((misses+1))
                    if [ "$misses" -ge 3 ]; then
                        printf "%s engine alive but no layer on %s — restarting\n" "$(date -Is)" "$monitor" >>"$log"
                        kill "$epid" 2>/dev/null; sleep 2; kill -9 "$epid" 2>/dev/null
                        break
                    fi
                fi
            done
            wait "$epid"; rc=$?

            # A watchdog kill is an intentional restart, not an engine exit — skip the clean-stop
            # check in that case so the loop always relaunches.
            if [ "$misses" -lt 3 ]; then
                case "$rc" in 0|129|130|137|143) exit 0 ;; esac
            fi

            ran=$(( $(date +%s) - start ))
            # A run that survived a while then died (e.g. an EGL/DPMS surface loss when the monitor
            # slept) is NOT a startup crash-loop. Reset the counter on healthy uptime so occasional
            # crashes never accumulate to a permanent give-up.
            if [ "$ran" -ge 60 ]; then crashes=0; else crashes=$((crashes+1)); fi
            printf "%s engine exit %s after %ss (crashes=%s)\n" "$(date -Is)" "$rc" "$ran" "$crashes" >>"$log"
            if [ "$crashes" -ge 5 ]; then
                # Rapid crash-loop: back off, then keep trying (do NOT give up permanently, so the
                # wallpaper recovers when the monitor wakes / the transient condition clears).
                notify-send -u critical "Wallpaper Engine" "Engine crash-looping (exit $rc) — backing off. Log: $log" 2>/dev/null
                sleep 30
                crashes=0
                continue
            fi
            notify-send "Wallpaper Engine" "Engine crashed (exit $rc) — restarting…" 2>/dev/null
            sleep 2
        done
    ' _ "$bin" "$log" "$monitor" "${args[@]}" >/dev/null 2>&1 9>&- < /dev/null &
    disown
}

# Confirm it stays up. CEF's GPU/offscreen init occasionally crashes on the first
# try (Wayland), so retry a couple times before giving up — a far better outcome
# than dropping a renderable wallpaper to a static preview.
started=false
for attempt in 1 2 3; do
    stop_engine_for_monitor
    rm -f "$sock"
    launch_supervised
    for _ in $(seq 1 25); do [ -S "$sock" ] && break; sleep 0.2; done
    sleep 1
    if pgrep -f -- "--control-socket $sock" >/dev/null 2>&1; then
        started=true
        break
    fi
done

if [ "$started" = true ]; then
    # Property overrides were already applied at launch via --set-property above.
    # Do NOT re-push them over the socket here: that calls setProperty -> reloads
    # the wallpaper seconds after startup, which crashes CEF web wallpapers.
    theme_async
else
    fallback
fi
