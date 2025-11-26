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
import { createBinding, createState, createComputed } from "ags";
import { createPoll } from "ags/time";
import GLib from "gi://GLib";
import { writeJSONFile } from "./utils/json";
import { AGSSetting, Settings } from "./interfaces/settings.interface";
import { Api } from "./interfaces/api.interface";
import { Waifu } from "./interfaces/waifu.interface";
import { getGlobalTheme } from "./utils/theme";
import { phi, phi_min } from "./constants/phi.constants";

export const NOTIFICATION_DELAY = phi * 3000;

const [globalSettings, _setGlobalSettings] =
  createState<Settings>(defaultSettings);
autoCreateSettings();
function setGlobalSettings(value: Settings) {
  _setGlobalSettings(value);
  writeJSONFile(settingsPath, value);
}
export { globalSettings, setGlobalSettings };

const [globalOpacity, _setGlobalOpacity] = createState<AGSSetting>(
  getSetting("globalOpacity")
);
function setGlobalOpacity(value: AGSSetting) {
  _setGlobalOpacity(value);
  setSetting("globalOpacity", value);
  refreshCss();
}
export { globalOpacity, setGlobalOpacity };

const [globalIconSize, _setGlobalIconSize] = createState<AGSSetting>(
  getSetting("globalIconSize")
);
function setGlobalIconSize(value: AGSSetting) {
  _setGlobalIconSize(value);
  setSetting("globalIconSize", value);
  refreshCss();
}
export { globalIconSize, setGlobalIconSize };

const [globalScale, _setGlobalScale] = createState<AGSSetting>(
  getSetting("globalScale")
);
function setGlobalScale(value: AGSSetting) {
  _setGlobalScale(value);
  setSetting("globalScale", value);
  refreshCss();
}
export { globalScale, setGlobalScale };

const [globalFontSize, _setGlobalFontSize] = createState<AGSSetting>(
  getSetting("globalFontSize")
);
function setGlobalFontSize(value: AGSSetting) {
  _setGlobalFontSize(value);
  setSetting("globalFontSize", value);
  refreshCss();
}
export { globalFontSize, setGlobalFontSize };

const [autoWorkspaceSwitching, _setAutoWorkspaceSwitching] =
  createState<AGSSetting>(getSetting("autoWorkspaceSwitching"));
function setAutoWorkspaceSwitching(value: AGSSetting) {
  _setAutoWorkspaceSwitching(value);
  setSetting("autoWorkspaceSwitching", value);
}
export { autoWorkspaceSwitching, setAutoWorkspaceSwitching };

export const [globalTheme, setGlobalTheme] = createState<boolean>(false);
getGlobalTheme();

export const globalMargin = phi * 10;
export const globalTransition = phi * 300;

const [dateFormat, _setDateFormat] = createState<string>(
  getSetting("dateFormat")
);
export const date_less = createPoll(
  "",
  phi * 1000,
  () => GLib.DateTime.new_now_local().format(dateFormat)!
);
export const date_more = createPoll(
  "",
  phi * 1000,
  () => GLib.DateTime.new_now_local().format(":%S %b %e, %A.")!
);
function setDateFormat(value: string) {
  _setDateFormat(value);
  setSetting("date.format", value);
}
export { dateFormat, setDateFormat };

const [barVisibility, _setBarVisibility] = createState<boolean>(
  getSetting("bar.visibility")
);
function setBarVisibility(value: boolean) {
  _setBarVisibility(value);
  setSetting("bar.visibility", value);
}
export { barVisibility, setBarVisibility };

const [barLock, _setBarLock] = createState<boolean>(getSetting("bar.lock"));
function setBarLock(value: boolean) {
  _setBarLock(value);
  setSetting("bar.lock", value);
}
export { barLock, setBarLock };

const [barOrientation, _setBarOrientation] = createState<boolean>(
  getSetting("bar.orientation")
);
function setBarOrientation(value: boolean) {
  _setBarOrientation(value);
  setSetting("bar.orientation", value);
}
export { barOrientation, setBarOrientation };

const [barLayout, _setBarLayout] = createState<WidgetSelector[]>(
  getSetting("bar.layout")
);
function setBarLayout(value: WidgetSelector[]) {
  _setBarLayout(value);
  setSetting("bar.layout", value);
}
export { barLayout, setBarLayout };

const [waifuApi, _setWaifuApi] = createState<Api>(getSetting("waifu.api"));
function setWaifuApi(value: Api) {
  _setWaifuApi(value);
  setSetting("waifu.api", value);
}
export { waifuApi, setWaifuApi };

const [waifuCurrent, _setWaifuCurrent] = createState<Waifu>(
  getSetting("waifu.current")
);
function setWaifuCurrent(value: Waifu) {
  _setWaifuCurrent(value);
  setSetting("waifu.current", value);
}
export { waifuCurrent, setWaifuCurrent };

export const focusedClient = createBinding(hyprland, "focusedClient");
export const emptyWorkspace = createComputed(() => !focusedClient());
export const focusedWorkspace = createBinding(hyprland, "focusedWorkspace");

export const [newAppWorkspace, setNewAppWorkspace] = createState(0);

const [rightPanelVisibility, _setRightPanelVisibility] = createState<boolean>(
  getSetting("rightPanel.visibility")
);
function setRightPanelVisibility(value: boolean) {
  _setRightPanelVisibility(value);
  setSetting("rightPanel.visibility", value);
}
export { rightPanelVisibility, setRightPanelVisibility };

const [rightPanelExclusivity, _setRightPanelExclusivity] = createState<boolean>(
  getSetting("rightPanel.exclusivity")
);
function setRightPanelExclusivity(value: boolean) {
  _setRightPanelExclusivity(value);
  setSetting("rightPanel.exclusivity", value);
}
export { rightPanelExclusivity, setRightPanelExclusivity };

const [rightPanelWidth, _setRightPanelWidth] = createState<number>(
  getSetting("rightPanel.width")
);
function setRightPanelWidth(value: number) {
  _setRightPanelWidth(value);
  setSetting("rightPanel.width", value);
}
export { rightPanelWidth, setRightPanelWidth };

const [rightPanelLock, _setRightPanelLock] = createState<boolean>(
  getSetting("rightPanel.lock")
);
function setRightPanelLock(value: boolean) {
  _setRightPanelLock(value);
  setSetting("rightPanel.lock", value);
}
export { rightPanelLock, setRightPanelLock };

const [DND, _setDND] = createState<boolean>(getSetting("notifications.dnd"));
function setDND(value: boolean) {
  _setDND(value);
  setSetting("notifications.dnd", value);
}
export { DND, setDND };

export const widgetLimit = 6;
const [rightPanelWidgets, _setRightPanelWidgets] = createState<
  WidgetSelector[]
>(getSetting("rightPanel.widgets"));
function setRightPanelWidgets(value: WidgetSelector[]) {
  _setRightPanelWidgets(value);
  setSetting("rightPanel.widgets", value);
}
export { rightPanelWidgets, setRightPanelWidgets };

const [leftPanelVisibility, _setLeftPanelVisibility] = createState<boolean>(
  getSetting("leftPanel.visibility")
);
function setLeftPanelVisibility(value: boolean) {
  _setLeftPanelVisibility(value);
  setSetting("leftPanel.visibility", value);
}
export { leftPanelVisibility, setLeftPanelVisibility };

const [leftPanelExclusivity, _setLeftPanelExclusivity] = createState<boolean>(
  getSetting("leftPanel.exclusivity")
);
function setLeftPanelExclusivity(value: boolean) {
  _setLeftPanelExclusivity(value);
  setSetting("leftPanel.exclusivity", value);
}
export { leftPanelExclusivity, setLeftPanelExclusivity };

const [leftPanelWidth, _setLeftPanelWidth] = createState<number>(
  getSetting("leftPanel.width")
);
function setLeftPanelWidth(value: number) {
  _setLeftPanelWidth(value);
  setSetting("leftPanel.width", value);
}
export { leftPanelWidth, setLeftPanelWidth };

const [leftPanelLock, _setLeftPanelLock] = createState<boolean>(
  getSetting("leftPanel.lock")
);
function setLeftPanelLock(value: boolean) {
  _setLeftPanelLock(value);
  setSetting("leftPanel.lock", value);
}
export { leftPanelLock, setLeftPanelLock };

const [leftPanelWidget, _setLeftPanelWidget] = createState<WidgetSelector>(
  getSetting("leftPanel.widget")
);
function setLeftPanelWidget(value: WidgetSelector) {
  _setLeftPanelWidget(value);
  setSetting("leftPanel.widget", value);
}
export { leftPanelWidget, setLeftPanelWidget };

const [chatBotApi, _setChatBotApi] = createState<Api>(
  getSetting("chatBot.api")
);
function setChatBotApi(value: Api) {
  _setChatBotApi(value);
  setSetting("chatBot.api", value);
}
export { chatBotApi, setChatBotApi };

const [chatBotImageGeneration, _setChatBotImageGeneration] =
  createState<boolean>(getSetting("chatBot.imageGeneration"));
function setChatBotImageGeneration(value: boolean) {
  _setChatBotImageGeneration(value);
  setSetting("chatBot.imageGeneration", value);
}
export { chatBotImageGeneration, setChatBotImageGeneration };

const [booruApi, _setBooruApi] = createState<Api>(getSetting("booru.api"));
function setBooruApi(value: Api) {
  _setBooruApi(value);
  setSetting("booru.api", value);
}
export { booruApi, setBooruApi };

const [booruTags, _setBooruTags] = createState<string[]>(
  getSetting("booru.tags")
);
function setBooruTags(value: string[]) {
  _setBooruTags(value);
  setSetting("booru.tags", value);
}
export { booruTags, setBooruTags };

const [booruLimit, _setBooruLimit] = createState<number>(
  getSetting("booru.limit")
);
function setBooruLimit(value: number) {
  _setBooruLimit(value);
  setSetting("booru.limit", value);
}
export { booruLimit, setBooruLimit };

const [booruPage, _setBooruPage] = createState<number>(
  getSetting("booru.page")
);
function setBooruPage(value: number) {
  _setBooruPage(value);
  setSetting("booru.page", value);
}
export { booruPage, setBooruPage };

const [screenShotVisibility, _setScreenShotVisibility] =
  createState<boolean>(false);
function setScreenShotVisibility(value: boolean) {
  _setScreenShotVisibility(value);
  if (value) {
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 5000 * phi, () => {
      _setScreenShotVisibility(false);
      return false;
    });
  }
}
export { screenShotVisibility, setScreenShotVisibility };
