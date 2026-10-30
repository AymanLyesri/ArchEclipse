#!/usr/bin/env python3
"""ArchEclipse QML style-audit harness.

One place defines the styling contract:
  - static QML scan: every color/radius/font-size/opacity literal must be a
    Theme token binding (or an explicitly allowlisted exception)
  - --palette: re-check the token derivation floors against a colors.scss

Exit 0 = clean; exit 1 = findings; exit 2 = usage/IO error.
Printed rows:  file:line  RULE  detail

Allowlists (deliberate, documented):
  - theme/ directory: the token source itself keeps fallback hexes
  - DonationsWidget.qml / IslandSideRail.qml: official brand colors
  - lines starting with `//` and anything after a line's `//` comment
  - inline opt-out: append `// audit: ok <reason>` on the offending line
"""
import argparse
import colorsys
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRNAMES_PREFIX = {"theme/"}
SKIP_BASENAMES = {
    "DonationsWidget.qml",  # official brand hexes (crypto/Patreon)
    "IslandSideRail.qml",   # Patreon brand pair
    "Weather.qml",          # services: weather-code→color DATA (fixed plate
                            # blues year-round, verified against codeInfo) —
                            # not widget styling
}
OPT_OUT_MARKER = "// audit: ok"

RADIUS_VOCAB = {4, 6, 8, 10, 16, 24}
OPACITY_ALLOWED = {0.0, 0.15, 0.2, 0.35, 0.5, 0.95, 1.0}

RULES = [
    ("R-Hex", r'(?<![\w&/])#[0-9a-fA-F]{3,8}\b'),
    ("R-Named", r'(?:\:\s*|\=\s*)"(white|black)"'),
    ("R-Rgba", r'\bQt\.rgba\s*\(|(?<![\w.])\brgba\s*\('),
    ("R-Font", r'(?:font\.pixelSize|(?<![\w.])pixelSize)\s*:\s*([0-9]+(?:\.[0-9]+)?)'),
    ("R-Radius", r'(?<![\w.])\bradius\s*:\s*([0-9]+(?:\.[0-9]+)?)'),
    ("R-Opacity", r'(?<![\w.])\bopacity\s*:\s*([0-9]+(?:\.[0-9]+)?)'),
]
COMPILED = [(name, re.compile(pattern)) for name, pattern in RULES]


def code_part(line: str) -> str:
    """Code up to the first // comment; marker must sit in the comment tail."""
    cut = line.find("//")
    if cut < 0:
        return line, False
    return line[:cut], OPT_OUT_MARKER in line[cut:]


def check_line(path_rel: str, lineno: int, line: str, out: list) -> None:
    stripped = line.lstrip()
    if stripped.startswith("//"):
        return
    code, optout = code_part(line)
    for rule, pattern in COMPILED:
        for m in pattern.finditer(code):
            if rule == "R-Opacity":
                value = round(float(m.group(1)), 2)
                if value in OPACITY_ALLOWED:
                    continue
            if rule == "R-Radius":
                value = float(m.group(1))
                if value < 4 or value in RADIUS_VOCAB:
                    continue
            if optout:
                continue
            out.append(f"{path_rel}:{lineno} {rule} {m.group(0).strip()}")


def scan(start: Path) -> list:
    findings = []
    files = sorted(start.rglob("*.qml")) if start.is_dir() else [start]
    for qml in files:
        try:
            rel = qml.resolve().relative_to(REPO_ROOT).as_posix()
        except ValueError:
            rel = qml.resolve().as_posix()
        if any(rel.startswith(p) for p in SKIP_DIRNAMES_PREFIX):
            continue
        if qml.name in SKIP_BASENAMES:
            continue
        try:
            text = qml.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            print(f"IO error: {rel}: {exc}", file=sys.stderr)
            sys.exit(2)
        for i, line in enumerate(text.splitlines(), 1):
            check_line(rel, i, line, findings)
    return findings


# ---------------- palette mode ----------------

def hex_to_rgb(h: str):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    if len(h) == 8:  # AARRGGBB-ish → drop alpha channel
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rel_lum(rgb) -> float:
    c = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b) -> float:
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = (max(la, lb), min(la, lb))
    return (hi + 0.05) / (lo + 0.05)


def to_hex(rgb) -> str:
    return "#" + "".join(f"{round(min(1, max(0, v)) * 255):02x}" for v in rgb)


def mix(a, b, t: float):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def fix_toward(ink, bg, floor: float):
    """Brightness-correct at constant hue+saturation; desaturate toward the
    bg's pole only when V saturates. Mirrors Theme.contrastFix."""
    if contrast(ink, bg) >= floor:
        return ink
    h, s, v = colorsys.rgb_to_hsv(*ink)
    up = rel_lum(bg) < 0.5
    v0 = max(v, 0.0001)
    cur_v = v0
    for _ in range(20):
        cur_v = min(1.0, cur_v + 0.06) if up else max(0.0, cur_v - 0.06)
        k = cur_v / v0
        cand = tuple(min(1.0, c * k) for c in ink)
        if contrast(cand, bg) >= floor:
            return cand
        if cur_v in (0.0, 1.0):
            break
    pole = hex_to_rgb("#ffffff" if up else "#000000")
    cur = ink
    for _ in range(24):
        if contrast(cur, bg) >= floor:
            return cur
        cur = mix(cur, pole, 0.08)
    return cur


def parsePalette(text: str) -> dict:
    palette = {}
    for line in text.splitlines():
        line = line.strip()
        m = re.match(r'^\$(\w+)\s*:\s*(#[0-9a-fA-F]{3,8})', line)
        if m:
            palette[m.group(1)] = hex_to_rgb(m.group(2))
    return palette


def palette_mode(path: Path) -> int:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"palette IO error: {exc}", file=sys.stderr)
        return 2
    p = parsePalette(text)
    rows, bad = [], 0

    bg = p.get("background")
    fg = p.get("foreground")
    accent = p.get("accent")
    if bg is None or fg is None:
        print("FAIL palette parsing requires $background and $foreground")
        return 1
    if contrast(fg, bg) < 4.5:
        bad += 1
        rows.append(f"FAIL base fg/bg {contrast(fg, bg):.2f} < 4.5")
    else:
        rows.append(f"ok base fg/bg {contrast(fg, bg):.2f}")

    # danger: red-band scan across the consumer slots (values are NOT hue-loyal in cwal). Narrow
    # bands need sat >= 0.30 and v >= 0.12, else a warm gray wins (measured #917f7a, sat 0.159).
    def band_pick(band, floor=0.15):
        best = None
        for i in range(1, 16):
            c = p.get(f"color{i}")
            if not c:
                continue
            h, s, v = colorsys.rgb_to_hsv(*c)
            if s < floor or v < 0.12:
                continue
            if any(lo <= h * 360 <= hi for lo, hi in band):
                cand = (contrast(c, bg), c)
                if best is None or cand[0] > best[0]:
                    best = cand
        return best[1] if best else None

    ink = band_pick([(345, 360), (0, 15)], 0.30)
    if ink is not None:
        danger = fix_toward(ink, bg, 4.5)
        rows.append(f"ok danger {to_hex(danger)} {contrast(danger, bg):.2f} (palette red)")
    else:
        c14 = p.get("color14")
        redish = False
        if c14:
            h, s, v = colorsys.rgb_to_hsv(*c14)
            redish = (h * 360 >= 330 or h * 360 <= 25) and s >= 0.30 and v >= 0.12
        if redish:
            danger = fix_toward(c14, bg, 4.5)
            rows.append(f"ok danger {to_hex(danger)} {contrast(danger, bg):.2f} (color14 red)")
        else:
            danger = fix_toward(hex_to_rgb("#ff4444"), bg, 4.5)
            rows.append(f"ok danger {to_hex(danger)} {contrast(danger, bg):.2f} (fallback)")
    if contrast(danger, bg) < 4.5:
        bad += 1
        rows.append("FAIL danger floor")

    # critical card: surface-grade fill + ink that must clear 4.5:1 on it.
    danger_surface = mix(danger, bg, 0.45)
    white = hex_to_rgb("#ffffff")
    ink_pick = white if contrast(white, danger_surface) >= contrast(fg, danger_surface) else fg
    # fix_toward mixes toward the readable pole of the SURFACE: white inks
    # toward white, fg inks toward fg.
    crit = fix_toward(ink_pick, danger_surface, 4.5)
    r = contrast(crit, danger_surface)
    rows.append(f"ok criticalFg {to_hex(crit)} {r:.2f} on dangerSurface {to_hex(danger_surface)}")
    if r < 4.5:
        bad += 1
        rows.append("FAIL criticalFg floor")
    if accent is not None:
        if contrast(accent, bg) < 3.0:
            bad += 1
            rows.append(f"FAIL accent {contrast(accent, bg):.2f} < 3.0")
        else:
            rows.append(f"ok accent {to_hex(accent)} {contrast(accent, bg):.2f}")

    # success: green-band scan over consumer slots with fallback.
    ink = band_pick([(90, 170)])
    if ink is not None:
        success = fix_toward(ink, bg, 4.5)
        rows.append(f"ok success {to_hex(success)} {contrast(success, bg):.2f} (palette green)")
    else:
        success = fix_toward(hex_to_rgb("#22c55e"), bg, 4.5)
        rows.append(f"ok success {to_hex(success)} {contrast(success, bg):.2f} (fallback green)")
    if contrast(success, bg) < 4.5:
        bad += 1
        rows.append("FAIL success floor")

    # chart ramp: rank by contrast descending, hue of the FIXED colour, greedy >=30deg separation,
    # ramp padding. Mirrors Theme._charts; v >= 0.25 keeps near-blacks (which read as ink) out.
    ramp_base = [accent or fg, mix(accent or fg, fg, 0.35), mix(accent or fg, fg, 0.65)]
    picks, used = [], []
    per = []
    for i in range(1, 16):
        c = p.get(f"color{i}")
        if not c:
            continue
        h, s, v = colorsys.rgb_to_hsv(*c)
        if s < 0.15 or v < 0.25:
            continue  # grays / near-blacks carry no usable hue identity
        fixed = fix_toward(c, bg, 3.0)
        if contrast(fixed, bg) < 3.0:
            continue  # palette slot irrecoverably close to bg
        per.append((contrast(fixed, bg), colorsys.rgb_to_hsv(*fixed)[0] * 360, fixed))
    per.sort(key=lambda t: -t[0])
    for _ratio, h, c in per:
        if all(abs((h - hu + 180) % 360 - 180) >= 30 for hu in used):
            picks.append(c)
            used.append(h)
            if len(picks) == 3:
                break
    while len(picks) < 3:
        pad = ramp_base[len(picks) % len(ramp_base)]
        picks.append(fix_toward(pad, bg, 3.0))
    for idx, c in enumerate(picks, 1):
        r = contrast(c, bg)
        rows.append(f"ok chart{idx} {to_hex(c)} {r:.2f}")
        if r < 3.0:
            bad += 1
            rows.append(f"FAIL chart{idx} floor")

    # foregroundDim: composited over bg at the discharged floor alpha.
    fg_dim = tuple(f * 0.70 + b * 0.30 for f, b in zip(fg, bg))
    r = contrast(fg_dim, bg)
    rows.append(f"ok fgDim(0.70) {to_hex(fg_dim)} {r:.2f}")
    if r < 4.5:
        bad += 1
        rows.append("FAIL fgDim floor")

    for row in rows:
        print(row)
    if bad:
        print(f"PALETTE FAIL ({bad})")
        return 1
    print("PALETTE OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("path", nargs="?", default=str(REPO_ROOT),
                    help="File or directory to scan (default: repo root).")
    ap.add_argument("--palette", metavar="COLORS.SCSS",
                    help="Palette mode: validate derivation floors instead of scanning.")
    args = ap.parse_args()

    if args.palette:
        return palette_mode(Path(args.palette))

    target = Path(args.path)
    if not target.exists():
        print(f"no such path: {target}", file=sys.stderr)
        return 2
    findings = scan(target)
    for row in findings:
        print(row)
    if findings:
        print(f"AUDIT FAIL ({len(findings)})")
        return 1
    print("AUDIT OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
