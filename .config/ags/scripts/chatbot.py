#!/usr/bin/env python3

import os
import sys
import json
import time
import uuid
import requests
from pathlib import Path

API_URL = "https://openrouter.ai/api/v1/chat/completions"
CACHE_DIR = Path.home() / ".config/ags/cache/chatbot"


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
    payload = {"model": model, "messages": api_messages}

    try:
        start_time = time.time()
        response = requests.post(API_URL, headers=headers, json=payload, timeout=60)
        response.raise_for_status()
        response_time = int((time.time() - start_time) * 1000)  # milliseconds

        data = response.json()
        reply = data["choices"][0]["message"]["content"]

        # Add assistant's response to history with response time
        assistant_msg = create_message("assistant", reply, response_time)
        history.append(assistant_msg)

        # Save updated history
        save_history(model, history, session_id)

        print(reply)

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
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
