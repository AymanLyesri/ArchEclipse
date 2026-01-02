import { readJSONFile, writeJSONFile } from "./json";
import { Settings } from "../interfaces/settings.interface";
import { defaultSettings } from "../constants/settings.constants";

export const settingsPath = "./assets/settings/settings.json";

function detectMergeKey(a: any[], b: any[]): string | null {
  const candidates = ["id", "name", "key", "uuid"];

  for (const key of candidates) {
    if (
      a.every((x) => typeof x?.[key] === "string") &&
      b.every((x) => typeof x?.[key] === "string")
    ) {
      return key;
    }
  }

  return null;
}

function mergeArraysAuto(defaults: any[], saved: any[]): any[] {
  // Empty saved → defaults win
  if (saved.length === 0) return defaults;

  // Detect merge key automatically
  const mergeKey = detectMergeKey(defaults, saved);

  // No stable key → keep saved (user intent)
  if (!mergeKey) return saved;

  const savedMap = new Map(saved.map((item) => [item[mergeKey], item]));

  return defaults.map((def) => {
    const user = savedMap.get(def[mergeKey]);
    return user ? deepMergeAuto(def, user) : def;
  });
}

function deepMergeAuto(target: any, source: any): any {
  if (source === undefined) return target;

  // Primitive or function → source wins
  if (
    typeof target !== "object" ||
    target === null ||
    typeof source !== "object" ||
    source === null
  ) {
    return source;
  }

  // Array handling
  if (Array.isArray(target) && Array.isArray(source)) {
    return mergeArraysAuto(target, source);
  }

  // Object handling
  const result: any = Array.isArray(target) ? [] : {};

  for (const key of Object.keys(target)) {
    result[key] = deepMergeAuto(target[key], source[key]);
  }

  return result;
}

// Settings are stored in a json file, containing all the settings, check if it exists, if not, create it
export function autoCreateSettings(
  globalSettings: Settings,
  setGlobalSettings: (value: Settings) => void
) {
  print(`\n############ Auto Creating Settings ###########`);
  try {
    const existingSettings = readJSONFile(settingsPath);
    if (Object.keys(existingSettings).length !== 0) {
      print("\nSettings file found, loading...");
      setGlobalSettings(deepMergeAuto(defaultSettings, existingSettings));
    } else {
      print("\nSettings file is empty, creating default settings...");
      writeJSONFile(settingsPath, defaultSettings);
      setGlobalSettings(defaultSettings);
    }
  } catch (e) {
    print("\nSettings file not found, creating one...");
    writeJSONFile(settingsPath, defaultSettings);
    setGlobalSettings(defaultSettings);
  }

  print(`\n############ Settings Loaded ###########`);
}

// export function setSetting(
//   key: string,
//   value: any,
//   globalSettings: Accessor<Settings>,
//   setGlobalSettings: (value: Settings) => void
// ): any {
//   let o: any = globalSettings.get();
//   key
//     .split(".")
//     .reduce(
//       (o, k, i, arr) => (o[k] = i === arr.length - 1 ? value : o[k] || {}),
//       o
//     );

//   setGlobalSettings({ ...o });
// }

// export function getSetting(key: string, globalSettings: Settings): any {
//   // returns the value of the key in the settings
//   return key.split(".").reduce((o: any, k) => o?.[k], globalSettings);
// }

// export function exportSettings() {
//   execAsync(`bash -c 'cat ${settingsPath} | wl-copy'`);
// }
