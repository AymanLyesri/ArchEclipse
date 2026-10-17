#!/usr/bin/env python3
import re
import subprocess
import sys
from pathlib import Path


def luminance(rgb):
    return (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255


def sampled_brightness(path):
    result = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(path),
            "-vf", "scale=1:1:flags=area,format=rgb24",
            "-frames:v", "1", "-f", "rawvideo", "pipe:1",
        ],
        check=True,
        stdout=subprocess.PIPE,
    )
    if len(result.stdout) < 3:
        raise ValueError(f"ffmpeg returned no pixel data for {path}")
    return luminance(result.stdout[:3])


def palette_color(text, name):
    match = re.search(rf"^\${name}:\s*(#[0-9a-fA-F]{{6}})\s*;", text, re.MULTILINE)
    if not match:
        raise ValueError(f"palette is missing ${name}")
    return match.group(1)


def color_luminance(color):
    return luminance(bytes.fromhex(color[1:]))


def replace_color(text, name, color):
    pattern = rf"^(\${name}:\s*)#[0-9a-fA-F]{{6}}(\s*;)"
    updated, count = re.subn(pattern, rf"\g<1>{color}\g<2>", text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"could not update ${name}")
    return updated


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: normalize-greeter-palette.py WALLPAPER COLORS_SCSS")

    wallpaper, palette_path = map(Path, sys.argv[1:])
    text = palette_path.read_text()
    # With autovariant disabled, coloreclipse uses the current desktop mode.
    desired_light = sampled_brightness(wallpaper) >= 0.5
    current_light = color_luminance(palette_color(text, "background")) >= 0.5

    if desired_light != current_light:
        background = palette_color(text, "foreground")
        foreground = palette_color(text, "background")
        text = replace_color(text, "background", background)
        text = replace_color(text, "foreground", foreground)
        text = replace_color(text, "color0", background)
        text = replace_color(text, "color15", foreground)

    palette_path.write_text(text)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"greeter palette normalization failed: {error}", file=sys.stderr)
        raise SystemExit(1)
