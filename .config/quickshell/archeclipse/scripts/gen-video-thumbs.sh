#!/bin/bash
# gen-video-thumbs.sh — first-frame JPEG thumbnails for video wallpapers.
#
# Usage: gen-video-thumbs.sh <video> [...]
# Cache dir via $THUMB_CACHE (default ~/.cache/quickshell/wallpaper-thumbs).
#
# Thumb name is deterministic from the source path so QML can derive it
# without hashing: sanitized path + ".jpg" (sed 's/[^A-Za-z0-9._-]/_/g',
# mirrored in WallpaperPanelBody.thumbFor). Freshness is by mtime: a thumb
# older than its source is regenerated. ASCII paths only (byte-wise sed vs
# QML UTF-16 would disagree on unicode — all shipped folders are ASCII).
CACHE="${THUMB_CACHE:-$HOME/.cache/quickshell/wallpaper-thumbs}"
mkdir -p "$CACHE"

if [ $# -lt 1 ]; then
    echo "Usage: gen-video-thumbs.sh <video> [...]" >&2
    exit 1
fi

jsonesc() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

pairs=()
for src in "$@"; do
    [ -f "$src" ] || continue
    name=$(printf '%s' "$src" | sed 's/[^A-Za-z0-9._-]/_/g')
    out="$CACHE/${name}.jpg"
    # Skip when the thumb is newer than the source (fresh).
    if [ -f "$out" ] && [ "$out" -nt "$src" ]; then
        pairs+=("\"$(jsonesc "$src")\": \"$(jsonesc "$out")\"")
        continue
    fi
    tmp="${out%.jpg}.tmp.$$.jpg"
    if ffmpeg -loglevel error -y -ss 1 -i "$src" -vframes 1 -vf "scale=320:-1" "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$out"
        pairs+=("\"$(jsonesc "$src")\": \"$(jsonesc "$out")\"")
    else
        rm -f "$tmp"
    fi
done

# Manifest for QML (same IFS pattern as get-wallpapers.sh): only sources
# with a usable thumb are listed; the rest keep the icon fallback.
(IFS=,; echo "{${pairs[*]}}")
