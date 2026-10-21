#!/usr/bin/env python3
"""Standalone mp4 screen-recording compressor.

Re-encodes once with libx264 CRF — static desktop content packs far tighter
than wf-recorder's capture defaults. Same container/codec, audio copied
untouched. In-place by default (input replaced via tmp + atomic rename);
pass a second path to write to a different file. Never grows the file: if
the re-encode is not smaller, the failure keeps the source untouched.

    python3 compress-video.py <input> [output] [--crf N] [--silent]

Exit 0 = written (or verified ok). Exit 1 = failed, source untouched.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

FTYP_OK = lambda b: b[:12][4:8] == b"ftyp"


def duration_of(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, timeout=60,
    )
    if out.returncode != 0:
        raise RuntimeError("ffprobe failed on " + str(path))
    return float(out.stdout.strip())


def compress(source, dest_dir, crf, kill_bigger):
    """Encode source to a tmp file in dest_dir; return the tmp path + size.

    kill_bigger: if True and the encode is not smaller than the source,
    raise (the caller then keeps the tmp off the target).
    """
    run = subprocess.run(
        [
            "ffmpeg", "-y", "-v", "error", "-i", str(source),
            "-c:v", "libx264", "-preset", "slow", "-crf", str(crf),
            "-pix_fmt", "yuvj420p", "-movflags", "+faststart",
            "-c:a", "copy",
            str(path_tmp := dest_dir / ".compress-tmp.mp4"),
        ],
        capture_output=True, text=True, timeout=900,
    )
    if run.returncode != 0:
        raise RuntimeError("ffmpeg failed: " + run.stderr.strip()[-400:])
    tmp = Path(path_tmp)
    size = tmp.stat().st_size
    try:
        if size == 0:
            raise RuntimeError("ffmpeg produced an empty file")
        if not FTYP_OK(tmp.read_bytes()[:12]):
            raise RuntimeError("ffmpeg output is not an mp4")
        before = duration_of(source)
        after = duration_of(tmp)
        if abs(after - before) > 1.5:
            raise RuntimeError(f"duration drifted: {before:.1f}s -> {after:.1f}s")
        if kill_bigger and size >= source.stat().st_size:
            raise RuntimeError(
                f"re-encode not smaller ({size} >= {source.stat().st_size} bytes)"
            )
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise
    return tmp


def main(argv=None):
    parser = argparse.ArgumentParser(description="Compress a screen-recording mp4.")
    parser.add_argument("input")
    parser.add_argument("output", nargs="?")
    parser.add_argument("--crf", type=int, default=26)
    parser.add_argument("--silent", action="store_true")
    args = parser.parse_args(argv)

    source = Path(args.input).expanduser()
    if not source.is_file():
        print(f"ERROR: missing input file: {source}", file=sys.stderr)
        return 1

    try:
        if not FTYP_OK(source.read_bytes()[:12]):
            raise RuntimeError("Not an mp4: " + str(source))
        source_size = source.stat().st_size
        in_place = not args.output
        if in_place:
            dest = source
        else:
            dest = Path(args.output).expanduser()
            if dest.exists() and dest.samefile(source):
                print("ERROR: output equals input — omit it for in-place", file=sys.stderr)
                return 1
            dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = compress(source, dest.parent, args.crf, kill_bigger=in_place)
        os.replace(tmp, dest)
        os.chmod(dest, 0o644)
        if not args.silent:
            pct = 100.0 * (source_size - dest.stat().st_size) / source_size
            print(
                f"{source.name}: {source_size/1e6:.1f} MB -> "
                f"{dest.stat().st_size/1e6:.1f} MB ({pct:.0f}% smaller)"
            )
        return 0
    except BaseException as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
