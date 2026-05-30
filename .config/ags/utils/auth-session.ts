import GLib from "gi://GLib";
import { createPoll } from "ags/time";
import { fetch } from "ags/fetch";
import { readJSONFile } from "./json";
import { writeJSONFile } from "./json";
import { notify } from "./notification";
import { execAsync } from "ags/process";

export interface AuthSession {
  access_token?: string;
  refresh_token?: string;
  expires_at?: string;
  token_type?: string;
  type?: string;
  [key: string]: string | undefined;
}

export const authSessionPath = `${GLib.get_home_dir()}/.config/ags/cache/auth/session.json`;
export const authServerScriptPath = `${GLib.get_home_dir()}/.config/ags/scripts/auth-server-callback.py`;
const SUPABASE_URL = "https://skekmjmsgcbfhbwgpzkp.supabase.co";
const SUPABASE_PUB_KEY = "sb_publishable_PLXFIwBsb79Gfu3YkW5B-w_rHozkZ1y";

export function readAuthSession(): AuthSession | null {
  const session = readJSONFile<AuthSession | null>(authSessionPath, null);

  if (!session || !session.access_token) return null;
  return session;
}

export async function refreshAuthSession(): Promise<AuthSession | null> {
  const session = readAuthSession();

  if (!session?.access_token) return null;

  const tokenCheck = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: SUPABASE_PUB_KEY,
      Authorization: `Bearer ${session.access_token}`,
    },
  }).catch(() => null);

  if (tokenCheck?.ok) return session;

  if (!session.refresh_token) return session;

  const refreshRes = await fetch(
    `${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: SUPABASE_PUB_KEY,
      },
      body: JSON.stringify({ refresh_token: session.refresh_token }),
    },
  ).catch(() => null);

  if (!refreshRes?.ok) return session;

  const refreshed = (await refreshRes.json()) as Partial<AuthSession>;
  const nextSession: AuthSession = {
    ...session,
    ...refreshed,
    access_token: refreshed.access_token || session.access_token,
    refresh_token: refreshed.refresh_token || session.refresh_token,
    expires_at: refreshed.expires_at || session.expires_at,
    token_type: refreshed.token_type || session.token_type,
    type: refreshed.type || session.type,
  };

  writeJSONFile(authSessionPath, nextSession);
  return nextSession;
}

export const authSession = createPoll<AuthSession | null>(
  readAuthSession(),
  2000,
  readAuthSession,
);

export const isAuthenticated = authSession((session) => Boolean(session));

export function ensureAuthServerRunning() {
  try {
    // Attempt to start server if not running. Use setsid+nohup to detach reliably.
    // const cmd = `bash -c "python3 '${authServerScriptPath}' >/tmp/ags-auth-server.log 2>&1"`;

    // kill the old server if it's still running and run the new one
    const killCmd = `bash -c "pkill -f 'python3 ${authServerScriptPath}' || true"`;
    const startCmd = `bash -c "python3 '${authServerScriptPath}' >/tmp/ags-auth-server.log 2>&1 &"`;

    // We don't care if the previous pkill fails (no existing process),
    // so ignore errors from the kill step and continue to start.
    execAsync(killCmd)
      .catch(() => undefined)
      .then(() =>
        execAsync(startCmd).catch((error) => {
          notify({
            summary: "Auth Server Error (start new)",
            body: String(error),
          });
        }),
      );
  } catch (error) {
    notify({
      summary: "Auth Server Error (ensure running)",
      body: String(error),
    });
  }
}
