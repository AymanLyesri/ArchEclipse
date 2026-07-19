import { Gtk } from "ags/gtk4";
import { With } from "gnim";
import Pango from "gi://Pango";
import { weatherData, setWeatherCity, globalSettings } from "../variables";
import type { Settings } from "../interfaces/settings.interface";
import type { weatherInterface } from "../interfaces/weather.interface";
import { connectPopoverEvents } from "../utils/window";

// Weather code to description mapping
const weatherCodes: Record<
  number,
  { description: string; background: string }
> = {
  0: { description: "Clear sky", background: "#0F4C81" },
  1: { description: "Mainly clear", background: "#1F5D8A" },
  2: { description: "Partly cloudy", background: "#2E5984" },
  3: { description: "Overcast", background: "#4A5568" },
  45: { description: "Foggy", background: "#4B5563" },
  48: { description: "Depositing rime fog", background: "#4B5563" },
  51: { description: "Light drizzle", background: "#0C4A6E" },
  53: { description: "Moderate drizzle", background: "#0B3A67" },
  55: { description: "Dense drizzle", background: "#1E3A8A" },
  56: { description: "Light freezing drizzle", background: "#0C4A6E" },
  57: { description: "Dense freezing drizzle", background: "#1E3A8A" },
  61: { description: "Slight rain", background: "#0C4A6E" },
  63: { description: "Moderate rain", background: "#0B3A67" },
  65: { description: "Heavy rain", background: "#1E3A8A" },
  66: { description: "Light freezing rain", background: "#0C4A6E" },
  67: { description: "Heavy freezing rain", background: "#1E3A8A" },
  71: { description: "Slight snow fall", background: "#334155" },
  73: { description: "Moderate snow fall", background: "#1E40AF" },
  75: { description: "Heavy snow fall", background: "#1E3A8A" },
  77: { description: "Snow grains", background: "#334155" },
  80: { description: "Slight rain showers", background: "#0C4A6E" },
  81: { description: "Moderate rain showers", background: "#0B3A67" },
  82: { description: "Violent rain showers", background: "#1E3A8A" },
  85: { description: "Slight snow showers", background: "#334155" },
  86: { description: "Heavy snow showers", background: "#1E3A8A" },
  95: { description: "Thunderstorm", background: "#9A3412" },
  96: {
    description: "Thunderstorm with slight hail",
    background: "#7C2D12",
  },
  99: {
    description: "Thunderstorm with heavy hail",
    background: "#7F1D1D",
  },
};

// Wind direction mapping
const windDirections = [
  "N",
  "NNE",
  "NE",
  "ENE",
  "E",
  "ESE",
  "SE",
  "SSE",
  "S",
  "SSW",
  "SW",
  "WSW",
  "W",
  "WNW",
  "NW",
  "NNW",
];

const getWindDirection = (degrees: number) => {
  const index = Math.round((degrees % 360) / 22.5) % 16;
  return windDirections[index];
};

const UNKNOWN_WEATHER = { description: "Unknown", background: "#000000" };
const getWeatherInfo = (code?: number) =>
  code != null ? (weatherCodes[code] ?? UNKNOWN_WEATHER) : UNKNOWN_WEATHER;

const fmt = (value: number | undefined | null, unit = "") =>
  value != null ? `${value}${unit}` : "N/A";

// Format time from ISO string safely
const formatTime = (isoTime: string | number | undefined) => {
  if (!isoTime) return "N/A";
  const normalized =
    typeof isoTime === "string"
      ? isoTime.replace("T", " ").replace(/-/g, "/")
      : isoTime;
  const date = new Date(normalized);
  if (isNaN(date.getTime())) return "N/A";
  return date.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
};

const formatDate = (isoTime: string | number | undefined) => {
  if (!isoTime) return "N/A";

  const normalized =
    typeof isoTime === "string"
      ? isoTime.replace("T", " ").replace(/-/g, "/")
      : isoTime;

  const date = new Date(normalized);
  if (isNaN(date.getTime())) return "N/A";
  return date.toLocaleDateString([], {
    weekday: "short",
    day: "numeric",
    month: "short",
  });
};

const currentWeatherLabel = (w: weatherInterface | null) => {
  if (!w) return "Weather N/A";
  const current = w.current;
  return `${fmt(current.temp, current.temp_unit)} ${
    getWeatherInfo(current.weather_code).description
  }`;
};

const weatherIcon = (code?: number) => {
  if (code == null) return "󰖙";
  if (code === 0) return "󰖙";
  // partly cloudy
  if (code === 1 || code === 2) return "󰖐";
  // cloudy
  if (code === 3) return "󰖑";
  // hazy
  if (code >= 45 && code <= 48) return "󰼰";
  // hail
  if (code >= 56 && code <= 57) return "󰖒";
  // pouring rain
  if (code >= 65 && code <= 67) return "󰖖";
  // rainy
  if ((code >= 51 && code <= 64) || (code >= 80 && code <= 82)) return "󰖗";
  // snow
  if (code >= 71 && code <= 86) return "󰖘";
  // thunderstorm
  if (code >= 95) return "󰖓";
  return "󰖙"; // default to clear
};

export function Weather({ moreDetails = false }: { moreDetails?: boolean }) {
  let cityEntry: Gtk.Entry;

  return (
    <box class="weather" spacing={12} orientation={Gtk.Orientation.VERTICAL}>
      <With value={weatherData}>
        {(w) => {
          if (!w) return <label label="Weather data unavailable" />;

          const current = w.current;
          const today = w.daily;

          return (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={12}>
              <box
                class={`weather-section`}
                css={`
                  background-color: ${getWeatherInfo(current.weather_code)
                    .background};
                  color: white;
                `}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={10}
              >
                <box spacing={25}>
                  <box
                    orientation={Gtk.Orientation.VERTICAL}
                    class={"main"}
                    halign={Gtk.Align.CENTER}
                    spacing={4}
                  >
                    <label
                      class={"weather-icon-large"}
                      label={weatherIcon(current?.weather_code)}
                    />
                    <label
                      class="weather-city-name"
                      css="font-weight: bold; font-size: 1.2rem; margin-bottom: 4px;"
                      label={globalSettings((s: Settings) => {
                        const savedCity = s.weather?.city;
                        if (savedCity) return `󰍎 ${savedCity}`;
                        if (w && w.city) return `󰍎 ${w.city}`;
                        return "Auto (IP)";
                      })}
                    />
                    <label
                      class="weather-temp-large"
                      label={fmt(current.temp, current.temp_unit)}
                    />
                    <label
                      class="weather-description"
                      label={getWeatherInfo(current.weather_code).description}
                    />
                    <label
                      class="weather-feels-like"
                      label={`Feels like: ${fmt(current.apparent_temp, current.temp_unit)}`}
                    />
                    <label
                      class="weather-date"
                      label={`${formatDate(w.daily.time?.[0])}`}
                    />
                  </box>

                  <box
                    orientation={Gtk.Orientation.VERTICAL}
                    halign={Gtk.Align.CENTER}
                    spacing={5}
                  >
                    <box
                      class="weather-detail sun-detail"
                      valign={Gtk.Align.CENTER}
                      spacing={5}
                      vexpand
                    >
                      <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                        <label class={"icon"} label="" />
                        <label label={formatTime(today.sunrise?.[0])} />
                      </box>
                      <label class={"sun"} label="" hexpand />
                      <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                        <label class={"icon"} label="" />
                        <label label={formatTime(today.sunset?.[0])} />
                      </box>
                    </box>
                    <box spacing={5} vexpand>
                      <box class="weather-detail" spacing={5} hexpand>
                        <label class={"icon"} label="" />
                        <label label={fmt(current.humidity, "%")} />
                      </box>
                      <box class="weather-detail" spacing={5} hexpand>
                        <label class={"icon"} label="" />
                        <label label={fmt(current.precipitation, " mm")} />
                      </box>
                    </box>

                    <box class="weather-detail" spacing={5} vexpand>
                      <label class={"icon"} label="" />
                      <label
                        label={`${fmt(current.wind_speed)} ${
                          current.wind_unit
                        } ${getWindDirection(current.wind_direction ?? 0)}`}
                      />
                    </box>
                  </box>
                </box>
                <box
                  orientation={Gtk.Orientation.HORIZONTAL}
                  spacing={8}
                  halign={Gtk.Align.CENTER}
                >
                  <entry
                    class="weather-city-input"
                    placeholderText={globalSettings((s: Settings) => {
                      const city = s.weather?.city;
                      if (city) return "Search...";

                      const currentLoc = w?.city || "IP";
                      return `Not ${currentLoc}?...`;
                    })}
                    text={globalSettings(
                      (s: Settings) => s.weather?.city || "",
                    )}
                    $={(self) => {
                      cityEntry = self;
                    }}
                    onActivate={(self) => {
                      setWeatherCity(self.get_text());
                    }}
                    hexpand
                  />

                  <button
                    class="weather-city-apply"
                    tooltipText="Search city"
                    onClicked={() => {
                      if (cityEntry) setWeatherCity(cityEntry.get_text());
                    }}
                  >
                    <label label="✔" />
                  </button>

                  <button
                    class="weather-city-clear"
                    tooltipText="Auto (IP)"
                    onClicked={() => setWeatherCity("")}
                  >
                    <label label="󰦛" />
                  </button>
                </box>
              </box>

              <box
                class={`weather-section`}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={12}
                visible={moreDetails}
              >
                <label class="weather-subheading" label="Today's Forecast" />
                <box class="daily-forecast" spacing={8}>
                  <box
                    class="forecast-item"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={2}
                    hexpand
                  >
                    <label class="forecast-label" label="Max" />
                    <label
                      class="forecast-value"
                      label={fmt(
                        today.temperature_2m_max?.[0],
                        current.temp_unit,
                      )}
                    />
                  </box>
                  <box
                    class="forecast-item"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={2}
                    hexpand
                  >
                    <label class="forecast-label" label="Min" />
                    <label
                      class="forecast-value"
                      label={fmt(
                        today.temperature_2m_min?.[0],
                        current.temp_unit,
                      )}
                    />
                  </box>
                  <box
                    class="forecast-item"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={2}
                    hexpand
                  >
                    <label class="forecast-label" label="Rain" />
                    <label
                      class="forecast-value"
                      label={`${today.precipitation_sum?.[0] ?? 0} mm`}
                    />
                  </box>
                  <box
                    class="forecast-item"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={2}
                    hexpand
                  >
                    <label class="forecast-label" label="Wind" />
                    <label
                      class="forecast-value"
                      label={`${today.wind_speed_10m_max?.[0] ?? "N/A"} ${current.wind_unit}`}
                    />
                  </box>
                </box>
              </box>

              <box
                class={`weather-section`}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={12}
                visible={moreDetails}
              >
                <label class="weather-subheading" label="Hourly Forecast" />

                <box class="hourly-forecast">
                  {(() => {
                    const hourlyData = w.hourly;
                    if (!hourlyData?.time || hourlyData.time.length === 0)
                      return null;

                    const apiCurrentTime = current.time;
                    const currentHourISO = apiCurrentTime
                      ? `${apiCurrentTime.slice(0, 13)}:00`
                      : (() => {
                          const now = new Date();
                          const year = now.getFullYear();
                          const month = String(now.getMonth() + 1).padStart(
                            2,
                            "0",
                          );
                          const day = String(now.getDate()).padStart(2, "0");
                          const hoursStr = String(now.getHours()).padStart(
                            2,
                            "0",
                          );
                          return `${year}-${month}-${day}T${hoursStr}:00`;
                        })();

                    const startIndex = hourlyData.time.findIndex(
                      (t: string) => t >= currentHourISO,
                    );
                    const baseIndex = startIndex === -1 ? 0 : startIndex;

                    const hours = [];
                    for (let i = 0; i < 4; i++) {
                      const hourIndex = baseIndex + i * 3;
                      if (hourIndex >= hourlyData.time.length) break;

                      const timeStr = hourlyData.time[hourIndex];
                      const safeTimeStr = timeStr
                        .replace("T", " ")
                        .replace(/-/g, "/");
                      const time = new Date(safeTimeStr);

                      const temp = hourlyData.temperature_2m?.[hourIndex];
                      const weatherCode = hourlyData.weather_code?.[hourIndex];
                      const precipitation =
                        hourlyData.precipitation?.[hourIndex] ?? 0;

                      hours.push(
                        <box
                          class="hourly-item"
                          orientation={Gtk.Orientation.VERTICAL}
                          halign={Gtk.Align.CENTER}
                          spacing={4}
                          hexpand
                        >
                          <label
                            class="hourly-icon"
                            label={weatherIcon(weatherCode)}
                          />

                          <box class={"hourly-content"} spacing={5}>
                            <label
                              class="hourly-temp"
                              label={
                                temp != null ? `${Math.round(temp)}°` : "N/A"
                              }
                            />
                            <label
                              class="hourly-time"
                              label={
                                !isNaN(time.getTime())
                                  ? time.toLocaleTimeString([], {
                                      hour: "2-digit",
                                      minute: "2-digit",
                                      hour12: false,
                                    })
                                  : "N/A"
                              }
                            />
                          </box>

                          {precipitation > 0 && (
                            <label
                              class="hourly-precipitation"
                              label={`${precipitation}mm`}
                            />
                          )}
                        </box>,
                      );
                    }
                    return hours;
                  })()}
                </box>
              </box>
            </box>
          );
        }}
      </With>
    </box>
  );
}

export function WeatherButton() {
  let popover: Gtk.Popover | null = null;

  return (
    <button
      class="weather-button"
      tooltipText={"click to open"}
      css={weatherData((w) => {
        if (!w) return "";
        return `background-color: ${
          getWeatherInfo(w.current.weather_code).background
        };
        color: white;
      `;
      })}
      onClicked={() => {
        if (!popover) return;
        if (popover.visible) popover.popdown();
        else popover.popup();
      }}
      $={(self) => {
        popover = new Gtk.Popover({
          has_arrow: true,
          position: Gtk.PositionType.BOTTOM,
          autohide: true,
        });

        popover.set_child((<Weather moreDetails />) as unknown as Gtk.Widget);
        popover.set_parent(self);

        connectPopoverEvents(self, "barWindow", popover);

        popover.connect("notify::visible", () => {
          if (!popover) return;

          if (popover.visible) popover.add_css_class("popover-open");
          else if (popover.get_child())
            popover.remove_css_class("popover-open");
        });
      }}
    >
      <box class="weather-button" spacing={5}>
        <label
          label={weatherData((w) => weatherIcon(w?.current?.weather_code))}
        />
        <label
          label={weatherData((w) => currentWeatherLabel(w))}
          ellipsize={Pango.EllipsizeMode.END}
        />
      </box>
    </button>
  );
}
