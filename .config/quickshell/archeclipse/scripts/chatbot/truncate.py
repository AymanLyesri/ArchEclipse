def truncate_history(history: list, max_msgs: int = 40, max_chars: int = 12000) -> list:
    if len(history) <= max_msgs and sum(len(str(m.get("content", ""))) for m in history) <= max_chars:
        return list(history)
    system = [history[0]] if history and history[0].get("role") == "system" else []
    tail = list(history[-max_msgs:])
    if system and (not tail or tail[0].get("role") != "system"):
        tail = system + [m for m in tail if m.get("role") != "system"]
    total = sum(len(str(m.get("content", ""))) for m in tail)
    i = 1 if tail and tail[0].get("role") == "system" else 0
    while total > max_chars and len(tail) - i > 1:
        total -= len(str(tail[i].get("content", "")))
        del tail[i]
    return tail
