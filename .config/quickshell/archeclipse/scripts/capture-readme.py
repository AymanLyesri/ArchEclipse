#!/usr/bin/env python3
"""Capture live Quickshell widgets; replaces README assets by default, --no-replace to preview."""

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
CACHE = (
    Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    / "archeclipse-capture"
)
# Captures always run on this workspace so open windows never leak into shots.
# Workspace 10 is empty by default; dispatching to it creates it when missing.
CAPTURE_WORKSPACE_ID = 10
# Settle after the workspace switch before any wallpaper change: the switch
# itself triggers the wallpaper daemon to reapply ws10's own entry plus the
# slide animation, so applying immediately races the daemon and captures
# a half-faded wallpaper.
WORKSPACE_SETTLE = 2.0

# ArchEclipse Overview hero floats, measured from the live ws10 reference
# placement (absolute monitor pixels on the 1920x1080 output).
OVERVIEW_FLOATS = [
    dict(cmd=["kitty", "-o", "font_size=9"], x=935, y=580, w=1091, h=469),
    dict(cmd=["kitty", "-o", "font_size=9", "-e", "cava"], x=1184, y=389, w=652, h=161),
]


def shot(
    name, state=None, widget=None, asset=None, reason="", fullscreen=False, wallpaper=""
):
    return dict(
        id=name,
        state=state,
        widget=widget,
        asset=".github/assets/" + (asset or name + ".png"),
        supported=not reason,
        reason=reason,
        fullscreen=fullscreen,
        wallpaper=wallpaper,
    )


# app-launcher, control-panel, workspace-overview and wallpaper-switcher read
# best as full monitor shots (wallpaper + island in context); the rest stay
# pill crops.
# Per-shot wallpaper: image path or http(s) URL, applied live for that shot
# (falls back to --wallpaper); restored afterwards. Keep "" to skip.
MANIFEST = [
    shot(
        "overview",
        "player",
        fullscreen=True,
        wallpaper="/home/ayman/.config/wallpapers/defaults/images_nsfw/__gwen_irelia_galio_and_mythmaker_gwen_league_of_legends_drawn_by_shen_fan__5620a8c6ea0f208f5b89d65a6c39b418.jpg",
    ),
    shot(
        "app-launcher",
        "search",
        fullscreen=True,
        wallpaper="/home/ayman/.config/wallpapers/defaults/images_nsfw/__ciel_kamitsubaki_studio_drawn_by_shirone_coxo_ii__e659fcfcb737cccce99c1f7ebdc34f2e.jpg",
    ),
    shot("right-panel-layout-1", "right", wallpaper=""),
    shot("right-panel-layout-2", "right", wallpaper=""),
    shot(
        "control-panel",
        "control",
        fullscreen=True,
        wallpaper="/home/ayman/.config/wallpapers/defaults/images_nsfw/__hakuhou_azur_lane_drawn_by_yunsang__41349e7a65cb2c05b04c22df5580a316.png",
    ),
    shot("left-panel-chatbot", "left", "ChatBot", wallpaper=""),
    shot("left-panel-booru-1", "left", "BooruViewer", wallpaper=""),
    shot("left-panel-settings", "left", "SettingsWidget", wallpaper=""),
    shot("left-panel-keybinds", "left", "KeyBinds", wallpaper=""),
    shot(
        "wallpaper-switcher",
        "wallpaper",
        fullscreen=True,
        wallpaper="/home/ayman/.config/wallpapers/defaults/images_nsfw/__prinz_moritz_azur_lane__3c7795af9ae9b14715a33c33eb584651.png",
    ),
    shot(
        "workspace-overview",
        "overview",
        fullscreen=True,
        wallpaper="/home/ayman/.config/wallpapers/defaults/images_nsfw/__iori_and_iori_blue_archive_drawn_by_dizzen__7c56e7e702806ceaac863b9b0d210b17.png",
    ),
    shot(
        "dark-theme",
        reason="Whole-desktop theme showcase: manual; no global theme changes.",
    ),
    shot(
        "light-theme",
        reason="Whole-desktop theme showcase: manual; no global theme changes.",
    ),
    shot(
        "lock-screen",
        reason="Secure lock screen: capture manually; never locks automatically.",
    ),
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
        return subprocess.run(
            [str(x) for x in cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError) as e:
        raise RuntimeError(
            f"Command failed: {cmd}: {getattr(e, 'stderr', '') or e}"
        ) from e


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


def parse_active_workspace(text):
    info = json.loads(text)
    workspace_id = info.get("id")
    if not isinstance(workspace_id, int):
        raise RuntimeError("Unexpected active workspace: " + text[:200])
    return workspace_id


def ensure_workspace(workspace_id, timeout=10):
    # Hyprland Lua config evaluates dispatch args as Lua: raw `workspace 10`
    # fails, the `hl.dsp.focus` dispatcher works (cf. Workspaces.qml).
    run(
        ["hyprctl", "dispatch", f"hl.dsp.focus({{workspace = {workspace_id}}})"],
        timeout=10,
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if (
            parse_active_workspace(run(["hyprctl", "activeworkspace", "-j"]))
            == workspace_id
        ):
            return
        time.sleep(0.2)
    raise RuntimeError(f"Workspace {workspace_id} did not become active")


def parse_monitor_rect(text, monitor):
    monitors = json.loads(text)
    matches = [m for m in monitors if m.get("name") == monitor]
    if len(matches) != 1:
        raise RuntimeError("Monitor not found: " + monitor)
    m = matches[0]
    rect = {
        "x": int(m["x"]),
        "y": int(m["y"]),
        "w": int(m["width"]),
        "h": int(m["height"]),
    }
    if rect["w"] <= 0 or rect["h"] <= 0:
        raise RuntimeError("Invalid monitor geometry")
    return rect


def resolve_wallpaper(url):
    """Image path or http(s) URL -> local image path (URLs download into cache)."""
    if url.startswith("http://") or url.startswith("https://"):
        import hashlib
        import urllib.parse
        import urllib.request

        ext = Path(urllib.parse.urlparse(url).path).suffix.lower() or ".jpg"
        dest = (
            CACHE / "wallpapers" / (hashlib.sha256(url.encode()).hexdigest()[:16] + ext)
        )
        if not dest.is_file():
            dest.parent.mkdir(parents=True, exist_ok=True)
            try:
                with urllib.request.urlopen(url, timeout=30) as response, open(
                    dest, "wb"
                ) as out:
                    shutil.copyfileobj(response, out)
            except OSError as e:
                raise RuntimeError(f"Wallpaper download failed: {url}: {e}") from e
        return str(dest)
    path = Path(url).expanduser()
    if not path.is_file():
        raise RuntimeError("Wallpaper not found: " + url)
    return str(path)


def parse_active_wallpaper(text, monitor):
    # WallEclipse: `walleclipse current` prints the last-applied path
    # (monitor arg kept for call-site compatibility).
    del monitor
    return text.strip() or None


def workspace_mapping(monitor, workspace):
    # Saved per-workspace mapping from `walleclipse list`
    # ("<monitor> <ws> <path>" per line); None when unmapped.
    for line in run(["walleclipse", "list"]).splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3 and parts[0] == monitor and parts[1] == str(workspace):
            return parts[2].strip() or None
    return None


def apply_wallpaper(monitor, path, workspace=CAPTURE_WORKSPACE_ID, timeout=15, settle=4.0):
    # WallEclipse `set` updates the workspace mapping AND shows immediately
    # (replaces `hyprctl hyprpaper wallpaper`, which was live-only).
    # Callers save/restore the mapping around capture runs.
    run(["walleclipse", "set", monitor, str(workspace), path], timeout=10)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if parse_active_wallpaper(run(["walleclipse", "current"]), monitor) == path:
            break
        time.sleep(0.5)
    else:
        raise RuntimeError("Wallpaper did not apply: " + path)
    # Decoded-at-startup means no upload lag, but keep a short settle so
    # compositor animations finish before any capture may proceed.
    time.sleep(settle)


def parse_quickshell_layer(text, monitor):
    levels = json.loads(text).get(monitor, {}).get("levels", {})
    layers = [
        e
        for entries in levels.values()
        for e in entries
        if e.get("namespace") == "quickshell"
    ]
    if len(layers) != 1:
        raise RuntimeError("Expected exactly one quickshell surface on " + monitor)
    rect = {k: int(layers[0][k]) for k in ("x", "y", "w", "h")}
    if rect["w"] <= 0 or rect["h"] <= 0:
        raise RuntimeError("Invalid layer geometry")
    if isinstance(layers[0].get("alpha"), (int, float)) and layers[0]["alpha"] <= 0:
        # Do not accept a wallpaper-only crop as a widget screenshot.
        raise RuntimeError(
            "Quickshell surface reports alpha 0; wait for compositor visibility or restart the shell"
        )
    return rect


def pill_rect(layer, status):
    r = status["rect"]
    x, y = math.floor(r["x"]), math.floor(r["y"])
    w, h = math.ceil(r["x"] + r["w"]) - x, math.ceil(r["y"] + r["h"]) - y
    if (
        not status["visible"]
        or min(w, h) <= 0
        or min(x, y) < 0
        or x + w > layer["w"]
        or y + h > layer["h"]
    ):
        raise RuntimeError("Pill hidden or outside its surface")
    return dict(x=layer["x"] + x, y=layer["y"] + y, w=w, h=h)


def build_grim_args(rect, out_path):
    # Layer and QML coordinates are logical. -s 1 makes PNG dimensions match.
    return [
        "grim",
        "-s",
        "1",
        "-g",
        "{x},{y} {w}x{h}".format(**rect),
        "-t",
        "png",
        str(out_path),
    ]


def validate_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError("Not PNG: " + str(path))
    pos, dims, end, packed = 8, None, False, bytearray()
    while pos + 12 <= len(data):
        size = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + size]
        if pos + size + 12 > len(data):
            raise RuntimeError("Truncated PNG chunk")
        crc = struct.unpack_from(">I", data, pos + 8 + size)[0]
        if crc != zlib.crc32(kind + body):
            raise RuntimeError("PNG CRC mismatch")
        if dims is None:
            if kind != b"IHDR" or size != 13:
                raise RuntimeError("PNG missing IHDR")
            w, h, depth, color, comp, filt, interlace = struct.unpack(">IIBBBBB", body)
            if (
                not (0 < w <= 16384 and 0 < h <= 16384)
                or depth != 8
                or color not in (2, 6)
                or comp
                or filt
                or interlace
            ):
                raise RuntimeError("Unsupported PNG format (expected grim RGB/RGBA8)")
            dims = w, h
            stride = w * (3 if color == 2 else 4) + 1
        elif kind == b"IDAT":
            packed.extend(body)
        elif kind == b"IEND":
            end = size == 0 and pos + 12 == len(data)
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


def install_validated(
    shots, repo_root, readme_path, backup_root, allow_gif_to_png=False
):
    repo_root, readme_path, backup_root = (
        Path(repo_root),
        Path(readme_path),
        Path(backup_root),
    )
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
        new_readme = new_readme.replace(
            ".github/assets/workspace-overview.gif",
            ".github/assets/workspace-overview.png",
        )
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(
        tempfile.mkdtemp(
            prefix=datetime.datetime.now().strftime("%Y%m%d-%H%M%S-"), dir=backup_root
        )
    )
    shutil.copy2(readme_path, backup / "README.md")
    destinations = [
        (repo_root / s["asset"], Path(s["src"]), backup / s["asset"]) for s in shots
    ]
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
            raise RuntimeError(
                f"Rollback incomplete; originals in {backup}: {failures}"
            )
        raise
    return str(backup)


def _ws_clients(workspace):
    try:
        clients = json.loads(run(["hyprctl", "clients", "-j"]))
    except RuntimeError:
        return []
    return [c for c in clients if c.get("workspace", {}).get("id") == workspace]


def _wait_for(pred, timeout=15, interval=0.3):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = pred()
        if value:
            return value
        time.sleep(interval)
    return None


def setup_overview_windows(workspace=CAPTURE_WORKSPACE_ID, timeout=15):
    """Recreate the hero floats at their reference rects; return spawn pids."""
    for c in _ws_clients(workspace):
        try:
            os.kill(int(c["pid"]), signal.SIGTERM)
        except (OSError, KeyError, ValueError):
            pass
    if not _wait_for(lambda: not _ws_clients(workspace), timeout=timeout):
        raise RuntimeError("Workspace 10 did not empty for overview setup")
    seen = set()
    spawned = []
    for f in OVERVIEW_FLOATS:
        rule = (
            f"[float; move {f['x']} {f['y']}; size {f['w']} {f['h']}; "
            f"workspace {workspace}] " + " ".join(f["cmd"])
        )
        run(["hyprctl", "dispatch", f"hl.dsp.exec_cmd('{rule}')"])

        def mapped():
            found = [
                c
                for c in _ws_clients(workspace)
                if c.get("class") == "kitty" and int(c["pid"]) not in seen
            ]
            return found or None

        found = _wait_for(mapped, timeout=timeout)
        if not found:
            raise RuntimeError("Overview window did not map: " + " ".join(f["cmd"]))
        # Newest unmatched kitty client is this spawn (sequential spawns).
        target = max(found, key=lambda c: int(c["pid"]))
        seen.add(int(target["pid"]))
        spawned.append(int(target["pid"]))
        if (
            list(target.get("at", [])) != [f["x"], f["y"]]
            or list(target.get("size", [])) != [f["w"], f["h"]]
            or not target.get("floating")
        ):
            raise RuntimeError(
                "Overview window misplaced: " + json.dumps(target.get("at"))
            )
    # Apply pywal using the workspace-overview wallpaper (dynamic from manifest).
    overview_wallpaper = next(
        (s.get("wallpaper") for s in MANIFEST if s.get("id") == "overview"),
        "",
    )
    try:
        if overview_wallpaper:
            run(["cwal", "-i", overview_wallpaper])
            print(
                "Applied pywal for overview windows: " + overview_wallpaper, flush=True
            )
    except RuntimeError as e:
        print("WARNING: pywal failed: " + str(e), flush=True)
    return spawned


def teardown_overview_windows(pids, timeout=10):
    for pid in pids:
        try:
            os.kill(int(pid), signal.SIGTERM)
        except (OSError, ValueError):
            pass
    _wait_for(
        lambda: not any(
            int(c.get("pid", -1)) in set(int(p) for p in pids)
            for c in _ws_clients(CAPTURE_WORKSPACE_ID)
        ),
        timeout=timeout,
    )


def capture_supported_shot(shot, monitor, out_path, settle=1.0, timeout=30):
    capture_ipc("select", shot["id"])
    deadline, stable_since, previous = time.monotonic() + timeout, None, None
    while time.monotonic() < deadline:
        status = capture_ipc("status")  # refreshes finite capture lease
        ready = status.get("ready") and status.get("state") == shot["state"]
        pill = None
        if ready:
            try:
                layer = parse_quickshell_layer(
                    run(["hyprctl", "layers", "-j"]), monitor
                )
                pill = pill_rect(layer, status)
            except RuntimeError:
                ready = False
        if ready and pill == previous:
            stable_since = stable_since or time.monotonic()
            if time.monotonic() - stable_since >= settle:
                break
        else:
            stable_since = None
        previous = pill
        time.sleep(0.2)
    else:
        raise RuntimeError(
            "Timed out waiting for " + shot["id"] + ": " + json.dumps(status)
        )
    if shot.get("fullscreen"):
        # Full monitor output (wallpaper + island in context), not a pill crop.
        rect = parse_monitor_rect(run(["hyprctl", "monitors", "-j"]), monitor)
    else:
        rect = previous
    run(build_grim_args(rect, out_path), timeout=10)
    w, h = validate_png(out_path)
    after = capture_ipc("status")
    layer_after = parse_quickshell_layer(run(["hyprctl", "layers", "-j"]), monitor)
    if (
        not after.get("ready")
        or after.get("state") != shot["state"]
        or pill_rect(layer_after, after) != previous
        or (w, h) != (rect["w"], rect["h"])
    ):
        raise RuntimeError("Widget changed during capture; refusing image")
    return dict(w=w, h=h)


def capture_run(args, monitor, out_dir, workspace=CAPTURE_WORKSPACE_ID, wallpaper=None):
    wallpaper = wallpaper if wallpaper is not None else args.wallpaper
    workspace_settle = getattr(args, "workspace_settle", WORKSPACE_SETTLE)
    shots = select_shots(args.only)
    staged = []
    wallpaper_path = None
    previous_wallpaper = None
    saved_mapping = None
    applied_wallpaper = None
    want_wallpaper = wallpaper or any(s.get("wallpaper") for s in shots)
    if want_wallpaper:
        # Read before the workspace switch: the wallpaper currently shown
        # plus the capture workspace's saved mapping (WallEclipse `set`
        # writes the mapping, so it must be restored afterwards).
        previous_wallpaper = parse_active_wallpaper(
            run(["walleclipse", "current"]), monitor
        )
        saved_mapping = workspace_mapping(monitor, workspace)
    previous = None
    if workspace is not None:
        previous = parse_active_workspace(run(["hyprctl", "activeworkspace", "-j"]))
        if previous != workspace:
            print(f"Switching to workspace {workspace} for captures", flush=True)
            ensure_workspace(workspace)
            # Let the compositor slide animation and the wallpaper daemon's
            # ws10 reapply finish before any per-shot wallpaper change.
            if workspace_settle > 0:
                print(
                    f"Waiting {workspace_settle:g}s after workspace switch",
                    flush=True,
                )
                time.sleep(workspace_settle)
    try:
        capture_ipc("begin", monitor)
        overview_pids = []
        try:
            if any(s["id"] == "overview" for s in shots):
                print("Staging overview floats on workspace 10", flush=True)
                overview_pids = setup_overview_windows(
                    workspace or CAPTURE_WORKSPACE_ID
                )
            for s in shots:
                raw = s.get("wallpaper") or wallpaper
                if raw:
                    wallpaper_path = resolve_wallpaper(raw)
                    # First wallpaper of the run always applies: the workspace
                    # switch itself changes the live wallpaper (the daemon
                    # reapplies ws10's own entry), so the pre-switch state
                    # can't be trusted for skip decisions. Later shots skip
                    # when the same wallpaper is already applied.
                    if applied_wallpaper is None or wallpaper_path != applied_wallpaper:
                        print(f"Setting wallpaper for {s['id']}", flush=True)
                        apply_wallpaper(monitor, wallpaper_path)
                        applied_wallpaper = wallpaper_path
                dest = Path(out_dir) / Path(s["asset"]).name
                print("Capturing " + s["id"], flush=True)
                info = capture_supported_shot(
                    s, monitor, dest, args.settle, args.timeout
                )
                print(f"  {info['w']}x{info['h']} -> {dest}", flush=True)
                staged.append(dict(id=s["id"], asset=s["asset"], src=str(dest)))
        finally:
            if overview_pids:
                teardown_overview_windows(overview_pids)
            restored = capture_ipc("end")
            print("Restored shell: " + json.dumps(restored), flush=True)
    finally:
        if workspace is not None and previous is not None and previous != workspace:
            try:
                ensure_workspace(previous)
            except RuntimeError as e:
                print("WARNING: " + str(e), flush=True)
        if (
            applied_wallpaper
            and previous_wallpaper
            and applied_wallpaper != previous_wallpaper
        ):
            try:
                if saved_mapping:
                    apply_wallpaper(monitor, saved_mapping)
                else:
                    print(
                        "WARNING: no saved mapping for "
                        f"{monitor} ws{workspace}, leaving capture wallpaper"
                    )
            except RuntimeError as e:
                print("WARNING: " + str(e), flush=True)
    # Restoration MUST succeed before files in the repo can change.
    if args.replace:
        backup = install_validated(
            staged, REPO, REPO / "README.md", CACHE / "backups", allow_gif_to_png=True
        )
        print("Replaced README pictures. Backup: " + backup)
    return staged


def parse_cli(argv):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--list", action="store_true")
    ap.add_argument(
        "--only", default="", help="comma-separated IDs; default all supported"
    )
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument(
        "--output-dir", help="preview directory (preview-only, skips --replace)"
    )
    ap.add_argument(
        "--replace",
        dest="replace",
        action="store_true",
        default=True,
        help="capture and replace local README assets with backups (default: on)",
    )
    ap.add_argument(
        "--no-replace",
        dest="replace",
        action="store_false",
        help="preview only; do not touch README assets",
    )
    ap.add_argument(
        "--settle",
        type=float,
        default=1,
        help="stable-layout delay, seconds (default 1)",
    )
    ap.add_argument(
        "--timeout",
        type=float,
        default=30,
        help="per-widget readiness timeout, seconds",
    )
    ap.add_argument(
        "--wallpaper",
        default="",
        help="image path or http(s) URL set live for the run; restored afterwards",
    )
    ap.add_argument(
        "--workspace-settle",
        type=float,
        default=WORKSPACE_SETTLE,
        help="delay after switching to workspace 10 before changing wallpaper, seconds (default 2)",
    )
    args = ap.parse_args(argv)
    if args.output_dir and "--replace" in (argv or []):
        ap.error("--output-dir is preview-only (drop --replace or use --no-replace)")
    if args.output_dir:
        # Explicit preview dir implies no install.
        args.replace = False
    if args.workspace_settle < 0 or args.timeout <= args.settle:
        ap.error("settle must be >=0.5; timeout must exceed settle")
    return args


def main(argv=None):
    args = parse_cli(argv)
    if args.list:
        for s in MANIFEST:
            print(
                f"{s['id']}: {s['asset']}"
                + ("" if s["supported"] else " [manual: " + s["reason"] + "]")
            )
        return 0
    try:
        shots = select_shots(args.only)
        assert_all_supported(shots)
        if not args.only:
            for s in MANIFEST:
                if not s["supported"]:
                    print("Skipping " + s["id"] + ": " + s["reason"])
        print(
            "Live content may contain private chats, notifications, API keys or window previews. Review before publishing. No upload/commit.",
            flush=True,
        )
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
                    raise RuntimeError(
                        "Do not use --output-dir for README assets; run without it to auto-replace"
                    )
                if any((out / Path(s["asset"]).name).exists() for s in shots):
                    raise RuntimeError(
                        "Preview files already exist; choose a fresh directory"
                    )
            else:
                out = Path(tempfile.mkdtemp(prefix="preview-", dir=CACHE))

            def interrupted(signum, frame):
                raise KeyboardInterrupt

            old = {
                sig: signal.signal(sig, interrupted)
                for sig in (signal.SIGINT, signal.SIGTERM)
            }
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
