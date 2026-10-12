"""Slash-command parse + session match helpers for the chatbot.

Pure logic mirrored in ChatBotWidget.qml (QML cannot import this module;
keep both implementations in sync — this module is the tested spec).
"""

COMMANDS = ("new", "list", "sessions", "switch", "rename", "delete", "clear", "revert")
SESSION_COMMANDS = ("list", "sessions", "switch", "delete")


def parse_slash(text):
    """Split `/cmd arg...` -> (cmd.lower(), arg.strip()) or (None, None)."""
    if not isinstance(text, str) or not text.startswith("/"):
        return (None, None)
    body = text[1:].strip()
    if not body:
        return (None, None)
    parts = body.split(None, 1)
    cmd = parts[0].lower()
    arg = parts[1].strip() if len(parts) > 1 else ""
    return (cmd, arg)


def match_session(sessions, query):
    """Match a session by 1-based index, exact id, or name substring (case-insensitive).

    Returns the session dict or None.
    """
    if not query or not sessions:
        return None
    q = str(query).strip()
    if not q:
        return None
    # 1-based index ("2" -> second session).
    try:
        idx = int(q)
        if 1 <= idx <= len(sessions):
            return sessions[idx - 1]
    except (ValueError, TypeError):
        pass
    ql = q.lower()
    for s in sessions:
        if str(s.get("id", "")).lower() == ql:
            return s
    for s in sessions:
        if ql in str(s.get("name", "")).lower():
            return s
    return None
