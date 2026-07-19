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
import {
  weatherInterface,
  OpenMeteoResponse,
} from "./interfaces/weather.interface";
import Gio from "gi://Gio";
import { monitorFile } from "ags/file";

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

export const layers = createBinding;

// export const globalMargin = emptyWorkspace((empty) => (empty ? 20 : 5));
export const globalMargin = 5;
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
  createSubprocess(
    null,
    `/tmp/ags-${GLib.get_user_name()}/system-resources-loop-ags`,
    (out) => {
      try {
        const parsed: SystemResourcesInterface = JSON.parse(out);

        return parsed;
      } catch (e) {
        return null;
      }
    },
  );

const [weatherData, setWeatherData] = createState<weatherInterface | null>(
  null,
);

export const updateWeather = async () => {
  try {
    const settings = globalSettings.peek() as Settings;
    let lat = settings.weather?.lat;
    let lon = settings.weather?.lon;
    let detectedCity = "";

    // If the coordinates are not specified, we determine by IP
    if (!lat || !lon) {
      try {
        // We make a request to ipinfo.io, which returns the coordinates in the "loc" field and the city name in "city"
        const ipOut = await execAsync([
          "curl",
          "-fsSL",
          "https://ipinfo.io/json",
        ]);
        const ipData = JSON.parse(ipOut);

        if (ipData.loc) {
          const loc = ipData.loc.split(",");
          lat = loc[0];
          lon = loc[1];
        }
        if (ipData.city) {
          detectedCity = ipData.city;
        }
      } catch (ipErr) {
        // Fallback via ifconfig.co if ipinfo.io doesn't respond
        try {
          const backupOut = await execAsync([
            "curl",
            "-fsSL",
            "https://ifconfig.co/json",
          ]);
          const backupData = JSON.parse(backupOut);
          if (backupData.latitude && backupData.longitude) {
            lat = backupData.latitude;
            lon = backupData.longitude;
          }
          if (backupData.city) {
            detectedCity = backupData.city;
          }
        } catch (backupErr) {
          console.error("Failed to detect location by IP:", backupErr);
        }
      }
    }

    if (!lat || !lon) return;

    // Request weather from Open-Meteo
    const out = await execAsync([
      "curl",
      "-fsSL",
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,apparent_temperature,is_day,precipitation,weather_code&hourly=temperature_2m,weather_code,precipitation&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_hours,wind_speed_10m_max&timezone=auto&forecast_days=2`,
    ]);

    const parsed = JSON.parse(out) as OpenMeteoResponse;

    // If the city is determined by IP and the settings are currently empty (Auto mode),
    // we'll temporarily write it to the weather object so the widget can display it,
    // but we won't overwrite the user's global settings.
    const finalCityName = settings.weather?.city || detectedCity || "Unknown";

    // include detected city (from IP) so the widget can show an Auto city name
    const weather: weatherInterface = {
      city: finalCityName,
      current: {
        time: parsed.current?.time,
        temp: parsed.current?.temperature_2m,
        temp_unit: parsed.current_units?.temperature_2m ?? "°C",
        humidity: parsed.current?.relative_humidity_2m,
        wind_speed: parsed.current?.wind_speed_10m,
        wind_unit: parsed.current_units?.wind_speed_10m ?? "km/h",
        wind_direction: parsed.current?.wind_direction_10m,
        apparent_temp: parsed.current?.apparent_temperature,
        is_day: parsed.current?.is_day,
        precipitation: parsed.current?.precipitation,
        weather_code: parsed.current?.weather_code,
      },
      daily: parsed.daily,
      hourly: parsed.hourly,
    };
    setWeatherData(weather);
  } catch (e) {
    console.error("Weather parsing error:", e);
  }
};

// Initial boot and interval start (every 10 minutes)
updateWeather();
createPoll(null, 600000, updateWeather);

export const setWeatherCity = async (cityName: string) => {
  if (!cityName || cityName.trim() === "") {
    print("Weather City is empty");
    setGlobalSetting("weather.city", "");
    setGlobalSetting("weather.lat", null);
    setGlobalSetting("weather.lon", null);
    await updateWeather();
    return;
  }

  try {
    print("Searching Weather City");
    const geoOut = await execAsync([
      "curl",
      "-fsSL",
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cityName)}&count=1&format=json`,
    ]);
    const geo = JSON.parse(geoOut);

    if (geo.results && geo.results.length > 0) {
      const { latitude, longitude, name } = geo.results[0];
      setGlobalSetting("weather.city", name);
      setGlobalSetting("weather.lat", latitude);
      setGlobalSetting("weather.lon", longitude);
      await updateWeather();
    } else {
      notify({ summary: "Weather", body: `City '${cityName}' not found` });
    }
  } catch (e) {
    notify({
      summary: "Weather",
      body: `Error fetching weather for '${cityName}'`,
    });
    console.error("Geocoding error:", e);
  }
};

// IMPORTANT: Export Accessor directly
export { weatherData };

export const [profilePicturePath, setProfilePicturePath] = createState<string>(
  Gio.File.new_for_path(`${GLib.get_home_dir()}/.face.icon`).query_exists(null)
    ? `${GLib.get_home_dir()}/.face.icon`
    : `${GLib.get_home_dir()}/.config/ags/assets/userpanel/archeclipse_default_pfp.jpg`,
);

monitorFile(`${GLib.get_home_dir()}/.face.icon`, () => {
  setProfilePicturePath("");
  setProfilePicturePath(
    Gio.File.new_for_path(`${GLib.get_home_dir()}/.face.icon`).query_exists(
      null,
    )
      ? `${GLib.get_home_dir()}/.face.icon`
      : `${GLib.get_home_dir()}/.config/ags/assets/userpanel/archeclipse_default_pfp.jpg`,
  );
});
