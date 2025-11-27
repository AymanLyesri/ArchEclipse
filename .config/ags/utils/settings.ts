import { execAsync } from "ags/process";
import { readJSONFile, writeJSONFile } from "./json";
import { Settings } from "../interfaces/settings.interface";
import { defaultSettings } from "../constants/settings.constants";

export const settingsPath = "./assets/settings/settings.json";

function deepMergePreserveStructure(target: any, source: any): any {
  // Fast path for non-object cases
  if (source === undefined) return target;
  if (typeof target !== "object" || target === null || Array.isArray(target)) {
    return source !== undefined ? source : target;
  }

  // Check if we need to do any merging at all
  if (typeof source !== "object" || source === null || Array.isArray(source)) {
    return target;
  }

  // Optimized object creation and property copying
  const result: Record<string, any> = Object.create(
    Object.getPrototypeOf(target)
  );

  // Cache target keys for faster iteration
  const targetKeys = Object.keys(target);

  for (let i = 0; i < targetKeys.length; i++) {
    const key = targetKeys[i];
    const targetValue = target[key];
    const sourceValue = source[key];

    // Fast path for primitive values
    if (
      typeof targetValue !== "object" ||
      targetValue === null ||
      Array.isArray(targetValue)
    ) {
      result[key] = sourceValue !== undefined ? sourceValue : targetValue;
      continue;
    }

    // Recursive case for objects
    if (
      typeof sourceValue === "object" &&
      sourceValue !== null &&
      !Array.isArray(sourceValue)
    ) {
      result[key] = deepMergePreserveStructure(targetValue, sourceValue);
    } else {
      result[key] = sourceValue !== undefined ? sourceValue : targetValue;
    }
  }

  return result;
}

// Settings are stored in a json file, containing all the settings, check if it exists, if not, create it
export function autoCreateSettings(
  globalSettings: Settings,
  setGlobalSettings: (value: Settings) => void
) {
  print("Checking settings file...");
  try {
    const existingSettings = readJSONFile(settingsPath);
    if (Object.keys(existingSettings).length !== 0) {
      print("Settings file found, loading...");
      setGlobalSettings(
        deepMergePreserveStructure(defaultSettings, existingSettings)
      );
    } else {
      print("Settings file is empty, creating default settings...");
      writeJSONFile(settingsPath, defaultSettings);
      setGlobalSettings(defaultSettings);
    }
  } catch (e) {
    print("Settings file not found, creating one...");
    writeJSONFile(settingsPath, defaultSettings);
    setGlobalSettings(defaultSettings);
  }
}

export function setSetting(
  key: string,
  value: any,
  globalSettings: Settings,
  setGlobalSettings: (value: Settings) => void
): any {
  let o: any = globalSettings;
  key
    .split(".")
    .reduce(
      (o, k, i, arr) => (o[k] = i === arr.length - 1 ? value : o[k] || {}),
      o
    );

  setGlobalSettings({ ...o });
}

export function getSetting(key: string, globalSettings: Settings): any {
  // returns the value of the key in the settings
  return key.split(".").reduce((o: any, k) => o?.[k], globalSettings);
}

export function exportSettings() {
  execAsync(`bash -c 'cat ${settingsPath} | wl-copy'`);
}
