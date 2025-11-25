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
import {
  createBinding,
  createState,
  createEffect,
  createPoll,
  createComputed,
} from "ags";
import GLib from "gi://GLib";
import { writeJSONFile } from "./utils/json";
import { AGSSetting, Settings } from "./interfaces/settings.interface";
import { Api } from "./interfaces/api.interface";
import { Waifu } from "./interfaces/waifu.interface";
import { getGlobalTheme } from "./utils/theme";
import { phi, phi_min } from "./constants/phi.constants";

export const NOTIFICATION_DELAY = phi * 3000;

export const [globalSettings, setGlobalSettings] =
  createState<Settings>(defaultSettings);
autoCreateSettings();
createEffect(() => writeJSONFile(settingsPath, globalSettings()));

export const [globalOpacity, setGlobalOpacity] = createState<AGSSetting>(
  getSetting("globalOpacity")
);
createEffect(() => {
  setSetting("globalOpacity", globalOpacity());
  refreshCss();
});

export const [globalIconSize, setGlobalIconSize] = createState<AGSSetting>(
  getSetting("globalIconSize")
);
createEffect(() => {
  setSetting("globalIconSize", globalIconSize());
  refreshCss();
});

export const [globalScale, setGlobalScale] = createState<AGSSetting>(
  getSetting("globalScale")
);
createEffect(() => {
  setSetting("globalScale", globalScale());
  refreshCss();
});

export const [globalFontSize, setGlobalFontSize] = createState<AGSSetting>(
  getSetting("globalFontSize")
);
createEffect(() => {
  setSetting("globalFontSize", globalFontSize());
  refreshCss();
});

export const [autoWorkspaceSwitching, setAutoWorkspaceSwitching] =
  createState<AGSSetting>(getSetting("autoWorkspaceSwitching"));
createEffect(() => {
  setSetting("autoWorkspaceSwitching", autoWorkspaceSwitching());
});

export const [globalTheme, setGlobalTheme] = createState<boolean>(false);
getGlobalTheme();

export const globalMargin = phi * 10;
export const globalTransition = phi * 300;

export const [dateFormat, setDateFormat] = createState<string>(
  getSetting("dateFormat")
);
export const date_less = createPoll(
  phi * 1000,
  () => GLib.DateTime.new_now_local().format(dateFormat())!
);
export const date_more = createPoll(
  phi * 1000,
  () => GLib.DateTime.new_now_local().format(":%S %b %e, %A.")!
);
createEffect(() => {
  setSetting("date.format", dateFormat());
});

export const [barVisibility, setBarVisibility] = createState<boolean>(
  getSetting("bar.visibility")
);
createEffect(() => setSetting("bar.visibility", barVisibility()));

export const [barLock, setBarLock] = createState<boolean>(
  getSetting("bar.lock")
);
createEffect(() => setSetting("bar.lock", barLock()));

export const [barOrientation, setBarOrientation] = createState<boolean>(
  getSetting("bar.orientation")
);
createEffect(() => setSetting("bar.orientation", barOrientation()));

export const [barLayout, setBarLayout] = createState<WidgetSelector[]>(
  getSetting("bar.layout")
);
createEffect(() => setSetting("bar.layout", barLayout()));

export const [waifuApi, setWaifuApi] = createState<Api>(
  getSetting("waifu.api")
);
createEffect(() => setSetting("waifu.api", waifuApi()));

export const [waifuCurrent, setWaifuCurrent] = createState<Waifu>(
  getSetting("waifu.current")
);
createEffect(() => setSetting("waifu.current", waifuCurrent()));

export const focusedClient = createBinding(hyprland, "focusedClient");
export const emptyWorkspace = createComputed(() => !focusedClient());
export const focusedWorkspace = createBinding(hyprland, "focusedWorkspace");

export const [newAppWorkspace, setNewAppWorkspace] = createState(0);

export const [rightPanelVisibility, setRightPanelVisibility] =
  createState<boolean>(getSetting("rightPanel.visibility"));
createEffect(() => setSetting("rightPanel.visibility", rightPanelVisibility()));

export const [rightPanelExclusivity, setRightPanelExclusivity] =
  createState<boolean>(getSetting("rightPanel.exclusivity"));
createEffect(() =>
  setSetting("rightPanel.exclusivity", rightPanelExclusivity())
);

export const [rightPanelWidth, setRightPanelWidth] = createState<number>(
  getSetting("rightPanel.width")
);
createEffect(() => setSetting("rightPanel.width", rightPanelWidth()));

export const [rightPanelLock, setRightPanelLock] = createState<boolean>(
  getSetting("rightPanel.lock")
);
createEffect(() => setSetting("rightPanel.lock", rightPanelLock()));

export const [DND, setDND] = createState<boolean>(
  getSetting("notifications.dnd")
);
createEffect(() => setSetting("notifications.dnd", DND()));

export const widgetLimit = 6;
export const [rightPanelWidgets, setRightPanelWidgets] = createState<
  WidgetSelector[]
>(getSetting("rightPanel.widgets"));
createEffect(() => setSetting("rightPanel.widgets", rightPanelWidgets()));

export const [leftPanelVisibility, setLeftPanelVisibility] =
  createState<boolean>(getSetting("leftPanel.visibility"));
createEffect(() => setSetting("leftPanel.visibility", leftPanelVisibility()));

export const [leftPanelExclusivity, setLeftPanelExclusivity] =
  createState<boolean>(getSetting("leftPanel.exclusivity"));
createEffect(() => setSetting("leftPanel.exclusivity", leftPanelExclusivity()));

export const [leftPanelWidth, setLeftPanelWidth] = createState<number>(
  getSetting("leftPanel.width")
);
createEffect(() => setSetting("leftPanel.width", leftPanelWidth()));

export const [leftPanelLock, setLeftPanelLock] = createState<boolean>(
  getSetting("leftPanel.lock")
);
createEffect(() => setSetting("leftPanel.lock", leftPanelLock()));

export const [leftPanelWidget, setLeftPanelWidget] =
  createState<WidgetSelector>(getSetting("leftPanel.widget"));
createEffect(() => setSetting("leftPanel.widget", leftPanelWidget()));

export const [chatBotApi, setChatBotApi] = createState<Api>(
  getSetting("chatBot.api")
);
createEffect(() => setSetting("chatBot.api", chatBotApi()));

export const [chatBotImageGeneration, setChatBotImageGeneration] =
  createState<boolean>(getSetting("chatBot.imageGeneration"));
createEffect(() =>
  setSetting("chatBot.imageGeneration", chatBotImageGeneration())
);

export const [booruApi, setBooruApi] = createState<Api>(
  getSetting("booru.api")
);
createEffect(() => setSetting("booru.api", booruApi()));

export const [booruTags, setBooruTags] = createState<string[]>(
  getSetting("booru.tags")
);
createEffect(() => setSetting("booru.tags", booruTags()));

export const [booruLimit, setBooruLimit] = createState<number>(
  getSetting("booru.limit")
);
createEffect(() => setSetting("booru.limit", booruLimit()));

export const [booruPage, setBooruPage] = createState<number>(
  getSetting("booru.page")
);
createEffect(() => setSetting("booru.page", booruPage()));

export const [screenShotVisibility, setScreenShotVisibility] =
  createState<boolean>(false);
createEffect(() => {
  if (screenShotVisibility()) {
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 5000 * phi, () => {
      setScreenShotVisibility(false);
      return false;
    });
  }
});
