import { createPoll } from "ags/time";
import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import { With } from "gnim";
import { Eventbox } from "./Custom/Eventbox";
import Pango from "gi://Pango";

interface weatherData {
  current: {
    temp: number;
    temp_unit: string;
    humidity: number;
    wind_speed: number;
    wind_unit: string;
    wind_direction: number;
    apparent_temp: number;
    is_day: number;
    precipitation: number;
    weather_code: number;
  };
  daily: {
    time: number[];
    temperature_2m_max: number[];
    temperature_2m_min: number[];
    sunrise: number[];
    sunset: number[];
    precipitation_sum: number[];
    precipitation_hours: number[];
    wind_speed_10m_max: number[];
  };
  hourly: any;
}
// Poll every 10 minutes (600,000 ms)
const weather = createPoll(
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
      } as weatherData;
    } catch (e) {
      console.error("Weather parsing error:", e);
      return null;
    }
  },
);

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

// Format time from ISO string
const formatTime = (isoTime: number) => {
  if (!isoTime) return "N/A";
  const date = new Date(isoTime);
  return date.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
};

const formatDate = (isoTime: number) => {
  if (!isoTime) return "N/A";
  const date = new Date(isoTime);
  return date.toLocaleDateString([], {
    weekday: "short",
    day: "numeric",
    month: "short",
  });
};

// const currentWeatherLabel = weather((w) => {
//   if (!w) return "Weather N/A";
//   const current = w.current;
//   return `${current.temp}${current.temp_unit} ${
//     weatherCodes[current.weather_code]?.description || "Unknown"
//   }`;
// });

const currentWeatherLabel = (w: any) => {
  if (!w) return "Weather N/A";
  const current = w.current;
  return `${current.temp}${current.temp_unit} ${
    weatherCodes[current.weather_code]?.description || "Unknown"
  }`;
};

const weatherIcon = (w: any) => {
  if (!w) return "";
  const code = w.current.weather_code;
  // Map weather codes to icon names (simplified)
  // clear
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

export function Weather() {
  return (
    <box class="weather" spacing={12} orientation={Gtk.Orientation.VERTICAL}>
      <With value={weather}>
        {(w) => {
          if (!w) return <label label="Weather data unavailable" />;

          const current = w.current;
          const today = w.daily;

          return (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={12}>
              <box
                class={`weather-section`}
                css={`
                  background-color: ${weatherCodes[current.weather_code]
                    ?.background || "#000000"};
                  color: white;
                `}
                spacing={25}
              >
                <box
                  orientation={Gtk.Orientation.VERTICAL}
                  class={"main"}
                  halign={Gtk.Align.CENTER}
                  spacing={4}
                >
                  <label class={"weather-icon-large"} label={weatherIcon(w)} />
                  <label
                    class="weather-temp-large"
                    label={`${current.temp}${current.temp_unit}`}
                  />
                  <label
                    class="weather-description"
                    label={
                      weatherCodes[current.weather_code]?.description ||
                      "Unknown"
                    }
                  />
                  <label
                    class="weather-feels-like"
                    label={`Feels like: ${current.apparent_temp}${current.temp_unit}`}
                  />
                  <label
                    class="weather-date"
                    label={`${formatDate(w.daily.time[0])}`}
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
                      <label label={formatTime(today.sunrise[0])} />
                    </box>
                    <label class={"sun"} label="" hexpand />
                    <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                      <label class={"icon"} label="" />
                      <label label={formatTime(today.sunset[0])} />
                    </box>
                  </box>
                  <box spacing={5} vexpand>
                    <box class="weather-detail" spacing={5} hexpand>
                      <label class={"icon"} label="" />
                      <label label={`${current.humidity}%`} />
                    </box>
                    <box class="weather-detail" spacing={5} hexpand>
                      <label class={"icon"} label="" />
                      <label label={`${current.precipitation} mm`} />
                    </box>
                  </box>

                  <box class="weather-detail" spacing={5} vexpand>
                    <label class={"icon"} label="" />
                    <label
                      label={`${current.wind_speed} ${
                        current.wind_unit
                      } ${getWindDirection(current.wind_direction)}`}
                    />
                  </box>
                </box>
              </box>

              <box
                class={"weather-section"}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={12}
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
                      label={`${today.temperature_2m_max[0]}${current.temp_unit}`}
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
                      label={`${today.temperature_2m_min[0]}${current.temp_unit}`}
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
                      label={`${today.precipitation_sum[0]} mm`}
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
                      label={`${today.wind_speed_10m_max[0]} ${current.wind_unit}`}
                    />
                  </box>
                </box>
              </box>

              <box
                class={"weather-section"}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={12}
              >
                <label class="weather-subheading" label="Hourly Forecast" />

                <box class="hourly-forecast">
                  {(() => {
                    const now = new Date();
                    const currentHour = now.getHours();
                    const hourlyData = w.hourly;

                    // Show next 12 hours divided by 3h (4 blocks)
                    const hours = [];
                    for (let i = 0; i < 4; i++) {
                      const hourIndex = currentHour + i * 3;
                      if (hourIndex >= hourlyData.time.length) break;

                      const time = new Date(hourlyData.time[hourIndex]);
                      const temp = hourlyData.temperature_2m?.[hourIndex];
                      const weatherCode = hourlyData.weather_code?.[hourIndex];
                      const precipitation =
                        hourlyData.precipitation?.[hourIndex] || 0;

                      hours.push(
                        <box
                          class="hourly-item"
                          orientation={Gtk.Orientation.VERTICAL}
                          halign={Gtk.Align.CENTER}
                          spacing={4}
                          hexpand
                        >
                          <label class="hourly-icon" label={weatherIcon(w)} />

                          <box class={"hourly-content"} spacing={5}>
                            <label
                              class="hourly-temp"
                              label={temp ? `${Math.round(temp)}°` : "N/A"}
                            />
                            <label
                              class="hourly-time"
                              label={time.toLocaleTimeString([], {
                                hour: "2-digit",
                                minute: "2-digit",
                                hour12: false,
                              })}
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

              {/* <Eventbox
                    onClick={() =>
                      GLib.spawn_command_line_async(
                        "xdg-open 'https://open-meteo.com/'",
                      )
                    }
                  >
                    <label
                      class="weather-link"
                      label="More details on Open-Meteo →"
                    />
                  </Eventbox> */}
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
      css={weather((w) => {
        if (!w) {
          return "";
        }
        return `background-color: ${
          weatherCodes[w.current.weather_code]?.background || "#000000"
        };
        color: white;
      `;
      })}
      onClicked={() => {
        if (!popover) return;
        if (popover.visible) popover.hide();
        else popover.show();
      }}
      $={(self) => {
        popover = new Gtk.Popover({
          has_arrow: true,
          position: Gtk.PositionType.BOTTOM,
          autohide: true,
        });

        popover.set_child((<Weather />) as unknown as Gtk.Widget);
        popover.set_parent(self);

        popover.connect("notify::visible", () => {
          if (!popover) return;

          if (popover.visible) popover.add_css_class("popover-open");
          else if (popover.get_child())
            popover.remove_css_class("popover-open");
        });
      }}
    >
      <box class="weather-button" spacing={5}>
        <label label={weatherIcon(weather())} />
        <label
          label={currentWeatherLabel(weather())}
          ellipsize={Pango.EllipsizeMode.END}
        />
      </box>
    </button>
  );
}
