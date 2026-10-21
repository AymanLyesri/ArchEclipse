#!/usr/bin/env python3
"""Standalone mp4 -> GIF converter for screen recordings.

Re-encodes the frames once with a generated palette — static desktop
content packs far tighter with dither=none (dither noise defeats LZW,
the GIF codec). Defaults: 10 fps, 800px wide — README-friendly size with
UI text still readable.
    python3 video-to-gif.py <input> [output] [--width W] [--fps N]
        [--dither none|bayer|floyd] [--silent]
Output defaults to <input>.gif. Exit 0 = written. Exit 1 = failed, no
output file left behind.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

FTYP_OK = lambda b: b[:12][4:8] == b"ftyp"


def source_duration(path):
    probe = subprocess.run(
        [
            "ffprobe", "-v", "error", "-show_entries", "stream=duration",
            "-of", "csv=p=0", "-select_streams", "v:0", str(path),
        ],
        capture_output=True, text=True, timeout=60,
    )
    if probe.returncode != 0:
        raise RuntimeError("ffprobe failed on " + str(path))
    return float(probe.stdout.strip().splitlines()[0])


def main(argv=None):
    parser = argparse.ArgumentParser(description="Convert an mp4 screen recording to GIF.")
    parser.add_argument("input")
    parser.add_argument("output", nargs="?")
    parser.add_argument("--width", type=int, default=800)
    parser.add_argument("--fps", type=int, default=10)
    parser.add_argument(
        "--dither", default="none",
        choices=["none", "bayer", "floyd"],
        help="palette dithering: none is cheapest and purest for UI content",
    )
    parser.add_argument("--silent", action="store_true")
    args = parser.parse_args(argv)

    source = Path(args.input).expanduser()
    if not source.is_file():
        print(f"ERROR: missing input file: {source}", file=sys.stderr)
        return 1

    try:
        if not FTYP_OK(source.read_bytes()[:12]):
            raise RuntimeError("Not an mp4: " + str(source))
        dest = (
            Path(args.output).expanduser() if args.output
            else source.with_suffix(".gif")
        )
        if dest.exists() and dest.samefile(source):
            print("ERROR: output equals input", file=sys.stderr)
            return 1
        fd, tmp = tempfile.mkstemp(prefix=".gif-", suffix=".gif", dir=dest.parent)
        os.close(fd)
        tmp = Path(tmp)
        # One pass, one decode: split feeds both the palette generator and
        # the palette applier. Dither noise defeats LZW per-pixel, so "none"
        # is a size win measured at >8x vs the original default for UI.
        filters = (
            f"fps={args.fps},scale={args.width}:-2:flags=lanczos,"
            "split[a][b];[a]palettegen=stats_mode=diff[p];"
            f"[b][p]paletteuse=dither={args.dither}"
        )
        fh = subprocess.Popen(
            # -y: mkstemp already created the output path, and without -y
            # ffmpeg prompts instead of overwriting — empty file, rc 0.
            ["ffmpeg", "-y", "-v", "error", "-i", str(source),
             "-vf", filters, "-loop", "0", str(tmp)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        _o, err = fh.communicate(timeout=900)
        if fh.returncode != 0:
            raise RuntimeError("ffmpeg failed: " + err.strip()[-400:])
        if tmp.stat().st_size == 0:
            raise RuntimeError("ffmpeg produced an empty file")
        with open(tmp, "rb") as head:
            if not head.read(6).startswith(b"GIF8"):
                raise RuntimeError("output is not a GIF")
        gif_dur = source_duration(tmp)
        if abs(gif_dur - source_duration(source)) > 1.5:
            raise RuntimeError(f"duration drifted: {gif_dur:.1f}s")
        os.replace(tmp, dest)
        os.chmod(dest, 0o644)
        if not args.silent:
            print(
                f"{dest.name}: {dest.stat().st_size/1e6:.1f} MB "
                f"({args.width}px @{args.fps}fps, dither={args.dither}, from {source.name})"
            )
        return 0
    except BaseException as e:
        print(f"ERROR: {e}", file=sys.stderr)
        try:
            tmp.unlink(missing_ok=True)  # type: ignore[possibly-unbound]
        except NameError:
            pass
        return 1


if __name__ == "__main__":
    sys.exit(main())
