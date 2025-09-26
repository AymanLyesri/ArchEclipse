import {
  autoCreateSettings,
  defaultSettings,
  getSetting,
  setSetting,
  settingsPath,
} from "./utils/settings";

import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

import { WidgetSelector } from "./interfaces/widgetSelector.interface";
import { refreshCss } from "./utils/scss";
import { bind, Binding, GLib, timeout, Variable } from "astal";
import { writeJSONFile } from "./utils/json";
import { AGSSetting, Settings } from "./interfaces/settings.interface";
import { Api } from "./interfaces/api.interface";
import { Waifu } from "./interfaces/waifu.interface";
import { getGlobalTheme } from "./utils/theme";

export const NOTIFICATION_DELAY = 5000;

// Settings are stored in a json file, containing all the settings, check if it exists, if not, create it
export const globalSettings = Variable<Settings>(defaultSettings);
autoCreateSettings();
globalSettings.subscribe((value) => writeJSONFile(settingsPath, value));

export const globalOpacity = Variable<AGSSetting>(getSetting("globalOpacity"));
globalOpacity.subscribe((value) => {
  setSetting("globalOpacity", value);
  refreshCss();
});
export const globalIconSize = Variable<AGSSetting>(
  getSetting("globalIconSize")
);
globalIconSize.subscribe((value) => {
  setSetting("globalIconSize", value);
  refreshCss();
});
export const globalScale = Variable<AGSSetting>(getSetting("globalScale"));
globalScale.subscribe((value) => {
  setSetting("globalScale", value);
  refreshCss();
});

export const globalFontSize = Variable<AGSSetting>(
  getSetting("globalFontSize")
);
globalFontSize.subscribe((value) => {
  setSetting("globalFontSize", value);
  refreshCss();
});

export const autoWorkspaceSwitching = Variable<AGSSetting>(
  getSetting("autoWorkspaceSwitching")
);
autoWorkspaceSwitching.subscribe((value) => {
  setSetting("autoWorkspaceSwitching", value);
});

export const globalTheme = Variable<boolean>(false);
getGlobalTheme();

export const globalMargin = 14;
export const globalTransition = 500;

export const dateFormat = Variable<string>(getSetting("dateFormat"));
export const date_less = Variable("").poll(
  1000,
  () => GLib.DateTime.new_now_local().format(dateFormat.get())!
);
export const date_more = Variable("").poll(
  1000,
  () => GLib.DateTime.new_now_local().format(":%S %b %e, %A.")!
);
dateFormat.subscribe((value) => {
  setSetting("date.format", value);
  date_less.set(GLib.DateTime.new_now_local().format(value)!);
  // date_more.set(GLib.DateTime.new_now_local().format(value)!);
});

export const barVisibility = Variable<boolean>(getSetting("bar.visibility"));
barVisibility.subscribe((value) => setSetting("bar.visibility", value));
export const barLock: Variable<boolean> = Variable(getSetting("bar.lock"));
barLock.subscribe((value) => setSetting("bar.lock", value));
export const barOrientation = Variable<boolean>(getSetting("bar.orientation"));
barOrientation.subscribe((value) => setSetting("bar.orientation", value));
export const barLayout = Variable<WidgetSelector[]>(getSetting("bar.layout"));
barLayout.subscribe((value) => setSetting("bar.layout", value));

export const waifuApi = Variable<Api>(getSetting("waifu.api"));
waifuApi.subscribe((value) => setSetting("waifu.api", value));
export const waifuCurrent = Variable<Waifu>(getSetting("waifu.current"));
waifuCurrent.subscribe((value) => setSetting("waifu.current", value));

export const focusedClient: Binding<Hyprland.Client> = bind(
  hyprland,
  "focusedClient"
);
export const emptyWorkspace: Binding<boolean> = focusedClient.as(
  (client) => !client
);
export const focusedWorkspace: Binding<Hyprland.Workspace> = bind(
  hyprland,
  "focusedWorkspace"
);

export const newAppWorkspace = Variable(0);

export const rightPanelVisibility = Variable<boolean>(
  getSetting("rightPanel.visibility")
);
rightPanelVisibility.subscribe((value) =>
  setSetting("rightPanel.visibility", value)
);
export const rightPanelExclusivity = Variable<boolean>(
  getSetting("rightPanel.exclusivity")
);
rightPanelExclusivity.subscribe((value) =>
  setSetting("rightPanel.exclusivity", value)
);
export const rightPanelWidth = Variable<number>(getSetting("rightPanel.width"));
rightPanelWidth.subscribe((value) => setSetting("rightPanel.width", value));
export const rightPanelLock = Variable<boolean>(getSetting("rightPanel.lock"));
rightPanelLock.subscribe((value) => setSetting("rightPanel.lock", value));

export const DND = Variable<boolean>(getSetting("notifications.dnd"));
DND.subscribe((value) => setSetting("notifications.dnd", value));

export const widgetLimit = 5;
export const rightPanelWidgets = Variable<WidgetSelector[]>(
  getSetting("rightPanel.widgets")
);
rightPanelWidgets.subscribe((value) => setSetting("rightPanel.widgets", value));

export const leftPanelVisibility = Variable<boolean>(
  getSetting("leftPanel.visibility")
);
leftPanelVisibility.subscribe((value) =>
  setSetting("leftPanel.visibility", value)
);
export const leftPanelExclusivity = Variable<boolean>(
  getSetting("leftPanel.exclusivity")
);
leftPanelExclusivity.subscribe((value) =>
  setSetting("leftPanel.exclusivity", value)
);
export const leftPanelWidth = Variable<number>(getSetting("leftPanel.width"));
leftPanelWidth.subscribe((value) => setSetting("leftPanel.width", value));
export const leftPanelLock = Variable<boolean>(getSetting("leftPanel.lock"));
leftPanelLock.subscribe((value) => setSetting("leftPanel.lock", value));

export const leftPanelWidget = Variable<WidgetSelector>(
  getSetting("leftPanel.widget")
);
leftPanelWidget.subscribe((value) => setSetting("leftPanel.widget", value));

export const chatBotApi = Variable<Api>(getSetting("chatBot.api"));
chatBotApi.subscribe((value) => setSetting("chatBot.api", value));
export const chatBotImageGeneration = Variable<boolean>(
  getSetting("chatBot.imageGeneration")
);
chatBotImageGeneration.subscribe((value) =>
  setSetting("chatBot.imageGeneration", value)
);

export const booruApi = Variable<Api>(getSetting("booru.api"));
booruApi.subscribe((value) => setSetting("booru.api", value));
export const booruTags = Variable<string[]>(getSetting("booru.tags"));
booruTags.subscribe((value) => setSetting("booru.tags", value));
export const booruLimit = Variable<number>(getSetting("booru.limit"));
booruLimit.subscribe((value) => setSetting("booru.limit", value));
export const booruPage = Variable<number>(getSetting("booru.page"));
booruPage.subscribe((value) => setSetting("booru.page", value));

export const screenShotVisibility = Variable<boolean>(false);
screenShotVisibility.subscribe((value) => {
  if (value) {
    timeout(5000, () => {
      screenShotVisibility.set(false);
    });
  }
});
