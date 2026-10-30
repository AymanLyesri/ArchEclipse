#!/usr/bin/env python3
"""Backend entry point. Argv: <provider/model> <message> <session_id>.
Key: OPENROUTER_API_KEY env (stripped, never argv). Context: JSON
{flags, attachments} drained from stdin (select-based: QML Process has no
close-stdin, so a blocking read() would hang forever).
Exits: 0 ok, 1 generic, 2 auth, 3 rate-limit, 4 context-too-long."""
import json
import os
import select
import signal
import sys
import time
import uuid
from pathlib import Path

if __name__ == "__main__" and __package__ is None:
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import requests

from chatbot.context import build_system_block, collect_info
from chatbot.providers.openrouter import API_URL, decode_sse_raw, parse_sse_line, save_history_atomic
from chatbot.providers.registry import resolve_provider
from chatbot.truncate import truncate_history

CACHE_DIR = Path.home() / ".cache" / "quickshell" / "chatbot"
MODEL_CACHE = CACHE_DIR / "models.json"

# stdin drain budget: QML writes once on started; quiet gap ends the drain.
_STDIN_FIRST_WAIT = 5.0
_STDIN_QUIET_GAP = 0.15
_STDIN_MAX_BYTES = 256 * 1024


def read_stdin_json(stdin=None, timeout: float = _STDIN_FIRST_WAIT) -> dict:
    """Drain available stdin bytes without blocking past EOF-less pipes.

    Returns {} when stdin is empty, invalid, or never produces data.
    """
    f = stdin if stdin is not None else sys.stdin
    try:
        fd = f.fileno()
    except Exception:
        return {}
    chunks: list = []
    total = 0
    deadline = time.time() + timeout
    try:
        r, _, _ = select.select([fd], [], [], timeout)
        if not r:
            return {}
        while time.time() < deadline and total < _STDIN_MAX_BYTES:
            r, _, _ = select.select([fd], [], [], _STDIN_QUIET_GAP)
            if not r:
                break
            data = os.read(fd, 65536)
            if not data:
                break
            chunks.append(data)
            total += len(data)
    except (OSError, ValueError):
        return {}
    try:
        raw = b"".join(chunks).decode("utf-8", errors="replace")
        return json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError):
        return {}


def _check_segment(seg: str, what: str) -> None:
    if not seg or seg in (".", ".."):
        raise ValueError(f"Bad path component ({what}): {seg!r}")


def safe_history_path(model: str, session_id: str) -> Path:
    """History path with traversal guard. Raises ValueError, never exits."""
    if not model or model.startswith("/"):
        raise ValueError(f"Bad model path: {model!r}")
    for seg in model.split("/"):
        _check_segment(seg, "model")
    if not session_id or "/" in session_id:
        raise ValueError(f"Bad session id: {session_id!r}")
    _check_segment(session_id, "session")
    return CACHE_DIR / "sessions" / session_id / "history.json"


def _msg(role: str, content: str, rt: int = 0) -> dict:
    return {"id": str(uuid.uuid4()), "role": role, "content": content,
            "timestamp": int(time.time() * 1000), "responseTime": rt}


def _fail(msg: str, code: int) -> "int":
    print(msg, file=sys.stderr)
    sys.exit(code)


def main() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    if len(sys.argv) < 4:
        _fail("Usage: main.py <provider/model> <message> <session_id>", 1)
    model, user_message, session_id = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        provider = resolve_provider(model)
    except ValueError as e:
        _fail(f"ERROR: {e}", 1)
    assert provider == "openrouter"
    api_key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        _fail("ERROR: HTTP 401: Missing OPENROUTER_API_KEY", 2)

    ctx = read_stdin_json()
    if not isinstance(ctx, dict):
        ctx = {}
    flags, attachments = ctx.get("flags", {}), ctx.get("attachments", [])

    try:
        path = safe_history_path(model, session_id)
    except ValueError as e:
        _fail(f"ERROR: {e}", 1)
    try:
        history = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
        if not isinstance(history, list):
            history = []
    except (json.JSONDecodeError, OSError):
        history = []
    history.append(_msg("user", user_message))
    block = build_system_block(flags, attachments,
                               {**collect_info(flags), "time": time.strftime("%Y-%m-%d %H:%M")})
    api_messages = truncate_history(
        ([{"role": "system", "content": block}] if block else [])
        + [{"role": m["role"], "content": m["content"]} for m in history])

    state = {"reply": "", "start": time.time()}

    def _save_partial():
        if state["reply"]:
            history.append(_msg("assistant", state["reply"],
                                int((time.time() - state["start"]) * 1000)))
            save_history_atomic(path, history)

    def _on_stop(signum, frame):
        try:
            _save_partial()
        finally:
            sys.stdout.flush()
            os._exit(0)

    try:
        signal.signal(signal.SIGINT, _on_stop)
        signal.signal(signal.SIGTERM, _on_stop)
    except Exception:
        pass

    def _post(payload):
        return requests.post(API_URL, headers={"Authorization": f"Bearer {api_key}",
                             "Content-Type": "application/json"},
                             json=payload, timeout=60, stream=True)

    def _send(api_messages):
        try:
            return _post({"model": model, "messages": api_messages, "stream": True})
        except requests.exceptions.Timeout:
            _fail("ERROR: Request timed out after 60 seconds", 1)
        except requests.exceptions.ConnectionError:
            _fail("ERROR: Failed to connect to API server", 1)

    resp = _send(api_messages)
    if resp.status_code == 401:
        _fail(f"ERROR: HTTP 401: {resp.text}", 2)
    if resp.status_code == 429:
        _fail(f"ERROR: HTTP 429: {resp.text}", 3)
    if resp.status_code == 400 and "context" in resp.text.lower():
        resp.close()
        api_messages = truncate_history(api_messages, max_msgs=24, max_chars=7200)
        resp = _send(api_messages)
        if resp.status_code == 401:
            _fail(f"ERROR: HTTP 401: {resp.text}", 2)
        if resp.status_code == 429:
            _fail(f"ERROR: HTTP 429: {resp.text}", 3)
        if resp.status_code != 200:
            _fail(f"ERROR: HTTP {resp.status_code}: {resp.text}", 4)
    elif resp.status_code != 200:
        _fail(f"ERROR: HTTP {resp.status_code}: {resp.text}", 1)

    mid_error = None
    for raw in resp.iter_lines(decode_unicode=False):
        if raw is None:
            continue
        # Decode UTF-8 ourselves: decode_unicode=True lets requests fall back to latin-1 when the
        # SSE response has no charset, mojibake'ing every non-ASCII token.
        kind, val = parse_sse_line(decode_sse_raw(raw))
        if kind == "content":
            state["reply"] += val
            print(val, end="", flush=True)
        elif kind == "done":
            break
        elif kind == "error":
            mid_error = val
            break
    resp.close()
    if mid_error and not state["reply"]:
        _fail(f"ERROR: {mid_error}", 1)
    if not state["reply"]:
        _fail("ERROR: Empty response from API", 1)
    history.append(_msg("assistant", state["reply"],
                        int((time.time() - state["start"]) * 1000)))
    save_history_atomic(path, history)
    sys.stdout.flush()
    if mid_error:
        _fail(f"ERROR: {mid_error}", 1)


if __name__ == "__main__":
    main()
