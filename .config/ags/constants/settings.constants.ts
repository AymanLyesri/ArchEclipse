import {
  barWidgetSelectors,
  leftPanelWidgetSelectors,
  rightPanelWidgetSelectors,
} from "../constants/widget.constants";
import { booruApis, chatBotApis } from "../constants/api.constants";
import { BooruImage } from "../classes/BooruImage";
import { dateFormats } from "../constants/date.constants";
import { phi, phi_min } from "../constants/phi.constants";
import { Settings } from "../interfaces/settings.interface";
import { Astal } from "ags/gtk4";

export const defaultSettings: Settings = {
  dateFormat: dateFormats[0],
  hyprsunset: {
    kelvin: 6500, // leave as is
  },
  hyprland: {
    general: {
      border_size: {
        name: "Border Size",
        value: 0,
        min: 0,
        max: 10,
        type: "int",
      },
      gaps_in: {
        name: "Gaps In",
        value: 7,
        min: 0,
        max: 20,
        type: "int",
      },
      gaps_out: {
        name: "Gaps Out",
        value: 10,
        min: 0,
        max: 40,
        type: "int",
      },
    },

    decoration: {
      rounding: {
        name: "Rounding",
        value: Math.round(phi * 10),
        min: 0,
        max: 50,
        type: "int",
      }, // already φ-based
      active_opacity: {
        name: "Active Opacity",
        value: 0.9,
        min: 0,
        max: 1,
        type: "float",
      }, // φ_min + small tweak
      inactive_opacity: {
        name: "Inactive Opacity",
        value: 0.8,
        min: 0,
        max: 1,
        type: "float",
      }, // φ_min - small tweak
      blur: {
        enabled: {
          name: "Blur Enabled",
          value: true,
          type: "bool",
          min: 0,
          max: 1,
        },
        size: {
          name: "Blur Size",
          value: 4,
          type: "int",
          min: 0,
          max: 10,
        }, // 3 → φ*2 ≈ 3
        passes: {
          name: "Blur Passes",
          value: 4,
          type: "int",
          min: 0,
          max: 10,
        },
        xray: { name: "Blur Xray", value: false, type: "bool", min: 0, max: 1 },
      },
      shadow: {
        enabled: {
          name: "Shadow Enabled",
          value: true,
          type: "bool",
          min: 0,
          max: 1,
        },
        range: {
          name: "Shadow Range",
          value: 15,
          type: "int",
          min: 0,
          max: 20,
        }, // 6 → φ*4 ≈ 6
        render_power: {
          name: "Shadow Render Power",
          value: 3,
          type: "int",
          min: 0,
          max: 20,
        },
      },
    },
  },
  notifications: {
    dnd: false,
  },
  ui: {
    opacity: {
      name: "Opacity",
      value: phi_min, // 0.618 instead of 0.5
      type: "float",
      min: 0,
      max: 1,
    },
    scale: {
      name: "Scale",
      value: Math.round(phi * 6), // 10 → φ*6 ≈ 9.7 → 10
      type: "int",
      min: 10,
      max: 30,
    },
    fontSize: {
      name: "Font Size",
      value: 12, // 12 → φ*7 ≈ 11.3 → 12
      type: "int",
      min: 10,
      max: 30,
    },
  },
  autoWorkspaceSwitching: {
    name: "Auto Workspace Switching",
    value: true,
    type: "bool",
    min: 0,
    max: 1,
  },
  bar: {
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
  waifuWidget: {
    input_history: "",
    visibility: true,
    current: new BooruImage(),
    api: booruApis[0],
  },
  rightPanel: {
    exclusivity: true,
    lock: false,
    width: 250,
    widgets: rightPanelWidgetSelectors,
  },
  leftPanel: {
    exclusivity: true,
    lock: false,
    width: 400,
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
    columns: 2,
    bookmarks: [],
  },
  crypto: {
    favorite: {
      symbol: "",
      timeframe: "",
    },
  },
  fileManager: "nautilus",
  keyStrokeVisualizer: {
    visibility: {
      name: "Key Stroke Visualizer Visibility",
      value: false,
      type: "bool",
      min: 0,
      max: 1,
    },
    anchor: {
      name: "Key Stroke Visualizer Anchor",
      value: ["bottom"],
      type: "select",
      min: 0,
      max: 0,
    },
  },
};
