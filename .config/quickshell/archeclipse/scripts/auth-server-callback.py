#!/usr/bin/env python3
"""Quickshell auth callback server (magic-link login).

Listens on http://127.0.0.1:53100/callback — this URL is registered as the
Supabase ``emailRedirectTo``. The access token arrives in the URL *fragment*
(``#access_token=...``), which browsers never send to the server, so the
``/callback`` page's JS forwards the fragment to ``/save`` via POST, and the
session is persisted to ``~/.cache/quickshell/auth/session.json`` for
``UserProfileWidget.qml`` to poll.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse
import html
import json
import os
import subprocess

SESSION_PATH = Path.home() / ".cache" / "quickshell" / "auth" / "session.json"

SESSION_PATH.parent.mkdir(parents=True, exist_ok=True)

# One-time bearer for /save: minted at startup, embedded only in the served
# /callback page. Any other local page or process POSTing without it gets a
# 403, so a malicious tab cannot plant attacker tokens (session fixation).
SAVE_TOKEN = os.urandom(32).hex()


def save_session(params):
    if params.get("token", [""])[0] != SAVE_TOKEN:
        return False
    session = {
        "access_token": params.get("access_token", [""])[0],
        "refresh_token": params.get("refresh_token", [""])[0],
        "expires_at": params.get("expires_at", [""])[0],
        "token_type": params.get("token_type", [""])[0],
        "type": params.get("type", [""])[0],
    }
    if not session["access_token"]:
        return False

    # Mode 0600: these are bearer credentials, never group/world-readable.
    fd = os.open(SESSION_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(session, f, indent=2)
    except BaseException:
        os.close(fd)
        raise

    print(f"Session saved to {SESSION_PATH}")
    try:
        subprocess.run(
            ["notify-send", "Quickshell Auth", f"Session saved to {SESSION_PATH}"],
            check=False,
        )
    except Exception as e:
        print(f"Failed to send notification: {e}")
    return True


def callback_page():
    token = html.escape(SAVE_TOKEN, quote=True)
    return (
        b"""<!DOCTYPE html>
<html>
<body>
<script>
const hash = window.location.hash.replace(/^#/, '');
const token = """
        + json.dumps(token).encode()
        + b""";
if (!hash) {
  document.body.innerHTML = '<h1>Login failed</h1><p>No session data was returned.</p>';
} else {
  fetch('/save', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: hash + '&token=' + encodeURIComponent(token),
  }).then(() => {
    document.body.innerHTML = '<h1>Login successful</h1><p>You can close this window.</p>';
  }).catch(() => {
    document.body.innerHTML = '<h1>Login failed</h1><p>Could not save the session.</p>';
  });
}
</script>
</body>
</html>
"""
    )


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Quieter stdout: Quickshell's authServerProc redirects this to
        # /tmp/qs-auth-server.log. One line per request.
        print(f"[{self.log_date_time_string()}] {self.address_string()} {fmt % args}", flush=True)

    def _deny(self):
        self.send_response(404)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/callback":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()

            self.wfile.write(callback_page())
            return

        # /save accepts POST only: a GET that writes would let any <img> tag
        # or pasted link plant a session via its query string.
        self._deny()

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path != "/save":
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length).decode("utf-8")
        params = parse_qs(body)

        if not save_session(params):
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"forbidden")
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok")


HTTPServer.allow_reuse_address = True
server = HTTPServer(("127.0.0.1", 53100), Handler)

print("Auth server running on http://127.0.0.1:53100", flush=True)

try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
