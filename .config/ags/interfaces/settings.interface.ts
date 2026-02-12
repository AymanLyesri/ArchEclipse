import { Astal } from "ags/gtk4";
import { Waifu } from "../classes/BooruImage";
import { Api } from "./api.interface";
import { WidgetSelector } from "./widgetSelector.interface";

export interface AGSSetting {
  name: string;
  value: any;
  type: "int" | "float" | "string" | "bool" | "select";
  min: number;
  max: number;
}

export interface Settings {
  dateFormat: string;
  hyprsunset: {
    kelvin: number;
  };
  hyprland: {
    general: {
      border_size: AGSSetting;
      gaps_in: AGSSetting;
      gaps_out: AGSSetting;
    };
    decoration: {
      rounding: AGSSetting;
      active_opacity: AGSSetting;
      inactive_opacity: AGSSetting;
      blur: {
        enabled: AGSSetting;
        size: AGSSetting;
        passes: AGSSetting;
        xray?: AGSSetting;
      };
      shadow: {
        enabled: AGSSetting;
        range: AGSSetting;
        render_power: AGSSetting;
      };
    };
  };
  notifications: {
    dnd: boolean;
  };
  ui: {
    opacity: AGSSetting;
    scale: AGSSetting;
    fontSize: AGSSetting;
  };
  autoWorkspaceSwitching: AGSSetting;
  bar: {
    lock: boolean;
    orientation: AGSSetting;
    layout: WidgetSelector[];
  };
  waifuWidget: {
    visibility: boolean;
    input_history: string;
    current: Waifu;
    api: Api;
  };
  rightPanel: {
    exclusivity: boolean;
    width: number;
    widgets: WidgetSelector[];
    lock: boolean;
  };
  chatBot: {
    api: Api;
    imageGeneration: boolean;
  };
  booru: {
    api: Api;
    tags: string[];
    limit: number;
    page: number;
    columns: number;
    bookmarks: Waifu[];
  };
  leftPanel: {
    exclusivity: boolean;
    width: number;
    lock: boolean;
    widget: WidgetSelector;
  };
  crypto: {
    favorite: {
      symbol: string;
      timeframe: string;
    };
  };
  fileManager: string;
  keyStrokeVisualizer: {
    visibility: AGSSetting;
    anchor: AGSSetting;
  };
  wallpaperSwitcher: {
    category: string;
  };
}
