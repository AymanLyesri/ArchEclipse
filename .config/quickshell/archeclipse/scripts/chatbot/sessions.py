"""Session list/rename helper. Single code path for QML (no N-proc races).

CLI:
    sessions.py <model> list                    -> JSON [{"id","name"}] on stdout
    sessions.py <model> rename <sid> <newname>  -> exit 0 ok, 1 on bad input

The model argument is retained for CLI compatibility, but sessions are shared
by all models.
"""
import json
import sys
import time
from pathlib import Path

if __name__ == "__main__" and __package__ is None:
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

CACHE_DIR = Path.home() / ".cache" / "quickshell" / "chatbot"


def _sessions_root() -> Path:
    return CACHE_DIR / "sessions"


def _sessions_dir(model: str) -> Path:
    if not model or model.startswith("/"):
        raise ValueError(f"Bad model path: {model!r}")
    for seg in model.split("/"):
        if not seg or seg in (".", ".."):
            raise ValueError(f"Bad model path: {model!r}")
    return _sessions_root()


def _migrate_model_sessions() -> None:
    """Move old model-scoped sessions into the shared store once.

    Existing shared sessions win on ID collisions so switching models cannot
    overwrite data that has already been migrated or created.
    """
    shared_dir = _sessions_root()
    shared_dir.mkdir(parents=True, exist_ok=True)
    for legacy_dir in CACHE_DIR.glob("**/sessions"):
        if legacy_dir == shared_dir or not legacy_dir.is_dir():
            continue
        for source in legacy_dir.iterdir():
            target = shared_dir / source.name
            if source.is_dir() and not target.exists():
                source.rename(target)


def _check_sid(session_id: str) -> None:
    if not session_id or "/" in session_id or session_id in (".", ".."):
        raise ValueError(f"Bad session id: {session_id!r}")


def _meta_path(model: str, session_id: str) -> Path:
    _check_sid(session_id)
    return _sessions_dir(model) / session_id / "meta.json"


def read_meta(model: str, session_id: str) -> dict:
    try:
        data = json.loads(_meta_path(model, session_id).read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError, json.JSONDecodeError):
        return {}


def write_meta(model: str, session_id: str, meta: dict) -> None:
    p = _meta_path(model, session_id)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(meta, indent=2))
    tmp.replace(p)


def list_sessions(model: str) -> list:
    d = _sessions_dir(model)
    _migrate_model_sessions()
    d.mkdir(parents=True, exist_ok=True)
    ids = sorted(p.name for p in d.iterdir() if p.is_dir())
    if not ids:
        (d / "default").mkdir(exist_ok=True)
        ids = ["default"]

    def sort_key(sid: str):
        return (0 if sid == "default" else 1, sid)

    ids.sort(key=sort_key)
    out = []
    for i, sid in enumerate(ids):
        name = read_meta(model, sid).get("name") or f"Session {i + 1}"
        out.append({"id": sid, "name": str(name)[:80]})
    return out


def rename_session(model: str, session_id: str, name: str) -> dict:
    _check_sid(session_id)
    clean = (name or "").strip()
    if not clean:
        raise ValueError("Session name must not be empty")
    clean = clean[:80]
    if not (_sessions_dir(model) / session_id).is_dir():
        raise ValueError(f"Unknown session: {session_id!r}")
    meta = read_meta(model, session_id)
    meta["name"] = clean
    meta["updatedAt"] = int(time.time() * 1000)
    write_meta(model, session_id, meta)
    return meta


def main(argv: list) -> int:
    if len(argv) < 3:
        print("Usage: sessions.py <model> list|rename <sid> <name>", file=sys.stderr)
        return 1
    model, cmd = argv[1], argv[2]
    try:
        if cmd == "list":
            # Envelope carries the model so QML can drop stale replies
            # (a listing that arrives after a provider switch).
            print(json.dumps({"model": model, "sessions": list_sessions(model)}))
            return 0
        if cmd == "rename" and len(argv) >= 5:
            rename_session(model, argv[3], argv[4])
            return 0
        print("Usage: sessions.py <model> list|rename <sid> <name>", file=sys.stderr)
        return 1
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
