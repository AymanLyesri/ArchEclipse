#!/usr/bin/env python3
"""Detect the file open in the focused editor via Hyprland activewindow.

Single source of truth: imported by context.py (full dict with text) and
executed as a CLI by the QML preview label (prints path+name only).

Never fails the caller: every error degrades to {}. Never slow: the
directory walk is depth-capped and time-boxed so it cannot stall a send.
"""
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

if __name__ == "__main__" and __package__ is None:
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

_HEAD_CHARS = 8000
_WALK_DEPTH = 8
_WALK_BUDGET = 1.5
_PRUNE = {".git", "node_modules", "__pycache__", ".cache", "Cache", "CacheStorage"}
_EDITOR_CLASSES = {"com.microsoft.vscode", "code", "visual studio code", "vscodium"}


def _run(cmd: list, env, limit: int = 65536) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3, env=env)
        if out.returncode != 0:
            return ""
        return (out.stdout or "")[:limit]
    except Exception:
        return ""


def parse_editor_title(title: str, cls: str):
    """Split an editor window title into (basename, folder).

    VSCode titles look like "<file> - <folder> - … Visual Studio Code".
    Returns (None, None) for non-editor windows or unparseable titles.
    """
    if not title or (cls or "").lower() not in _EDITOR_CLASSES:
        return (None, None)
    for sep in (" \u2014 ", " - "):
        if sep in title:
            parts = [p.strip() for p in title.split(sep)]
            if len(parts) >= 2 and parts[0] and "/" not in parts[0] and parts[0] != "..":
                folder = parts[1]
                if not folder or "/" in folder or folder == "..":
                    return (None, None)
                return (parts[0], folder)
    return (None, None)


def _resolve_walk(basename: str, root: Path):
    """os.walk fallback when fd is unavailable. Newest mtime wins."""
    best = None
    deadline = time.time() + _WALK_BUDGET
    try:
        for dirpath, dirnames, filenames in os.walk(root, topdown=True):
            if time.time() > deadline:
                break
            if len(Path(dirpath).relative_to(root).parts) >= _WALK_DEPTH:
                dirnames[:] = []
                continue
            dirnames[:] = [d for d in dirnames if d not in _PRUNE]
            if basename in filenames:
                cand = Path(dirpath) / basename
                try:
                    mt = cand.stat().st_mtime
                except OSError:
                    continue
                if best is None or mt > best[0]:
                    best = (mt, str(cand))
    except Exception:
        return None
    return best[1] if best else None


def _resolve_fd(basename: str, root: Path):
    """Fast parallel find via fd. None when fd is missing or fails."""
    if not shutil.which("fd"):
        return None
    try:
        out = subprocess.run(
            ["fd", "--hidden", "--no-ignore", "--max-depth", str(_WALK_DEPTH),
             "--type", "f", "--fixed-strings",
             "--exclude", ".git", "--exclude", "node_modules",
             "--exclude", "__pycache__", basename, str(root)],
            capture_output=True, text=True, timeout=4)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    best = None
    for line in (out.stdout or "").splitlines():
        line = line.strip()
        if not line or os.path.basename(line) != basename:
            continue
        try:
            mt = os.stat(line).st_mtime
        except OSError:
            continue
        if best is None or mt > best[0]:
            best = (mt, line)
    return best[1] if best else None


def resolve_file(basename: str, folder: str, home=None):
    """Find basename under $HOME/<folder>; newest mtime wins. None on miss."""
    if (not basename or not folder or "/" in basename or basename == ".."
            or "/" in folder or folder == ".."):
        return None
    root = Path(home or str(Path.home())) / folder
    if not root.is_dir():
        return None
    return _resolve_fd(basename, root) or _resolve_walk(basename, root)


def detect_active_file(env=None, home=None) -> dict:
    """Return {"path","name","text"} for the focused editor file, else {}."""
    try:
        raw = _run(["hyprctl", "activewindow", "-j"], env)
        if not raw.strip():
            return {}
        win = json.loads(raw)
        base, folder = parse_editor_title(win.get("title", ""), win.get("class", ""))
        if not base:
            return {}
        path = resolve_file(base, folder, home or str(Path.home()))
        if not path:
            return {}
        try:
            with open(path, "rb") as f:
                head = f.read(_HEAD_CHARS)
        except (OSError, ValueError):
            return {}
        if b"\x00" in head:  # binary: never inject garbage into the prompt
            return {}
        text = head.decode("utf-8", errors="replace")
        if not text.strip():
            return {}
        return {"path": path, "name": base, "text": text[:_HEAD_CHARS]}
    except Exception:
        return {}


if __name__ == "__main__":
    got = detect_active_file()
    print(json.dumps({"path": got.get("path", ""), "name": got.get("name", "")}))
