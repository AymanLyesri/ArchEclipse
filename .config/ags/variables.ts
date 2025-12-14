import {
  autoCreateSettings,
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
import { phi, phi_min } from "./constants/phi.constants";
import { defaultSettings } from "./constants/settings.constants";
import { exec, execAsync } from "ags/process";
import { switchGlobalTheme } from "./utils/theme";

export const NOTIFICATION_DELAY = phi * 3000;

const [globalSettings, _setGlobalSettings] =
  createState<Settings>(defaultSettings);

print("Loading variables...1");

// Initialize settings after creating the state
autoCreateSettings(globalSettings.get(), setGlobalSettings);

print("Loading variables...2");

function setGlobalSettings(value: Settings) {
  _setGlobalSettings(value);
  writeJSONFile(settingsPath, value);
}
export { globalSettings, setGlobalSettings };

function printAllSettings(_: any) {
  console.log("=== Global Settings ===");
  console.log(JSON.stringify(_.get(), null, 2));
}

export { printAllSettings };

const [globalOpacity, _setGlobalOpacity] = createState<AGSSetting>(
  getSetting("globalOpacity", globalSettings.get())
);

function setGlobalOpacity(value: AGSSetting) {
  _setGlobalOpacity(value);
  setSetting("globalOpacity", value, globalSettings, setGlobalSettings);
  refreshCss();
}

export { globalOpacity, setGlobalOpacity };

const [globalIconSize, _setGlobalIconSize] = createState<AGSSetting>(
  getSetting("globalIconSize", globalSettings.get())
);
function setGlobalIconSize(value: AGSSetting) {
  _setGlobalIconSize(value);
  setSetting("globalIconSize", value, globalSettings, setGlobalSettings);
  refreshCss();
}
export { globalIconSize, setGlobalIconSize };

const [globalScale, _setGlobalScale] = createState<AGSSetting>(
  getSetting("globalScale", globalSettings.get())
);
function setGlobalScale(value: AGSSetting) {
  _setGlobalScale(value);
  setSetting("globalScale", value, globalSettings, setGlobalSettings);
  refreshCss();
}
export { globalScale, setGlobalScale };

const [globalFontSize, _setGlobalFontSize] = createState<AGSSetting>(
  getSetting("globalFontSize", globalSettings.get())
);
function setGlobalFontSize(value: AGSSetting) {
  _setGlobalFontSize(value);
  setSetting("globalFontSize", value, globalSettings, setGlobalSettings);
  refreshCss();
}
export { globalFontSize, setGlobalFontSize };

const [autoWorkspaceSwitching, _setAutoWorkspaceSwitching] =
  createState<AGSSetting>(
    getSetting("autoWorkspaceSwitching", globalSettings.get())
  );
function setAutoWorkspaceSwitching(value: AGSSetting) {
  _setAutoWorkspaceSwitching(value);
  setSetting(
    "autoWorkspaceSwitching",
    value,
    globalSettings,
    setGlobalSettings
  );
}
export { autoWorkspaceSwitching, setAutoWorkspaceSwitching };

const [globalTheme, _setGlobalTheme] = createState<boolean>(
  exec([
    "bash",
    "-c",
    "$HOME/.config/hypr/theme/scripts/system-theme.sh get",
  ]).includes("light")
);
function setGlobalTheme(value: boolean) {
  _setGlobalTheme(value);
  switchGlobalTheme(value);
}
export { globalTheme, setGlobalTheme };

export const globalMargin = phi * 10;
export const globalTransition = phi * 300;

const [dateFormat, _setDateFormat] = createState<string>(
  getSetting("dateFormat", globalSettings.get())
);
export const date_less = createPoll(
  "",
  phi * 1000,
  () => GLib.DateTime.new_now_local().format(dateFormat.get())!
);
export const date_more = createPoll(
  "",
  phi * 1000,
  () => GLib.DateTime.new_now_local().format(":%S %b %e, %A.")!
);
function setDateFormat(value: string) {
  _setDateFormat(value);
  setSetting("date.format", value, globalSettings, setGlobalSettings);
}
export { dateFormat, setDateFormat };

const [barVisibility, _setBarVisibility] = createState<boolean>(
  getSetting("bar.visibility", globalSettings.get())
);
function setBarVisibility(value: boolean) {
  _setBarVisibility(value);
  setSetting("bar.visibility", value, globalSettings, setGlobalSettings);
}
export { barVisibility, setBarVisibility };

const [barLock, _setBarLock] = createState<boolean>(
  getSetting("bar.lock", globalSettings.get())
);
function setBarLock(value: boolean) {
  _setBarLock(value);
  setSetting("bar.lock", value, globalSettings, setGlobalSettings);
}
export { barLock, setBarLock };

const [barOrientation, _setBarOrientation] = createState<boolean>(
  getSetting("bar.orientation", globalSettings.get())
);
function setBarOrientation(value: boolean) {
  _setBarOrientation(value);
  setSetting("bar.orientation", value, globalSettings, setGlobalSettings);
}
export { barOrientation, setBarOrientation };

const [barLayout, _setBarLayout] = createState<WidgetSelector[]>(
  getSetting("bar.layout", globalSettings.get())
);
function setBarLayout(value: WidgetSelector[]) {
  _setBarLayout(value);
  setSetting("bar.layout", value, globalSettings, setGlobalSettings);
}
export { barLayout, setBarLayout };

const [waifuApi, _setWaifuApi] = createState<Api>(
  getSetting("waifu.api", globalSettings.get())
);
function setWaifuApi(value: Api) {
  _setWaifuApi(value);
  setSetting("waifu.api", value, globalSettings, setGlobalSettings);
}
export { waifuApi, setWaifuApi };

const [waifuCurrent, _setWaifuCurrent] = createState<Waifu>(
  getSetting("waifu.current", globalSettings.get())
);
function setWaifuCurrent(value: Waifu) {
  _setWaifuCurrent(value);
  setSetting("waifu.current", value, globalSettings, setGlobalSettings);
}
export { waifuCurrent, setWaifuCurrent };

export const focusedClient = createBinding(hyprland, "focusedClient");
export const emptyWorkspace = focusedClient((client) => !client);
export const focusedWorkspace = createBinding(hyprland, "focusedWorkspace");

export const [newAppWorkspace, setNewAppWorkspace] = createState(0);

const [rightPanelVisibility, _setRightPanelVisibility] = createState<boolean>(
  getSetting("rightPanel.visibility", globalSettings.get())
);
function setRightPanelVisibility(value: boolean) {
  _setRightPanelVisibility(value);
  setSetting("rightPanel.visibility", value, globalSettings, setGlobalSettings);
}
export { rightPanelVisibility, setRightPanelVisibility };

const [rightPanelExclusivity, _setRightPanelExclusivity] = createState<boolean>(
  getSetting("rightPanel.exclusivity", globalSettings.get())
);
function setRightPanelExclusivity(value: boolean) {
  _setRightPanelExclusivity(value);
  setSetting(
    "rightPanel.exclusivity",
    value,
    globalSettings,
    setGlobalSettings
  );
}
export { rightPanelExclusivity, setRightPanelExclusivity };

const [rightPanelWidth, _setRightPanelWidth] = createState<number>(
  getSetting("rightPanel.width", globalSettings.get())
);
function setRightPanelWidth(value: number) {
  _setRightPanelWidth(value);
  setSetting("rightPanel.width", value, globalSettings, setGlobalSettings);
}
export { rightPanelWidth, setRightPanelWidth };

const [rightPanelLock, _setRightPanelLock] = createState<boolean>(
  getSetting("rightPanel.lock", globalSettings.get())
);
function setRightPanelLock(value: boolean) {
  _setRightPanelLock(value);
  setSetting("rightPanel.lock", value, globalSettings, setGlobalSettings);
}
export { rightPanelLock, setRightPanelLock };

const [DND, _setDND] = createState<boolean>(
  getSetting("notifications.dnd", globalSettings.get())
);
function setDND(value: boolean) {
  _setDND(value);
  setSetting("notifications.dnd", value, globalSettings, setGlobalSettings);
}
export { DND, setDND };

export const widgetLimit = 6;
const [rightPanelWidgets, _setRightPanelWidgets] = createState<
  WidgetSelector[]
>(getSetting("rightPanel.widgets", globalSettings.get()));
function setRightPanelWidgets(value: WidgetSelector[]) {
  _setRightPanelWidgets(value);
  setSetting("rightPanel.widgets", value, globalSettings, setGlobalSettings);
}
export { rightPanelWidgets, setRightPanelWidgets };

const [leftPanelVisibility, _setLeftPanelVisibility] = createState<boolean>(
  getSetting("leftPanel.visibility", globalSettings.get())
);
function setLeftPanelVisibility(value: boolean) {
  _setLeftPanelVisibility(value);
  setSetting("leftPanel.visibility", value, globalSettings, setGlobalSettings);
}
export { leftPanelVisibility, setLeftPanelVisibility };

const [leftPanelExclusivity, _setLeftPanelExclusivity] = createState<boolean>(
  getSetting("leftPanel.exclusivity", globalSettings.get())
);
function setLeftPanelExclusivity(value: boolean) {
  _setLeftPanelExclusivity(value);
  setSetting("leftPanel.exclusivity", value, globalSettings, setGlobalSettings);
}
export { leftPanelExclusivity, setLeftPanelExclusivity };

const [leftPanelWidth, _setLeftPanelWidth] = createState<number>(
  getSetting("leftPanel.width", globalSettings.get())
);
function setLeftPanelWidth(value: number) {
  _setLeftPanelWidth(value);
  setSetting("leftPanel.width", value, globalSettings, setGlobalSettings);
}
export { leftPanelWidth, setLeftPanelWidth };

const [leftPanelLock, _setLeftPanelLock] = createState<boolean>(
  getSetting("leftPanel.lock", globalSettings.get())
);
function setLeftPanelLock(value: boolean) {
  _setLeftPanelLock(value);
  setSetting("leftPanel.lock", value, globalSettings, setGlobalSettings);
}
export { leftPanelLock, setLeftPanelLock };

const [leftPanelWidget, _setLeftPanelWidget] = createState<WidgetSelector>(
  getSetting("leftPanel.widget", globalSettings.get())
);
function setLeftPanelWidget(value: WidgetSelector) {
  _setLeftPanelWidget(value);
  setSetting("leftPanel.widget", value, globalSettings, setGlobalSettings);
}
export { leftPanelWidget, setLeftPanelWidget };

const [chatBotApi, _setChatBotApi] = createState<Api>(
  getSetting("chatBot.api", globalSettings.get())
);
function setChatBotApi(value: Api) {
  _setChatBotApi(value);
  setSetting("chatBot.api", value, globalSettings, setGlobalSettings);
}
export { chatBotApi, setChatBotApi };

// const [chatBotImageGeneration, setChatBotImageGeneration] =
//   createState<boolean>(false);
// function setChatBotImageGeneration(value: boolean) {
//   _setChatBotImageGeneration(value);
//   setSetting(
//     "chatBot.imageGeneration",
//     value,
//     globalSettings,
//     setGlobalSettings
//   );
// }
// export { chatBotImageGeneration, setChatBotImageGeneration };

const [booruApi, _setBooruApi] = createState<Api>(
  getSetting("booru.api", globalSettings.get())
);
function setBooruApi(value: Api) {
  _setBooruApi(value);
  setSetting("booru.api", value, globalSettings, setGlobalSettings);
}
export { booruApi, setBooruApi };

const [booruTags, _setBooruTags] = createState<string[]>(
  getSetting("booru.tags", globalSettings.get())
);
function setBooruTags(value: string[]) {
  _setBooruTags(value);
  setSetting("booru.tags", value, globalSettings, setGlobalSettings);
}
export { booruTags, setBooruTags };

const [booruLimit, _setBooruLimit] = createState<number>(
  getSetting("booru.limit", globalSettings.get())
);
function setBooruLimit(value: number) {
  _setBooruLimit(value);
  setSetting("booru.limit", value, globalSettings, setGlobalSettings);
}
export { booruLimit, setBooruLimit };

const [booruPage, _setBooruPage] = createState<number>(
  getSetting("booru.page", globalSettings.get())
);
function setBooruPage(value: number) {
  _setBooruPage(value);
  setSetting("booru.page", value, globalSettings, setGlobalSettings);
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
