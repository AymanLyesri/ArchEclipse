import { createState } from "ags";
import { execAsync } from "ags/process";
import { timeout } from "ags/time";
import GLib from "gi://GLib";
import Gio from "gi://Gio";

type KeyboardDevice = {
  name?: string;
  active_keymap?: string;
  main?: boolean;
};

export const [keyboardLayout, setKeyboardLayout] = createState("");
export const [keyboardLayoutName, setKeyboardLayoutName] = createState("");

export const [deviceLayouts, setDeviceLayouts] = createState<
  Record<string, { layout: string; layoutName: string }>
>({});

let mainDeviceName = "";

const XKB_BASE_LIST_PATH = "/usr/share/X11/xkb/rules/base.lst";

let layoutCodes: Map<string, string> | null = null;
let lastRawLayoutName = "";

function parseXkbSection(
  text: string,
  section: "layout" | "variant",
  onEntry: (code: string, rest: string) => void,
) {
  const lines = text.split("\n");
  let inSection = false;
  for (const line of lines) {
    if (line === `! ${section}`) {
      inSection = true;
      continue;
    }
    if (!inSection) continue;
    if (line.startsWith("!")) break;
    const trimmed = line.trim();
    if (trimmed === "") break;
    const spaceIndex = trimmed.indexOf(" ");
    if (spaceIndex === -1) continue;
    onEntry(trimmed.slice(0, spaceIndex), trimmed.slice(spaceIndex + 1).trim());
  }
}

function loadLayoutCodes(): Promise<Map<string, string>> {
  return new Promise((resolve) => {
    const map = new Map<string, string>();
    const file = Gio.File.new_for_path(XKB_BASE_LIST_PATH);

    file.load_contents_async(null, (_source, result) => {
      try {
        const [, contents] = file.load_contents_finish(result);
        const text = new TextDecoder("utf-8").decode(contents);

        parseXkbSection(text, "layout", (code, description) => {
          if (!map.has(description)) map.set(description, code.toUpperCase());
        });

        parseXkbSection(text, "variant", (_variantCode, rest) => {
          const sep = rest.indexOf(":");
          if (sep === -1) return;
          const base = rest.slice(0, sep).trim();
          const description = rest.slice(sep + 1).trim();
          if (!map.has(description)) map.set(description, base.toUpperCase());
        });
      } catch (error) {
        printerr(
          `keyboard-layout: could not read ${XKB_BASE_LIST_PATH}: ${error}`,
        );
      }
      resolve(map);
    });
  });
}

function resolveCode(name: string): string {
  return layoutCodes?.get(name) ?? name.slice(0, 2).toUpperCase();
}

export function flagEmoji(code: string): string | null {
  const upper = code.toUpperCase();
  if (upper.length !== 2) return null;
  const REGIONAL_INDICATOR_A = 0x1f1e6;
  const points = [...upper].map(
    (char) => REGIONAL_INDICATOR_A + (char.charCodeAt(0) - 65),
  );
  const valid = points.every(
    (point) => point >= REGIONAL_INDICATOR_A && point <= REGIONAL_INDICATOR_A + 25,
  );
  return valid ? String.fromCodePoint(...points) : null;
}

void loadLayoutCodes().then((map) => {
  layoutCodes = map;
  if (lastRawLayoutName) setActiveLayout(lastRawLayoutName, mainDeviceName || undefined);
});

function setActiveLayout(rawName: string, device?: string) {
  const normalized = rawName.trim();
  if (!normalized) return;

  const code = resolveCode(normalized);

  if (device) {
    setDeviceLayouts((prev) => ({
      ...prev,
      [device]: { layout: code, layoutName: normalized },
    }));
  }

  if (!mainDeviceName || !device || device === mainDeviceName) {
    lastRawLayoutName = normalized;
    setKeyboardLayoutName(normalized);
    setKeyboardLayout(code);
  }
}

async function loadInitialLayout() {
  try {
    const output = await execAsync(["hyprctl", "devices", "-j"]);
    const devices = JSON.parse(output) as { keyboards?: KeyboardDevice[] };
    const keyboards = devices.keyboards ?? [];
    const mainKeyboard = keyboards.find((device) => device.main) ?? keyboards[0];

    mainDeviceName = mainKeyboard?.name ?? "";
    if (mainKeyboard?.active_keymap) {
      setActiveLayout(mainKeyboard.active_keymap, mainDeviceName || undefined);
    }

    for (const kb of keyboards) {
      if (kb.name && kb.name !== mainDeviceName && kb.active_keymap) {
        setActiveLayout(kb.active_keymap, kb.name);
      }
    }
  } catch (error) {
    printerr(`Unable to read the active keyboard layout: ${error}`);
  }
}

let socket: Gio.Socket | null = null;
let connection: Gio.SocketConnection | null = null;
let dataStream: Gio.DataInputStream | null = null;
let cancellable: Gio.Cancellable | null = null;
let connecting = false;
let watcherStarted = false;
let reconnectAttempt = 0;
let reconnectTimer: ReturnType<typeof timeout> | null = null;
const MAX_BACKOFF_MS = 30_000;

function stopWatcher() {
  if (reconnectTimer) {
    reconnectTimer.cancel?.();
    reconnectTimer = null;
  }
  cancellable?.cancel();
  cancellable = null;

  try {
    dataStream?.close(null);
  } catch {
  }
  dataStream = null;

  try {
    connection?.close(null);
  } catch {
  }
  connection = null;

  try {
    socket?.close();
  } catch {
  }
  socket = null;
  connecting = false;
}

function scheduleReconnect() {
  reconnectAttempt += 1;
  const delay = Math.min(1000 * 2 ** (reconnectAttempt - 1), MAX_BACKOFF_MS);
  printerr(
    `keyboard-layout: event socket down, retrying in ${delay}ms (attempt ${reconnectAttempt})`,
  );
  reconnectTimer = timeout(delay, () => {
    reconnectTimer = null;
    watchLayoutChanges();
  });
}

function handleEvent(line: string) {
  if (!line.startsWith("activelayout>>")) return;
  const [, payload] = line.split(">>", 2);
  const separator = payload.indexOf(",");
  if (separator === -1) return;
  const device = payload.slice(0, separator);
  const layoutName = payload.slice(separator + 1);
  setActiveLayout(layoutName, device);
}

function readNextLine() {
  if (!dataStream || !cancellable) return;
  const stream = dataStream;
  const token = cancellable;

  stream.read_line_async(GLib.PRIORITY_DEFAULT, token, (_source, result) => {
    if (token.is_cancelled()) return;
    try {
      const [line] = stream.read_line_finish_utf8(result);
      if (line === null) throw new Error("event socket closed (EOF)");
      handleEvent(line);
      readNextLine();
    } catch (error) {
      printerr(`keyboard-layout: event socket read failed: ${error}`);
      stopWatcher();
      scheduleReconnect();
    }
  });
}

function watchLayoutChanges() {
  const signature = GLib.getenv("HYPRLAND_INSTANCE_SIGNATURE");
  if (!signature) {
    scheduleReconnect();
    return;
  }

  if (socket || connecting) return;
  connecting = true;

  const socketPath = `${GLib.get_user_runtime_dir()}/hypr/${signature}/.socket2.sock`;

  try {
    const address = new Gio.UnixSocketAddress({ path: socketPath });
    const newSocket = Gio.Socket.new(
      Gio.SocketFamily.UNIX,
      Gio.SocketType.STREAM,
      Gio.SocketProtocol.DEFAULT,
    );

    newSocket.connect(address, null);

    socket = newSocket;
    connection = socket.connection_factory_create_connection();
    cancellable = new Gio.Cancellable();
    dataStream = new Gio.DataInputStream({
      base_stream: connection.get_input_stream(),
      close_base_stream: true,
    });

    reconnectAttempt = 0;
    connecting = false;
    readNextLine();
  } catch (error) {
    connecting = false;
    socket = null;
    connection = null;
    dataStream = null;
    printerr(`keyboard-layout: failed to connect to event socket: ${error}`);
    scheduleReconnect();
  }
}

export function startKeyboardLayoutWatcher() {
  if (watcherStarted) return;
  watcherStarted = true;
  void loadInitialLayout();
  watchLayoutChanges();
}

export function stopKeyboardLayoutWatcher() {
  watcherStarted = false;
  stopWatcher();
}

startKeyboardLayoutWatcher();
