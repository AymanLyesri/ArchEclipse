import json

API_URL = "https://openrouter.ai/api/v1/chat/completions"
MODELS_URL = "https://openrouter.ai/api/v1/models"


def decode_sse_raw(raw) -> str:
    """Decode one SSE chunk from iter_lines(decode_unicode=False).

    The stream is always UTF-8 (JSON). Decoding as bytes ourselves
    avoids requests' latin-1 fallback when the response has no charset,
    which mojibake'd smart quotes/em-dashes (UTF-8 bytes read as
    latin-1: " -> â€œ, ' -> â€™, — -> â€").
    """
    if isinstance(raw, bytes):
        return raw.decode("utf-8", errors="replace")
    return raw


def parse_sse_line(line: str):
    s = line.strip()
    if not s:
        return ("ignore", None)
    if s.startswith(":"):
        return ("ignore", None)
    if not s.startswith("data:"):
        return ("ignore", None)
    data = s[5:].strip()
    if data == "[DONE]":
        return ("done", None)
    try:
        obj = json.loads(data)
    except json.JSONDecodeError:
        return ("ignore", None)
    if "error" in obj:
        err = obj["error"]
        msg = err.get("message", str(err)) if isinstance(err, dict) else str(err)
        return ("error", msg)
    try:
        choices = obj.get("choices", [])
        if not choices:
            return ("ignore", None)
        content = choices[0].get("delta", {}).get("content")
        if content:
            return ("content", content)
        return ("ignore", None)
    except Exception:
        return ("ignore", None)


import os as _os
import tempfile as _tempfile
from pathlib import Path as _Path


def save_history_atomic(path: "_Path", history: list) -> None:
    path = _Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = _tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with _os.fdopen(fd, "w", encoding="utf-8") as f:
            import json as _json
            _json.dump(history, f, indent=2)
        _os.replace(tmp, path)
    except BaseException:
        try:
            _os.unlink(tmp)
        except OSError:
            pass
        raise
