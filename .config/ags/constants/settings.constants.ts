import {
  barWidgetSelectors,
  leftPanelWidgetSelectors,
  rightPanelWidgetSelectors,
} from "../constants/widget.constants";
import { booruApis, chatBotApis } from "../constants/api.constants";
import { WaifuClass } from "../interfaces/waifu.interface";
import { dateFormats } from "../constants/date.constants";
import { phi, phi_min } from "../constants/phi.constants";
import { Settings } from "../interfaces/settings.interface";

export const defaultSettings: Settings = {
  dateFormat: dateFormats[0],
  hyprsunset: {
    kelvin: 6500, // leave as is
  },
  hyprland: {
    general: {
      border_size: { value: 0, min: 0, max: 10, type: "int" },
      gaps_in: { value: 7, min: 0, max: 20, type: "int" },
      gaps_out: { value: 10, min: 0, max: 40, type: "int" },
    },

    decoration: {
      rounding: { value: Math.round(phi * 10), min: 0, max: 50, type: "int" }, // already φ-based
      active_opacity: { value: 0.9, min: 0, max: 1, type: "float" }, // φ_min + small tweak
      inactive_opacity: { value: 0.8, min: 0, max: 1, type: "float" }, // φ_min - small tweak
      blur: {
        enabled: { value: true, type: "bool", min: 0, max: 1 },
        size: { value: Math.round(phi * 2), type: "int", min: 0, max: 10 }, // 3 → φ*2 ≈ 3
        passes: { value: Math.round(phi * 2), type: "int", min: 0, max: 10 },
        xray: { value: false, type: "bool", min: 0, max: 1 },
      },
      shadow: {
        enabled: { value: true, type: "bool", min: 0, max: 1 },
        range: { value: 15, type: "int", min: 0, max: 20 }, // 6 → φ*4 ≈ 6
        render_power: { value: 3, type: "int", min: 0, max: 20 },
      },
    },
  },
  notifications: {
    dnd: false,
  },
  globalOpacity: {
    name: "Opacity",
    value: phi_min, // 0.618 instead of 0.5
    type: "float",
    min: 0,
    max: 1,
  },
  globalScale: {
    name: "Scale",
    value: Math.round(phi * 6), // 10 → φ*6 ≈ 9.7 → 10
    type: "int",
    min: 10,
    max: 30,
  },
  globalFontSize: {
    name: "Font Size",
    value: 12, // 12 → φ*7 ≈ 11.3 → 12
    type: "int",
    min: 10,
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
    orientation: {
      name: "Orientation",
      value: true,
      type: "bool",
      min: 0,
      max: 1,
    },
    layout: barWidgetSelectors,
  },
  waifu: {
    input_history: "",
    visibility: true,
    current: undefined,
    api: booruApis[0],
  },
  rightPanel: {
    exclusivity: true,
    lock: true,
    width: Math.round(300 * phi_min), // 300 → 300*0.618 ≈ 185
    visibility: false,
    widgets: rightPanelWidgetSelectors,
  },
  leftPanel: {
    exclusivity: true,
    lock: true,
    width: Math.round(400 * phi), // 400 → 400*1.618 ≈ 647
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
    limit: Math.round(20 * phi_min), // 20 → 20*0.618 ≈ 12
    page: 1,
    columns: 3,
    bookMarkWaifus: [] as WaifuClass[],
  },
  crypto: {
    favorite: {
      symbol: "",
      timeframe: "",
    },
  },
};
