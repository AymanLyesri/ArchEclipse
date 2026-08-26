import Gio from "gi://Gio";
import GLib from "gi://GLib";
import { execAsync } from "ags/process";
import { timeout } from "ags/time";

// Client for the kirie wallpaper engine (Wallpaper Engine renderer).
//
// kirie owns a control socket and answers questions about itself in JSON, so
// nothing here re-derives what it already knows: the socket carries the live
// state, the CLI answers when no engine is running. Both are spoken directly
// from AGS — the socket over Gio, the CLI over execAsync — so there is no
// helper daemon and no shell in the interactive path.
//
// Wire contract (kirie-ipc): connect, write ONE line, read the reply, the
// engine closes. Each call is therefore self-contained and there is nothing to
// reconnect after an AGS restart.

export const kirieSocket = `${GLib.getenv("XDG_RUNTIME_DIR") ?? "/tmp"}/lwe.sock`;

/** An installed Wallpaper Engine item, as reported by `kirie list --json`. */
export interface KirieItem {
  id: string;
  title: string;
  type: string;
  dir: string;
  preview: string | null;
  renderable: boolean;
  reason: string | null;
}

/** One entry of a wallpaper's property schema (project.json user properties,
 * with the live overrides already folded into `value` by the engine). */
export interface KirieProperty {
  key: string;
  type: "bool" | "slider" | "color" | "combo" | "textinput" | "file" | "directory";
  text: string;
  value: any;
  min?: number;
  max?: number;
  step?: number;
  order?: number;
  options?: { label: string; value: any }[];
}

/** One Workshop search result (`workshop search`, docs/compat-socket.md §13).
 *
 * Shares `KirieItem`'s keys so a picker can render browsable and installed
 * wallpapers from one code path; `dir` is null until the files arrive. */
export interface KirieWorkshopItem extends KirieItem {
  dir: string;
  subscribed: boolean;
  installed: boolean;
  size: number;
  votes_up: number;
  votes_down: number;
  score: number;
  updated: number;
  tags: string[];
}

/** What to ask the Workshop for. */
export interface KirieWorkshopQuery {
  text?: string;
  tags?: string[];
  excludeTags?: string[];
  sort?: "popular" | "trend" | "recent" | "rated";
  days?: number;
  page?: number;
  limit?: number;
}

/** A subscription in flight (`workshop job <n>`). */
export interface KirieWorkshopJob {
  job: number;
  id: string;
  state: "subscribing" | "downloading" | "installed" | "error";
  bytes: number;
  dir: string | null;
  error: string | null;
}

/** A GPU kirie can be pinned to, as reported by `kirie gpus --json`. */
export interface KirieGpu {
  value: string;
  label: string;
  kind: string;
  icd: string | null;
}

/** Parsed `status` reply: the global speed plus the background per screen. */
export interface KirieStatus {
  speed: number;
  screens: { screen: string; bg: string }[];
}

// The engine is installed per user, and the session PATH does not always carry
// ~/.local/bin when the compositor starts the shell.
const fallbackBin = `${GLib.get_home_dir()}/.local/bin/kirie`;
const kirieBin = (): string | null =>
  GLib.find_program_in_path("kirie") ??
  (GLib.file_test(fallbackBin, GLib.FileTest.IS_EXECUTABLE)
    ? fallbackBin
    : null);

/** Whether the engine binary is installed at all. */
export const kirieInstalled = () => kirieBin() !== null;

/** Run the engine CLI and parse its JSON output. */
const kirieJson = <T,>(args: string[]): Promise<T> =>
  execAsync([kirieBin() ?? "kirie", ...args]).then((json) => JSON.parse(json));

/**
 * Send one command and collect every reply line until the engine closes.
 * Rejects when the socket is missing (engine down), on a timeout, or when the
 * connection closes without a reply — callers surface that as a notification.
 *
 * `bg` waits longer: the engine replies only once the wallpaper is actually
 * applied, and a heavy scene takes seconds to build.
 */
export function kirieLines(
  cmd: string,
  timeoutMs = cmd.startsWith("bg ") ? 15000 : 2000,
): Promise<string[]> {
  return new Promise((resolve, reject) => {
    const cancellable = new Gio.Cancellable();
    let timer: number | null = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      timeoutMs,
      () => {
        timer = null;
        cancellable.cancel();
        reject(new Error(`kirie: "${cmd}" timed out after ${timeoutMs}ms`));
        return GLib.SOURCE_REMOVE;
      },
    );
    const settle = (fn: () => void) => {
      if (timer !== null) {
        GLib.source_remove(timer);
        timer = null;
      }
      fn();
    };

    const client = new Gio.SocketClient();
    client.connect_async(
      Gio.UnixSocketAddress.new(kirieSocket),
      cancellable,
      (_client, res) => {
        let conn: Gio.SocketConnection;
        try {
          conn = client.connect_finish(res);
        } catch (e) {
          settle(() => reject(new Error(`kirie: engine not reachable (${e})`)));
          return;
        }
        const close = () => {
          try {
            conn.close(null);
          } catch {}
        };

        conn.get_output_stream().write_bytes_async(
          new GLib.Bytes(new TextEncoder().encode(`${cmd}\n`)),
          GLib.PRIORITY_DEFAULT,
          cancellable,
          (stream, wres) => {
            try {
              (stream as Gio.OutputStream).write_bytes_finish(wres);
            } catch (e) {
              close();
              settle(() => reject(new Error(`kirie: write failed (${e})`)));
              return;
            }

            const input = new Gio.DataInputStream({
              base_stream: conn.get_input_stream(),
              close_base_stream: false,
            });
            const lines: string[] = [];
            const readNext = () =>
              input.read_line_async(
                GLib.PRIORITY_DEFAULT,
                cancellable,
                (_s, rres) => {
                  let line: string | null = null;
                  try {
                    [line] = input.read_line_finish_utf8(rres);
                  } catch (e) {
                    close();
                    settle(() => reject(new Error(`kirie: read failed (${e})`)));
                    return;
                  }
                  if (line !== null) {
                    lines.push(line.trim());
                    readNext();
                    return;
                  }
                  // EOF: the engine closed after its reply, as the protocol says.
                  close();
                  settle(() =>
                    lines.length === 0
                      ? reject(new Error("kirie: closed without a reply"))
                      : resolve(lines),
                  );
                },
              );
            readNext();
          },
        );
      },
    );
  });
}

/** Whether a failure is the engine having gone away mid-conversation: a
 * restart closes the socket under any request in flight. Worth one retry. */
const engineWentAway = (err: unknown) =>
  /Broken pipe|Connection refused|not reachable|closed/i.test(String(err));

/** Send one command and resolve with its first reply line.
 *
 * Retries once when the engine went away: the alternative is showing the user
 * a Gio error for something that fixes itself in a few hundred milliseconds. */
export const kirieSend = (cmd: string, timeoutMs?: number): Promise<string> =>
  kirieLines(cmd, timeoutMs)
    .catch((err) => {
      if (!engineWentAway(err)) throw err;
      return new Promise<string[]>((resolve, reject) => {
        timeout(400, () => kirieLines(cmd, timeoutMs).then(resolve, reject));
      });
    })
    .then((lines) => lines[0] ?? "")
    .catch((err) => {
      // Rephrase the transport's own words: "Error sending data: Broken pipe"
      // says nothing a user can act on.
      if (engineWentAway(err)) {
        throw new Error("the wallpaper engine is not running");
      }
      throw err;
    });

/** Send one command and resolve `true` when the engine accepted it. */
export const kirieOk = (cmd: string, timeoutMs?: number): Promise<boolean> =>
  kirieSend(cmd, timeoutMs)
    .then((r) => r !== "" && !r.startsWith("error") && !r.startsWith("unknown"))
    .catch(() => false);

/** Whether an engine is up and answering. */
export const kirieAlive = (): Promise<boolean> =>
  kirieSend("ping")
    .then((r) => r === "pong")
    .catch(() => false);

/** `status` → the speed and the background recorded for every screen. */
export const kirieStatus = (): Promise<KirieStatus> =>
  kirieLines("status").then((lines) => {
    const status: KirieStatus = { speed: 1, screens: [] };
    for (const line of lines) {
      if (line.startsWith("speed=")) {
        status.speed = parseFloat(line.slice(6)) || 1;
      } else if (line.startsWith("screen=")) {
        // `screen=<name> bg=<path>` — the path may contain spaces.
        const bgAt = line.indexOf(" bg=");
        if (bgAt > 7)
          status.screens.push({
            screen: line.slice(7, bgAt),
            bg: line.slice(bgAt + 4),
          });
      }
    }
    return status;
  });

/** The item directory rendered on `monitor`, or "" when nothing is. */
export const kirieCurrentItem = (monitor: string): Promise<string> =>
  kirieStatus()
    .then((s) => s.screens.find((sc) => sc.screen === monitor)?.bg ?? "")
    .catch(() => "");

const byOrder = (a: KirieProperty, b: KirieProperty) =>
  (a.order ?? 0) - (b.order ?? 0);

/** `getproperties <monitor>` → the live schema, overrides folded in. */
export const kirieProperties = (monitor: string): Promise<KirieProperty[]> =>
  kirieSend(`getproperties ${monitor}`).then((json) =>
    (JSON.parse(json) as KirieProperty[]).sort(byOrder),
  );

/** The schema of an item that is not being rendered — read straight off its
 * `project.json`, so the properties UI works with the engine down. */
export const kirieItemProperties = (item: string): Promise<KirieProperty[]> =>
  kirieJson<KirieProperty[]>(["--list-properties-json", item]).then((schema) =>
    schema.sort(byOrder),
  );

/** Every Wallpaper Engine item installed on this machine. */
export const kirieList = (): Promise<KirieItem[]> =>
  kirieJson<KirieItem[]>(["list", "--json"]);

/** The GPUs kirie can be pinned to (first entry is "auto"). */
export const kirieGpus = (): Promise<KirieGpu[]> =>
  kirieJson<KirieGpu[]>(["gpus", "--json"]);

/** `kirie check` — the engine's own report on what it needs here. It exits
 * non-zero when something required is missing, so the failure carries the
 * report too. */
export const kirieCheck = (): Promise<string> =>
  execAsync([kirieBin() ?? "kirie", "check"]);

// --- Workshop (docs/compat-socket.md §13) -----------------------------------
//
// The only calls here that leave the machine, so they take seconds and set
// their own timeout; this file's 2s default would fail every search.

/** How long to allow a Workshop query. The engine's own cap is 30s. */
const WORKSHOP_TIMEOUT = 30000;

/** Parse a Workshop reply, turning the engine's `{"error":…}` into a rejection. */
const workshopJson = <T,>(reply: string): T => {
  const value = JSON.parse(reply);
  if (value && !Array.isArray(value) && typeof value.error === "string") {
    throw new Error(value.error);
  }
  return value as T;
};

/** `workshop search` — browse the Workshop, installed or not.
 *
 * `text` goes last in the wire format: a search phrase has spaces in it and
 * the engine reads it as the rest of the line. */
export const kirieWorkshopSearch = (
  query: KirieWorkshopQuery = {},
): Promise<KirieWorkshopItem[]> => {
  const args: string[] = [];
  for (const tag of query.tags ?? []) args.push(`tag=${tag}`);
  for (const tag of query.excludeTags ?? []) args.push(`nottag=${tag}`);
  if (query.sort) args.push(`sort=${query.sort}`);
  if (query.days) args.push(`days=${query.days}`);
  if (query.page) args.push(`page=${query.page}`);
  if (query.limit) args.push(`limit=${query.limit}`);
  const text = query.text?.trim();
  if (text) args.push(`text=${text}`);

  return kirieSend(`workshop search ${args.join(" ")}`, WORKSHOP_TIMEOUT).then(
    workshopJson<KirieWorkshopItem[]>,
  );
};

/** `workshop subscribe <id>` → the job number following the download. */
export const kirieWorkshopSubscribe = (id: string): Promise<number> =>
  kirieSend(`workshop subscribe ${id}`, WORKSHOP_TIMEOUT).then(
    (reply) => workshopJson<{ job: number }>(reply).job,
  );

/** `workshop job <n>` → how that subscription is going. */
export const kirieWorkshopJob = (job: number): Promise<KirieWorkshopJob> =>
  kirieSend(`workshop job ${job}`).then(workshopJson<KirieWorkshopJob>);

/** `workshop unsubscribe <id>` → the item's state once Steam has accepted.
 *
 * Steam deletes the files on its own schedule, so the reply can still carry a
 * directory: the subscription is what changed. */
export const kirieWorkshopUnsubscribe = (id: string): Promise<KirieWorkshopItem> =>
  kirieSend(`workshop unsubscribe ${id}`, WORKSHOP_TIMEOUT).then(
    (reply) => workshopJson<KirieWorkshopItem[]>(reply)[0],
  );

/** `workshop state <id>` → subscribed/installed/where, Steam or no Steam. */
export const kirieWorkshopState = (id: string): Promise<KirieWorkshopItem> =>
  kirieSend(`workshop state ${id}`, WORKSHOP_TIMEOUT).then(
    (reply) => workshopJson<KirieWorkshopItem[]>(reply)[0],
  );

/** Whether this engine speaks the Workshop verbs at all.
 *
 * An engine from before they existed answers `unknown command`, and the
 * browser has to say so rather than look broken. */
export const kirieWorkshopSupported = (): Promise<boolean> =>
  kirieSend("workshop job 0")
    .then((reply) => !reply.startsWith("unknown"))
    .catch(() => false);
