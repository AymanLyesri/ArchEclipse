import { execAsync } from "astal";
import { readJSONFile, writeJSONFile } from "./json";
import { globalSettings } from "../variables";
import { Settings } from "../interfaces/settings.interface";
import {
  barWidgetSelectors,
  leftPanelWidgetSelectors,
} from "../constants/widget.constants";
import { booruApis, chatBotApis } from "../constants/api.constants";
import { WaifuClass } from "../interfaces/waifu.interface";
import { dateFormats } from "../constants/date.constants";
export const settingsPath = "./assets/settings/settings.json";

export const defaultSettings: Settings = {
  dateFormat: dateFormats[0],
  hyprsunset: {
    kelvin: 6500,
  },
  hyprland: {
    decoration: {
      rounding: { value: 15, min: 0, max: 50, type: "int" },
      active_opacity: { value: 0.8, min: 0, max: 1, type: "float" },
      inactive_opacity: { value: 0.5, min: 0, max: 1, type: "float" },
      blur: {
        enabled: { value: true, type: "bool", min: 0, max: 1 },
        size: { value: 3, type: "int", min: 0, max: 10 },
        passes: { value: 3, type: "int", min: 0, max: 10 },
      },
    },
  },
  notifications: {
    dnd: false,
  },
  globalOpacity: {
    name: "Global Opacity",
    value: 0.5,
    type: "float",
    min: 0,
    max: 1,
  },
  globalIconSize: {
    name: "Global Icon Size",
    value: 10,
    type: "int",
    min: 5,
    max: 20,
  },
  globalScale: {
    name: "Global Scale",
    value: 10,
    type: "int",
    min: 10,
    max: 30,
  },
  globalFontSize: {
    name: "Global Font Size",
    value: 12,
    type: "int",
    min: 12,
    max: 30,
  },
  autoWorkspaceSwitching: {
    name: "Auto Workspace Switching",
    value: true,
    type: "bool",
    min: 0,
    max: 1,
  },
  bar: {
    visibility: true,
    lock: true,
    orientation: true,
    layout: barWidgetSelectors,
  },
  waifu: {
    input_history: "",
    visibility: true,
    current: new WaifuClass(),
    api: booruApis[0],
  },
  rightPanel: {
    exclusivity: true,
    lock: true,
    width: 300,
    visibility: false,
    widgets: [],
  },
  leftPanel: {
    exclusivity: true,
    lock: true,
    width: 400,
    visibility: false,
    widget: leftPanelWidgetSelectors[0],
  },
  chatBot: {
    api: chatBotApis[0],
    imageGeneration: false,
  },
  booru: {
    api: booruApis[0],
    tags: [],
    limit: 20,
    page: 1,
  },
};

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
export function autoCreateSettings() {
  if (Object.keys(readJSONFile(settingsPath)).length !== 0) {
    globalSettings.set(
      deepMergePreserveStructure(defaultSettings, readJSONFile(settingsPath))
    );
  } else {
    writeJSONFile(settingsPath, globalSettings.get());
  }
}

export function setSetting(key: string, value: any): any {
  let o: any = globalSettings.get();
  key
    .split(".")
    .reduce(
      (o, k, i, arr) => (o[k] = i === arr.length - 1 ? value : o[k] || {}),
      o
    );

  globalSettings.set({ ...o });
}

export function getSetting(key: string): any {
  // returns the value of the key in the settings
  return key.split(".").reduce((o: any, k) => o?.[k], globalSettings.get());
}

export function exportSettings() {
  execAsync(`bash -c 'cat ${settingsPath} | wl-copy'`);
}
