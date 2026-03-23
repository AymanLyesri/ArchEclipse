import { autoCreateSettings, settingsPath } from "./utils/settings";

import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

import { Accessor, createBinding, createState } from "ags";
import { createPoll } from "ags/time";
import GLib from "gi://GLib";
import { writeJSONFile } from "./utils/json";
import { Settings } from "./interfaces/settings.interface";
import { phi, phi_min } from "./constants/phi.constants";
import { defaultSettings } from "./constants/settings.constants";
import { createSubprocess, exec, execAsync } from "ags/process";
import { notify } from "./utils/notification";
import { SystemResourcesInterface } from "./interfaces/systemResources.interface";
import { weatherInterface } from "./interfaces/weather.interface";

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
  return client && client.workspace ? client.workspace.id < 0 : false;
});

export const globalMargin = emptyWorkspace((empty) => (empty ? 20 : 5));
export const globalTransition = 300;

export const date_less = createPoll(
  "",
  30000,
  () => GLib.DateTime.new_now_local().format(globalSettings.peek().dateFormat)!,
);
export const date_more = createPoll(
  "",
  30000,
  () => GLib.DateTime.new_now_local().format(" %A ·%e %b %Y ")!,
);

const [globalTheme, _setGlobalTheme] = createState<boolean>(false);
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

execAsync([
  "bash",
  "-c",
  "$HOME/.config/hypr/theme/scripts/system-theme.sh get",
]).then((output) => {
  _setGlobalTheme(output.includes("light"));
});
export { globalTheme, setGlobalTheme };

export const systemResourcesData: Accessor<SystemResourcesInterface | null> =
  createSubprocess(null, `/tmp/ags/system-resources-loop-ags`, (out) => {
    try {
      const parsed: SystemResourcesInterface = JSON.parse(out);

      return parsed;
    } catch (e) {
      return null;
    }
  });

export const weatherData = createPoll(
  null,
  600000,
  [
    "bash",
    "-c",
    `
  LOC="$(
  curl -fsSL https://ipapi.co/latlong ||
  curl -fsSL https://ifconfig.co/coordinates ||
  curl -fsSL https://ipinfo.io/loc
)" || exit 1
  LAT=\${LOC%,*}
  LON=\${LOC#*,}
  curl -fsSL "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,apparent_temperature,is_day,precipitation,weather_code&hourly=temperature_2m,weather_code,precipitation&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_hours,wind_speed_10m_max&timezone=auto&forecast_days=2"
  `,
  ],
  (out) => {
    try {
      const parsed = JSON.parse(out);
      return {
        current: {
          temp: parsed.current.temperature_2m,
          temp_unit: parsed.current_units.temperature_2m,
          humidity: parsed.current.relative_humidity_2m,
          wind_speed: parsed.current.wind_speed_10m,
          wind_unit: parsed.current_units.wind_speed_10m,
          wind_direction: parsed.current.wind_direction_10m,
          apparent_temp: parsed.current.apparent_temperature,
          is_day: parsed.current.is_day,
          precipitation: parsed.current.precipitation,
          weather_code: parsed.current.weather_code,
        },
        daily: parsed.daily,
        hourly: parsed.hourly,
      } as weatherInterface;
    } catch (e) {
      console.error("Weather parsing error:", e);
      return null;
    }
  },
);
