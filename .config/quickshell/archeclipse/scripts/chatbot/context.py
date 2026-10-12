"""Minimal+explicit system context. Never fails the send: every source degrades to ''."""
import shutil
import subprocess

from chatbot.activefile import detect_active_file

_WS_ON, _WIN_ON, _CLIP_ON, _FILE_ON = True, True, True, True


def _run(cmd: list, limit: int = 1000) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        if out.returncode != 0:
            return ""
        return (out.stdout or "")[:limit]
    except Exception:
        return ""


def collect_info(flags: dict) -> dict:
    info: dict = {}
    if flags.get("ws", _WS_ON) and shutil.which("hyprctl"):
        info["ws"] = _run(["hyprctl", "activeworkspace", "-j"], 500).strip()
    if flags.get("win", _WIN_ON) and shutil.which("hyprctl"):
        info["win"] = _run(["hyprctl", "activewindow", "-j"], 800).strip()
    if flags.get("clip", _CLIP_ON) and shutil.which("wl-paste"):
        info["clip"] = _run(["wl-paste", "--no-newline"], 1000)
    if flags.get("file", _FILE_ON):
        info["activefile"] = detect_active_file()
    return info


def build_system_block(flags: dict, attachments: list, info: dict | None = None) -> str:
    info = info if info is not None else collect_info(flags)
    parts: list = []
    if info.get("ws"):
        parts.append(f"[workspace] {info['ws']}")
    if info.get("win"):
        parts.append(f"[focused window] {info['win']}")
    if info.get("clip"):
        parts.append(f"[clipboard] {info['clip']}")
    if info.get("time"):
        parts.append(f"[time] {info['time']}")
    if flags.get("file", _FILE_ON):
        af = info.get("activefile")
        if isinstance(af, dict) and af.get("path") and af.get("text"):
            parts.append(f"[active file {af['path']}]\n{str(af['text'])[:8000]}")
    for a in attachments or []:
        name = str(a.get("name", "attachment"))[:120]
        text = str(a.get("text", ""))[:8000]
        if text:
            parts.append(f"[file {name}]\n{text}")
    if not parts:
        return ""
    return "System context (user-approved, may be stale):\n" + "\n".join(parts)
