import Gio from "gi://Gio";
import GLib from "gi://GLib";
import { execAsync } from "ags/process";
import { booruPath } from "../constants/path.constants";
import { globalSettings } from "../variables";
import { BooruImage } from "../class/BooruImage.class";

type PinLike = {
  id?: number;
  extension?: string;
  api?: {
    value?: string;
  };
};

const FASTFETCH_CACHE_DIR = `${GLib.get_home_dir()}/.config/fastfetch/cache`;
const GENERATED_PREFIX = "booru-pin-";
const CORNER_RADIUS_PERCENT = 5;
const DEBOUNCE_MS = 250;

let started = false;
let debounceSourceId = 0;
let syncInProgress = false;
let resyncQueued = false;
let lastPinsSignature = "";

const sanitizeSegment = (value: string): string =>
  value.replace(/[^a-zA-Z0-9_-]/g, "_");

const getPinKey = (pin: PinLike): string | null => {
  if (typeof pin.id !== "number") return null;
  const apiValue = pin.api?.value;
  if (typeof apiValue !== "string" || !apiValue) return null;
  return `${pin.id}:${apiValue}`;
};

const getPinsSignature = (pins: PinLike[]): string => {
  const parts: string[] = [];

  for (const pin of pins) {
    const key = getPinKey(pin);
    if (!key) continue;
    parts.push(`${key}:${pin.extension ?? ""}`);
  }

  parts.sort();
  return parts.join("|");
};

const getSourcePath = (pin: PinLike): string | null => {
  const key = getPinKey(pin);
  if (!key) return null;

  const [id, apiValue] = key.split(":");
  if (!id || !apiValue || typeof pin.extension !== "string" || !pin.extension) {
    return null;
  }

  return `${booruPath}/${apiValue}/images/${id}.${pin.extension}`;
};

const getCachePath = (pin: PinLike): string | null => {
  const key = getPinKey(pin);
  if (!key) return null;

  const [id, apiValue] = key.split(":");
  if (!id || !apiValue) return null;

  return `${FASTFETCH_CACHE_DIR}/${GENERATED_PREFIX}${sanitizeSegment(apiValue)}-${id}.webp`;
};

const fileExists = (path: string): boolean => {
  return Gio.File.new_for_path(path).query_exists(null);
};

const removeStaleGeneratedPins = async (expectedPaths: Set<string>) => {
  const cacheDir = Gio.File.new_for_path(FASTFETCH_CACHE_DIR);
  if (!cacheDir.query_exists(null)) return;

  const enumerator = cacheDir.enumerate_children(
    "standard::name,standard::type",
    Gio.FileQueryInfoFlags.NONE,
    null,
  );

  let info = enumerator.next_file(null);
  while (info) {
    if (info.get_file_type() === Gio.FileType.REGULAR) {
      const name = info.get_name();
      if (name?.startsWith(GENERATED_PREFIX) && name.endsWith(".webp")) {
        const path = `${FASTFETCH_CACHE_DIR}/${name}`;
        if (!expectedPaths.has(path)) {
          try {
            Gio.File.new_for_path(path).delete(null);
          } catch (err) {
            console.warn(
              `[fastfetch] Failed to remove stale pin cache ${path}`,
              err,
            );
          }
        }
      }
    }

    info = enumerator.next_file(null);
  }

  enumerator.close(null);
};

const syncPinsToFastfetchCache = async () => {
  const pins = (globalSettings.peek().booru.pins ?? []) as PinLike[];
  BooruImage.syncPinCache(pins as Array<Partial<BooruImage>>);

  await execAsync(["mkdir", "-p", FASTFETCH_CACHE_DIR]);

  const expectedPaths = new Set<string>();

  for (const pin of pins) {
    const sourcePath = getSourcePath(pin);
    const cachePath = getCachePath(pin);
    if (!sourcePath || !cachePath) continue;

    expectedPaths.add(cachePath);

    if (!fileExists(sourcePath)) {
      continue;
    }

    if (fileExists(cachePath)) {
      continue;
    }

    const radius = `%[fx:min(w,h)*${CORNER_RADIUS_PERCENT / 100}]`;

    try {
      await execAsync([
        "magick",
        sourcePath,
        "-alpha",
        "set",
        "(",
        "+clone",
        "-alpha",
        "transparent",
        "-background",
        "none",
        "-fill",
        "white",
        "-draw",
        `roundrectangle 0,0,%[fx:w-1],%[fx:h-1],${radius},${radius}`,
        ")",
        "-compose",
        "Dst_In",
        "-composite",
        "-strip",
        "-quality",
        "82",
        "-define",
        "webp:method=6",
        "-define",
        "webp:alpha-quality=90",
        "-background",
        "none",
        cachePath,
      ]);
    } catch (err) {
      console.warn(
        `[fastfetch] Failed to build cache for pinned image ${sourcePath}`,
        err,
      );
    }
  }

  await removeStaleGeneratedPins(expectedPaths);
  await execAsync(["bash", "-c", "pkill -SIGUSR1 zsh || true"]);
};

const runSync = async () => {
  if (syncInProgress) {
    resyncQueued = true;
    return;
  }

  syncInProgress = true;

  try {
    do {
      resyncQueued = false;
      await syncPinsToFastfetchCache();
    } while (resyncQueued);
  } catch (err) {
    console.warn("[fastfetch] Pin sync failed", err);
  } finally {
    syncInProgress = false;
  }
};

const scheduleSync = () => {
  if (debounceSourceId) {
    GLib.source_remove(debounceSourceId);
  }

  debounceSourceId = GLib.timeout_add(
    GLib.PRIORITY_DEFAULT,
    DEBOUNCE_MS,
    () => {
      debounceSourceId = 0;
      void runSync();
      return GLib.SOURCE_REMOVE;
    },
  );
};

export const startFastfetchPinsSync = () => {
  if (started) return;
  started = true;

  const initialPins = (globalSettings.peek().booru.pins ?? []) as PinLike[];
  BooruImage.syncPinCache(initialPins as Array<Partial<BooruImage>>);
  lastPinsSignature = getPinsSignature(initialPins);
  scheduleSync();

  globalSettings.subscribe(() => {
    const pins = (globalSettings.peek().booru.pins ?? []) as PinLike[];
    BooruImage.syncPinCache(pins as Array<Partial<BooruImage>>);

    const signature = getPinsSignature(pins);
    if (signature === lastPinsSignature) return;

    lastPinsSignature = signature;
    scheduleSync();
  });
};
