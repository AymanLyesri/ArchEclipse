import { autoCreateSettings, settingsPath } from "./utils/settings";

import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

import { createBinding, createState } from "ags";
import { createPoll } from "ags/time";
import GLib from "gi://GLib";
import { writeJSONFile } from "./utils/json";
import { Settings } from "./interfaces/settings.interface";
import { phi, phi_min } from "./constants/phi.constants";
import { defaultSettings } from "./constants/settings.constants";
import { exec, execAsync } from "ags/process";
import { notify } from "./utils/notification";

export const NOTIFICATION_DELAY = phi * 3000;

const [globalSettings, _setGlobalSettings] =
  createState<Settings>(defaultSettings);

// Initialize settings after creating the state
autoCreateSettings(globalSettings.peek(), setGlobalSettings);

export function setGlobalSetting(keyChanged: string, value: any) {
  try {
    let o: any = globalSettings.peek();
    keyChanged
      .split(".")
      .reduce(
        (o, k, i, arr) => (o[k] = i === arr.length - 1 ? value : o[k] || {}),
        o,
      );

    _setGlobalSettings({ ...o });
    writeJSONFile(settingsPath, o);
  } catch (e) {
    print(`Error setting global setting ${keyChanged}: ${e}`);
    notify({
      summary: "Error",
      body: `Error setting global setting ${keyChanged}: ${e}`,
    });
  }
}

function setGlobalSettings(value: Settings) {
  _setGlobalSettings(value);
  writeJSONFile(settingsPath, value);
}
export { globalSettings, setGlobalSettings };

export const focusedClient = createBinding(hyprland, "focusedClient");
export const fullscreenClient = focusedClient((client) => {
  if (!client) return false;
  return client.fullscreen === 2 || client.get_fullscreen?.() === 2;
});
export const emptyWorkspace = focusedClient((client) => !client);
export const focusedWorkspace = createBinding(hyprland, "focusedWorkspace");
export const specialWorkspace = focusedClient((client) => {
  return client ? client.workspace.id < 0 : false;
});

export const globalMargin = emptyWorkspace((empty) => (empty ? 20 : 5));
export const globalTransition = 300;

export const date_less = createPoll(
  "",
  5000,
  () => GLib.DateTime.new_now_local().format(globalSettings.peek().dateFormat)!,
);
export const date_more = createPoll(
  "",
  5000,
  () => GLib.DateTime.new_now_local().format(" %A ·%e %b %Y ")!,
);

const [globalTheme, _setGlobalTheme] = createState<boolean>(
  exec([
    "bash",
    "-c",
    "$HOME/.config/hypr/theme/scripts/system-theme.sh get",
  ]).includes("light"),
);
function setGlobalTheme(value: boolean) {
  execAsync([
    "bash",
    "-c",
    `$HOME/.config/hypr/theme/scripts/system-theme.sh switch ${
      value ? "light" : "dark"
    }`,
  ]).then(() => {
    _setGlobalTheme(value);
  });
}
export { globalTheme, setGlobalTheme };
