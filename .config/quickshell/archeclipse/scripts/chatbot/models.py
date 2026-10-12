"""OpenRouter model list with 24h file cache. Public endpoint, no key needed.

CLI: models.py [cache_path]  -> JSON array of model ids on stdout.
On any failure prints the best fallback: stale cache, else [].
"""
import json
import sys
import time
from pathlib import Path

if __name__ == "__main__" and __package__ is None:
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import requests

MODELS_URL = "https://openrouter.ai/api/v1/models"
DEFAULT_CACHE = Path.home() / ".cache" / "quickshell" / "chatbot" / "models.json"


def _get(url: str, timeout: int):
    return requests.get(url, timeout=timeout)


def extract_ids(payload: dict) -> list:
    try:
        ids = sorted(m["id"] for m in payload.get("data", []) if isinstance(m, dict) and m.get("id"))
        return [str(i) for i in ids]
    except Exception:
        return []


def load_cached_models(cache_path: Path, ttl_hours: int = 24) -> tuple:
    """Returns (ids, fresh). Corrupt/missing cache -> ([], False)."""
    try:
        data = json.loads(Path(cache_path).read_text())
        ids = data.get("ids", [])
        if not isinstance(ids, list):
            return ([], False)
        age = time.time() - float(data.get("updatedAt", 0))
        return ([str(i) for i in ids], age < ttl_hours * 3600)
    except (OSError, ValueError, TypeError, AttributeError):
        return ([], False)


def fetch_models(cache_path: Path = DEFAULT_CACHE, ttl_hours: int = 24) -> list:
    ids, fresh = load_cached_models(cache_path, ttl_hours)
    if fresh:
        return ids
    try:
        resp = _get(MODELS_URL, timeout=15)
        if resp.status_code != 200:
            return ids
        ids = extract_ids(resp.json())
        if not ids:
            return ids
        Path(cache_path).parent.mkdir(parents=True, exist_ok=True)
        tmp = Path(str(cache_path) + ".tmp")
        tmp.write_text(json.dumps({"updatedAt": time.time(), "ids": ids}))
        tmp.replace(cache_path)
        return ids
    except Exception:
        return ids


def main(argv: list) -> int:
    cache = Path(argv[1]) if len(argv) > 1 else DEFAULT_CACHE
    print(json.dumps(fetch_models(cache_path=cache)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
