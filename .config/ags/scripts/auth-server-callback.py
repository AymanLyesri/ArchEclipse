# auth_server.py

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import json
import os

SESSION_PATH = os.path.expanduser("~/.config/ags/cache/auth/session.json")

os.makedirs(os.path.dirname(SESSION_PATH), exist_ok=True)


def save_session(params):
    session = {
        "access_token": params.get("access_token", [""])[0],
        "refresh_token": params.get("refresh_token", [""])[0],
        "expires_at": params.get("expires_at", [""])[0],
        "token_type": params.get("token_type", [""])[0],
        "type": params.get("type", [""])[0],
    }

    with open(SESSION_PATH, "w") as f:
        json.dump(session, f, indent=2)

    print(f"Session saved to {SESSION_PATH}")
    try:
        # Send a desktop notification for debugging (requires notify-send available)
        os.system(f'notify-send "AGS Auth" "Session saved to {SESSION_PATH}"')
    except Exception as e:
        print(f"Failed to send notification: {e}")


def callback_page():
    return b"""
<!DOCTYPE html>
<html>
<body>
<script>
const hash = window.location.hash.replace(/^#/, '');

if (!hash) {
  document.body.innerHTML = '<h1>Login failed</h1><p>No session data was returned.</p>';
} else {
  fetch('/save', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: hash,
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


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/callback":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()

            self.wfile.write(callback_page())
            return

        if parsed.path == "/save":
            params = parse_qs(parsed.query)
            save_session(params)

            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path != "/save":
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length).decode("utf-8")
        params = parse_qs(body)

        save_session(params)

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok")


server = HTTPServer(("127.0.0.1", 53100), Handler)

print("Auth server running on http://127.0.0.1:53100")

server.serve_forever()
