#!/usr/bin/env python3

import os
import sys
import json
import time
import uuid
import requests
from pathlib import Path

API_URL = "https://openrouter.ai/api/v1/chat/completions"
CACHE_DIR = Path.home() / ".cache" / "quickshell" / "chatbot"


def parse_sse_line(line: str):
    """Parse one SSE line from OpenRouter streaming.

    Returns (kind, value) where kind is one of:
      "content" -> value is the text delta
      "done"    -> value is None (stream terminator)
      "error"   -> value is the error message
      "ignore"  -> value is None (keep-alive, empty, usage chunk, bad JSON)
    """
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
        if isinstance(err, dict):
            msg = err.get("message", str(err))
        else:
            msg = str(err)
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


def create_message(role: str, content: str, response_time: int = 0) -> dict:
    """Create a message object with all required fields."""
    return {
        "id": str(uuid.uuid4()),
        "role": role,
        "content": content,
        "timestamp": int(time.time() * 1000),  # milliseconds
        "responseTime": response_time,
    }


def get_history_path(model: str, session_id: str = "default") -> Path:
    """Get the path to the history file for a given model and session."""
    # Split model into provider and model parts (e.g., "openai/gpt-4o-mini")
    return CACHE_DIR / model / "sessions" / session_id / "history.json"


def load_history(model: str, session_id: str = "default") -> list:
    """Load conversation history from JSON file."""
    history_path = get_history_path(model, session_id)

    if history_path.exists():
        try:
            with open(history_path, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            # If file is corrupted or can't be read, start fresh
            return []
    return []


def save_history(model: str, history: list, session_id: str = "default"):
    """Save conversation history to JSON file."""
    history_path = get_history_path(model, session_id)

    # Create directory structure if it doesn't exist
    history_path.parent.mkdir(parents=True, exist_ok=True)

    with open(history_path, "w") as f:
        json.dump(history, f, indent=2)


def main():
    if len(sys.argv) < 4:
        print("ERROR: Missing arguments", file=sys.stderr)
        print(
            "Usage: python chatbot.py <provider/model> <message> <api_key> [session_id]",
            file=sys.stderr,
        )
        print(
            'Example: python chatbot.py openai/gpt-4o-mini "Hello world" YOUR_API_KEY session1',
            file=sys.stderr,
        )
        sys.exit(1)

    model = sys.argv[1]
    user_message = sys.argv[2]
    api_key = sys.argv[3].strip()  # Strip whitespace/newlines from API key
    session_id = sys.argv[4] if len(sys.argv) > 4 else "default"

    # Load conversation history
    history = load_history(model, session_id)

    # Add new user message to history
    user_msg = create_message("user", user_message)
    history.append(user_msg)

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    # Extract only role and content for API payload
    api_messages = [{"role": msg["role"], "content": msg["content"]} for msg in history]
    payload = {"model": model, "messages": api_messages, "stream": True}

    # Partial state saved by the SIGINT/SIGTERM handler (Stop button).
    state = {"reply": "", "start": time.time()}

    def _save_partial():
        if state["reply"]:
            rt = int((time.time() - state["start"]) * 1000)
            history.append(create_message("assistant", state["reply"], rt))
            save_history(model, history, session_id)

    def _on_stop(signum, frame):
        try:
            _save_partial()
        finally:
            # Exit 0 so QML treats Stop as success and reloads canonical file.
            sys.stdout.flush()
            os._exit(0)

    try:
        import signal as _signal

        _signal.signal(_signal.SIGINT, _on_stop)
        _signal.signal(_signal.SIGTERM, _on_stop)
    except Exception:
        pass

    try:
        start_time = time.time()
        state["start"] = start_time
        response = requests.post(
            API_URL, headers=headers, json=payload, timeout=60, stream=True
        )
        if response.status_code != 200:
            try:
                err_data = response.json()
                msg = err_data.get("error", {}).get("message", response.text)
            except Exception:
                msg = response.text
            print(f"ERROR: HTTP {response.status_code}: {msg}", file=sys.stderr)
            sys.exit(1)

        mid_error = None
        for raw in response.iter_lines(decode_unicode=True):
            if raw is None:
                continue
            kind, val = parse_sse_line(raw)
            if kind == "content":
                state["reply"] += val
                print(val, end="", flush=True)
            elif kind == "done":
                break
            elif kind == "error":
                mid_error = val
                break
            # "ignore" -> keep-alive, usage chunk, bad JSON: skip
        response.close()

        if mid_error and not state["reply"]:
            print(f"ERROR: {mid_error}", file=sys.stderr)
            sys.exit(1)

        reply = state["reply"]
        if not reply:
            print("ERROR: Empty response from API", file=sys.stderr)
            sys.exit(1)

        response_time = int((time.time() - start_time) * 1000)  # milliseconds

        # Add assistant's response to history with response time
        assistant_msg = create_message("assistant", reply, response_time)
        history.append(assistant_msg)

        # Save updated history
        save_history(model, history, session_id)

        sys.stdout.flush()
        if mid_error:
            # Partial content streamed + saved; still report the error.
            print(f"ERROR: {mid_error}", file=sys.stderr)
            sys.exit(1)

    except requests.exceptions.Timeout:
        print("ERROR: Request timed out after 60 seconds", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(
            f"ERROR: HTTP {e.response.status_code}: {e.response.text}", file=sys.stderr
        )
        sys.exit(1)
    except requests.exceptions.ConnectionError:
        print("ERROR: Failed to connect to API server", file=sys.stderr)
        sys.exit(1)
    except (KeyError, IndexError) as e:
        print(f"ERROR: Unexpected API response format: {e}", file=sys.stderr)
        sys.exit(1)
    except SystemExit:
        raise
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
