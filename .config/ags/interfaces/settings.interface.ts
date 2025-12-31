import { Api } from "./api.interface";
import { Waifu } from "./waifu.interface";
import { WidgetSelector } from "./widgetSelector.interface";

export interface HyprlandSetting {
  value: any;
  type: string;
  min: number;
  max: number;
}

export interface AGSSetting {
  name: string;
  value: any;
  type: string;
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
      border_size: HyprlandSetting;
      gaps_in: HyprlandSetting;
      gaps_out: HyprlandSetting;
    };
    decoration: {
      rounding: HyprlandSetting;
      active_opacity: HyprlandSetting;
      inactive_opacity: HyprlandSetting;
      blur: {
        enabled: HyprlandSetting;
        size: HyprlandSetting;
        passes: HyprlandSetting;
        xray?: HyprlandSetting;
      };
      shadow: {
        enabled: HyprlandSetting;
        range: HyprlandSetting;
        render_power: HyprlandSetting;
      };
    };
  };
  notifications: {
    dnd: boolean;
  };
  globalOpacity: AGSSetting;
  globalScale: AGSSetting;
  globalFontSize: AGSSetting;
  autoWorkspaceSwitching: AGSSetting;
  bar: {
    visibility: boolean;
    lock: boolean;
    orientation: AGSSetting;
    layout: WidgetSelector[];
  };
  waifu: {
    visibility: boolean;
    input_history: string;
    current: Waifu | undefined;
    api: Api;
  };
  rightPanel: {
    visibility: boolean;
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
    bookMarkWaifus: Waifu[];
  };
  leftPanel: {
    visibility: boolean;
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
}
