#!/usr/bin/env python3
"""Capture live Quickshell widgets; preview by default, --replace to install."""
import argparse
import datetime
import fcntl
import json
import math
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import zlib

CONFIG = Path(__file__).resolve().parent.parent
REPO = CONFIG.parents[2]
CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "archeclipse-capture"


def shot(name, state=None, widget=None, asset=None, reason=""):
    return dict(id=name, state=state, widget=widget, asset=".github/assets/" + (asset or name + ".png"),
                supported=not reason, reason=reason)


MANIFEST = [
    shot("overview", reason="Desktop hero: compose manually; not a widget crop."),
    shot("app-launcher", "search"),
    shot("right-panel-layout-1", "right"),
    shot("right-panel-layout-2", "right"),
    shot("left-panel-chatbot", "left", "ChatBot"),
    shot("left-panel-booru-1", "left", "BooruViewer"),
    shot("left-panel-settings", "left", "SettingsWidget"),
    shot("left-panel-keybinds", "left", "KeyBinds"),
    shot("wallpaper-switcher", "wallpaper"),
    shot("workspace-overview", "overview"),
    shot("dark-theme", reason="Whole-desktop theme showcase: manual; no global theme changes."),
    shot("light-theme", reason="Whole-desktop theme showcase: manual; no global theme changes."),
    shot("lock-screen", reason="Secure lock screen: capture manually; never locks automatically."),
]


def select_shots(only):
    if not only:
        return [s for s in MANIFEST if s["supported"]]
    names = list(dict.fromkeys(x.strip() for x in only.split(",") if x.strip()))
    by_id = {s["id"]: s for s in MANIFEST}
    if not names or any(n not in by_id for n in names):
        raise ValueError("Unknown/empty selection; see --list")
    return [by_id[n] for n in names]


def assert_all_supported(shots):
    for s in shots:
        if not s["supported"]:
            raise RuntimeError(s["id"] + ": " + s["reason"])


def run(cmd, timeout=10):
    try:
        return subprocess.run([str(x) for x in cmd], capture_output=True, text=True,
                              timeout=timeout, check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError) as e:
        raise RuntimeError(f"Command failed: {cmd}: {getattr(e, 'stderr', '') or e}") from e


def capture_ipc(action, *args):
    text = run(["qs", "-p", CONFIG, "ipc", "call", "capture", action, *args])
    try:
        result = json.loads(text)
        if not result.get("ok"):
            raise ValueError(result.get("error", "capture helper failed"))
        return result
    except (ValueError, AttributeError) as e:
        raise RuntimeError(f"capture {action}: {text}") from e


def parse_focused_monitor(text):
    monitors = json.loads(text)
    focused = [m for m in monitors if m.get("focused") and not m.get("disabled")]
    if len(focused) != 1:
        raise RuntimeError("Expected one focused monitor")
    return focused[0]


def parse_quickshell_layer(text, monitor):
    levels = json.loads(text).get(monitor, {}).get("levels", {})
    layers = [e for entries in levels.values() for e in entries
              if e.get("namespace") == "quickshell"]
    if len(layers) != 1:
        raise RuntimeError("Expected exactly one quickshell surface on " + monitor)
    rect = {k: int(layers[0][k]) for k in ("x", "y", "w", "h")}
    if rect["w"] <= 0 or rect["h"] <= 0:
        raise RuntimeError("Invalid layer geometry")
    if isinstance(layers[0].get("alpha"), (int, float)) and layers[0]["alpha"] <= 0:
        # Do not accept a wallpaper-only crop as a widget screenshot.
        raise RuntimeError("Quickshell surface reports alpha 0; wait for compositor visibility or restart the shell")
    return rect


def pill_rect(layer, status):
    r = status["rect"]
    x, y = math.floor(r["x"]), math.floor(r["y"])
    w, h = math.ceil(r["x"] + r["w"]) - x, math.ceil(r["y"] + r["h"]) - y
    if not status["visible"] or min(w, h) <= 0 or min(x, y) < 0 or x+w > layer["w"] or y+h > layer["h"]:
        raise RuntimeError("Pill hidden or outside its surface")
    return dict(x=layer["x"] + x, y=layer["y"] + y, w=w, h=h)


def build_grim_args(rect, out_path):
    # Layer and QML coordinates are logical. -s 1 makes PNG dimensions match.
    return ["grim", "-s", "1", "-g", "{x},{y} {w}x{h}".format(**rect), "-t", "png", str(out_path)]


def validate_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError("Not PNG: " + str(path))
    pos, dims, end, packed = 8, None, False, bytearray()
    while pos + 12 <= len(data):
        size = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos+4:pos+8]
        body = data[pos+8:pos+8+size]
        if pos + size + 12 > len(data):
            raise RuntimeError("Truncated PNG chunk")
        crc = struct.unpack_from(">I", data, pos+8+size)[0]
        if crc != zlib.crc32(kind + body):
            raise RuntimeError("PNG CRC mismatch")
        if dims is None:
            if kind != b"IHDR" or size != 13:
                raise RuntimeError("PNG missing IHDR")
            w, h, depth, color, comp, filt, interlace = struct.unpack(">IIBBBBB", body)
            if not (0 < w <= 16384 and 0 < h <= 16384) or depth != 8 or color not in (2, 6) or comp or filt or interlace:
                raise RuntimeError("Unsupported PNG format (expected grim RGB/RGBA8)")
            dims = w, h
            stride = w * (3 if color == 2 else 4) + 1
        elif kind == b"IDAT":
            packed.extend(body)
        elif kind == b"IEND":
            end = size == 0 and pos+12 == len(data)
            break
        pos += size + 12
    if not dims or not end or not packed:
        raise RuntimeError("PNG incomplete")
    try:
        decoder = zlib.decompressobj()
        raw = decoder.decompress(packed, stride * dims[1] + 1)
        if not decoder.eof or decoder.unused_data or len(raw) != stride * dims[1]:
            raise RuntimeError("PNG pixel stream incomplete")
        if any(raw[i] > 4 for i in range(0, len(raw), stride)):
            raise RuntimeError("Invalid PNG row filter")
    except zlib.error as e:
        raise RuntimeError("Invalid PNG compression") from e
    return dims


def atomic_copy(src, dest):
    dest = Path(dest)
    fd, tmp = tempfile.mkstemp(prefix=".capture-", dir=dest.parent)
    os.close(fd)
    try:
        shutil.copy2(src, tmp)
        os.replace(tmp, dest)
    finally:
        Path(tmp).unlink(missing_ok=True)


def install_validated(shots, repo_root, readme_path, backup_root, allow_gif_to_png=False):
    repo_root, readme_path, backup_root = Path(repo_root), Path(readme_path), Path(backup_root)
    for s in shots:
        validate_png(s["src"])
        dest = repo_root / s["asset"]
        if dest.parent.resolve() != (repo_root / ".github/assets").resolve():
            raise RuntimeError("Asset outside README image directory")
        if not dest.parent.is_dir():
            raise RuntimeError("Missing README asset directory")
    old_readme = readme_path.read_text()
    new_readme = old_readme
    if any(s["id"] == "workspace-overview" for s in shots):
        if not allow_gif_to_png:
            raise RuntimeError("Overview GIF reference update not permitted")
        new_readme = new_readme.replace(".github/assets/workspace-overview.gif", ".github/assets/workspace-overview.png")
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix=datetime.datetime.now().strftime("%Y%m%d-%H%M%S-"), dir=backup_root))
    shutil.copy2(readme_path, backup / "README.md")
    destinations = [(repo_root / s["asset"], Path(s["src"]), backup / s["asset"]) for s in shots]
    # Back up ALL destinations before installing any.
    for dest, src, saved in destinations:
        saved.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists():
            shutil.copy2(dest, saved)
    touched = []
    readme_touched = False
    try:
        for dest, src, saved in destinations:
            touched.append((dest, saved))
            atomic_copy(src, dest)
        if new_readme != old_readme:
            stage = backup / "README.new"
            stage.write_text(new_readme)
            readme_touched = True
            atomic_copy(stage, readme_path)
    except BaseException:
        failures = []
        for dest, saved in reversed(touched):
            try:
                if saved.exists():
                    atomic_copy(saved, dest)
                else:
                    dest.unlink(missing_ok=True)
            except OSError as e:
                failures.append(str(e))
        if readme_touched:
            try:
                atomic_copy(backup / "README.md", readme_path)
            except OSError as e:
                failures.append(str(e))
        if failures:
            raise RuntimeError(f"Rollback incomplete; originals in {backup}: {failures}")
        raise
    return str(backup)


def capture_supported_shot(shot, monitor, out_path, settle=1.0, timeout=30):
    capture_ipc("select", shot["id"])
    deadline, stable_since, previous = time.monotonic() + timeout, None, None
    while time.monotonic() < deadline:
        status = capture_ipc("status")  # refreshes finite capture lease
        ready = status.get("ready") and status.get("state") == shot["state"]
        rect = None
        if ready:
            try:
                layer = parse_quickshell_layer(run(["hyprctl", "layers", "-j"]), monitor)
                rect = pill_rect(layer, status)
            except RuntimeError:
                ready = False
        if ready and rect == previous:
            stable_since = stable_since or time.monotonic()
            if time.monotonic() - stable_since >= settle:
                break
        else:
            stable_since = None
        previous = rect
        time.sleep(0.2)
    else:
        raise RuntimeError("Timed out waiting for " + shot["id"] + ": " + json.dumps(status))
    run(build_grim_args(rect, out_path), timeout=10)
    w, h = validate_png(out_path)
    after = capture_ipc("status")
    layer_after = parse_quickshell_layer(run(["hyprctl", "layers", "-j"]), monitor)
    if not after.get("ready") or after.get("state") != shot["state"] or pill_rect(layer_after, after) != rect or (w, h) != (rect["w"], rect["h"]):
        raise RuntimeError("Widget changed during capture; refusing image")
    return dict(w=w, h=h)


def capture_run(args, monitor, out_dir):
    shots = select_shots(args.only)
    staged = []
    capture_ipc("begin", monitor)
    try:
        for s in shots:
            dest = Path(out_dir) / Path(s["asset"]).name
            print("Capturing " + s["id"], flush=True)
            info = capture_supported_shot(s, monitor, dest, args.settle, args.timeout)
            print(f"  {info['w']}x{info['h']} -> {dest}", flush=True)
            staged.append(dict(id=s["id"], asset=s["asset"], src=str(dest)))
    finally:
        restored = capture_ipc("end")
        print("Restored shell: " + json.dumps(restored), flush=True)
    # Restoration MUST succeed before files in the repo can change.
    if args.replace:
        backup = install_validated(staged, REPO, REPO / "README.md", CACHE / "backups", allow_gif_to_png=True)
        print("Replaced README pictures. Backup: " + backup)
    return staged


def parse_cli(argv):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--only", default="", help="comma-separated IDs; default all supported")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--output-dir", help="preview directory (cannot combine with --replace)")
    ap.add_argument("--replace", action="store_true", help="capture and replace local README assets with backups")
    ap.add_argument("--settle", type=float, default=1, help="stable-layout delay, seconds (default 1)")
    ap.add_argument("--timeout", type=float, default=30, help="per-widget readiness timeout, seconds")
    args = ap.parse_args(argv)
    if args.output_dir and args.replace:
        ap.error("--output-dir is preview-only")
    if args.settle < 0.5 or args.timeout <= args.settle:
        ap.error("settle must be >=0.5; timeout must exceed settle")
    return args


def main(argv=None):
    args = parse_cli(argv)
    if args.list:
        for s in MANIFEST:
            print(f"{s['id']}: {s['asset']}" + ("" if s['supported'] else " [manual: " + s['reason'] + "]"))
        return 0
    try:
        shots = select_shots(args.only)
        assert_all_supported(shots)
        if not args.only:
            for s in MANIFEST:
                if not s["supported"]:
                    print("Skipping " + s["id"] + ": " + s["reason"])
        print("Live content may contain private chats, notifications, API keys or window previews. Review before publishing. No upload/commit.", flush=True)
        if args.dry_run:
            for s in shots:
                print(s["id"] + " -> " + s["asset"])
            return 0
        CACHE.mkdir(parents=True, exist_ok=True)
        with (CACHE / "capture.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            monitor = parse_focused_monitor(run(["hyprctl", "monitors", "-j"]))["name"]
            if args.output_dir:
                out = Path(args.output_dir).expanduser().resolve()
                out.mkdir(parents=True, exist_ok=True)
                if out == (REPO / ".github/assets").resolve():
                    raise RuntimeError("Use --replace to write README assets")
                if any((out / Path(s["asset"]).name).exists() for s in shots):
                    raise RuntimeError("Preview files already exist; choose a fresh directory")
            else:
                out = Path(tempfile.mkdtemp(prefix="preview-", dir=CACHE))
            def interrupted(signum, frame):
                raise KeyboardInterrupt
            old = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGINT, signal.SIGTERM)}
            try:
                capture_run(args, monitor, out)
            finally:
                for sig, handler in old.items():
                    signal.signal(sig, handler)
            print("Captures: " + str(out))
        return 0
    except (RuntimeError, ValueError, OSError, KeyboardInterrupt) as e:
        print("ERROR: " + (str(e) or "Interrupted; capture cancelled"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
