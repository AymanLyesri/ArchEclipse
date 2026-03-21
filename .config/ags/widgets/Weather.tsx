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
// Poll every 15 minutes (900,000 ms)
const weather = createPoll(
  null,
  900000,
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

interface WeatherCodeMap {
  [key: number]: string;
}

// Weather code to description mapping
const weatherCodes: WeatherCodeMap = {
  0: "Clear sky",
  1: "Mainly clear",
  2: "Partly cloudy",
  3: "Overcast",
  45: "Foggy",
  48: "Depositing rime fog",
  51: "Light drizzle",
  53: "Moderate drizzle",
  55: "Dense drizzle",
  56: "Light freezing drizzle",
  57: "Dense freezing drizzle",
  61: "Slight rain",
  63: "Moderate rain",
  65: "Heavy rain",
  66: "Light freezing rain",
  67: "Heavy freezing rain",
  71: "Slight snow fall",
  73: "Moderate snow fall",
  75: "Heavy snow fall",
  77: "Snow grains",
  80: "Slight rain showers",
  81: "Moderate rain showers",
  82: "Violent rain showers",
  85: "Slight snow showers",
  86: "Heavy snow showers",
  95: "Thunderstorm",
  96: "Thunderstorm with slight hail",
  99: "Thunderstorm with heavy hail",
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
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
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

const currentWeatherLabel = weather((w) => {
  if (!w) return "Weather N/A";
  const current = w.current;
  return `${current.temp}${current.temp_unit} ${
    weatherCodes[current.weather_code] || "Unknown"
  }`;
});

const weatherIcon = weather((w) => {
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
});

export function Weather() {
  return (
    <box class="weather" spacing={12} orientation={Gtk.Orientation.VERTICAL}>
      <With value={weather}>
        {(w) => {
          if (!w) return <label label="Weather data unavailable" />;

          const current = w.current;
          const today = w.daily;

          // Map weather codes to background colors, compatible with white text and providing good contrast
          const backgroundColor: Record<number, string> = {
            0: "#0F4C81", // Clear sky - deep blue
            1: "#1F5D8A", // Mainly clear - muted blue
            2: "#2E5984", // Partly cloudy - slate blue
            3: "#4A5568", // Overcast - dark gray
            45: "#4B5563", // Foggy - charcoal
            48: "#4B5563", // Depositing rime fog - charcoal
            51: "#0C4A6E", // Light drizzle - dark cyan-blue
            53: "#0B3A67", // Moderate drizzle - darker blue
            55: "#1E3A8A", // Dense drizzle - indigo blue
            56: "#0C4A6E", // Light freezing drizzle - dark cyan-blue
            57: "#1E3A8A", // Dense freezing drizzle - indigo blue
            61: "#0C4A6E", // Slight rain - dark cyan-blue
            63: "#0B3A67", // Moderate rain - darker blue
            65: "#1E3A8A", // Heavy rain - indigo blue
            66: "#0C4A6E", // Light freezing rain - dark cyan-blue
            67: "#1E3A8A", // Heavy freezing rain - indigo blue
            71: "#334155", // Slight snow fall - blue gray
            73: "#1E40AF", // Moderate snow fall - cobalt
            75: "#1E3A8A", // Heavy snow fall - indigo
            77: "#334155", // Snow grains - blue gray
            80: "#0C4A6E", // Slight rain showers - dark cyan-blue
            81: "#0B3A67", // Moderate rain showers - darker blue
            82: "#1E3A8A", // Violent rain showers - indigo blue
            85: "#334155", // Slight snow showers - blue gray
            86: "#1E3A8A", // Heavy snow showers - indigo
            95: "#9A3412", // Thunderstorm - deep orange
            96: "#7C2D12", // Thunderstorm with slight hail - burnt orange
            99: "#7F1D1D", // Thunderstorm with heavy hail - deep red
          };

          return (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={12}>
              <box
                class={`weather-section main`}
                css={`
                  background-color: ${backgroundColor[current.weather_code] ||
                  "#000000"};
                  color: white;
                `}
                spacing={25}
              >
                <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
                  <label class={"weather-icon-large"} label={weatherIcon} />
                  <label
                    class="weather-temp-large"
                    label={`${current.temp}${current.temp_unit}`}
                  />
                  <label
                    class="weather-description"
                    label={weatherCodes[current.weather_code] || "Unknown"}
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
                  spacing={6}
                  // halign={Gtk.Align.END}
                  // hexpand
                >
                  <box class="weather-detail" spacing={5} vexpand>
                    <label label="Humidity:" />
                    <label label={`${current.humidity}%`} xalign={1} hexpand />
                  </box>
                  <box class="weather-detail" spacing={5} vexpand>
                    <label label="Wind:" />
                    <label
                      label={`${current.wind_speed} ${
                        current.wind_unit
                      } ${getWindDirection(current.wind_direction)}`}
                      xalign={1}
                      hexpand
                    />
                  </box>
                  <box class="weather-detail" spacing={5} vexpand>
                    <label label="Precipitation:" />
                    <label
                      label={`${current.precipitation} mm`}
                      xalign={1}
                      hexpand
                    />
                  </box>
                  <box class="weather-detail" spacing={5} vexpand>
                    <label label="Sunrise:" />
                    <label
                      label={formatTime(today.sunrise[0])}
                      xalign={1}
                      hexpand
                    />
                  </box>
                  <box class="weather-detail" spacing={5} vexpand>
                    <label label="Sunset:" />
                    <label
                      label={formatTime(today.sunset[0])}
                      xalign={1}
                      hexpand
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
                <scrolledwindow
                  hscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                  vscrollbarPolicy={Gtk.PolicyType.NEVER}
                >
                  <box class="hourly-forecast" spacing={10}>
                    {(() => {
                      const now = new Date();
                      const currentHour = now.getHours();
                      const hourlyData = w.hourly;

                      // Show next 12 hours
                      const hours = [];
                      for (let i = 0; i < 12; i++) {
                        const hourIndex = currentHour + i;
                        if (hourIndex >= hourlyData.time.length) break;

                        const time = new Date(hourlyData.time[hourIndex]);
                        const temp = hourlyData.temperature_2m?.[hourIndex];
                        const weatherCode =
                          hourlyData.weather_code?.[hourIndex];
                        const precipitation =
                          hourlyData.precipitation?.[hourIndex] || 0;

                        // Get icon for this hour
                        let hourIcon = weatherIcon;

                        hours.push(
                          <box
                            class="hourly-item"
                            orientation={Gtk.Orientation.VERTICAL}
                            spacing={4}
                          >
                            <label
                              class="hourly-time"
                              label={time.toLocaleTimeString([], {
                                hour: "2-digit",
                                minute: "2-digit",
                              })}
                            />
                            <label class="hourly-icon" label={hourIcon} />
                            <label
                              class="hourly-temp"
                              label={temp ? `${Math.round(temp)}°` : "N/A"}
                            />
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
                </scrolledwindow>
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
  return (
    <menubutton>
      <box class="weather-button" spacing={5} tooltipText={"click to open"}>
        <label label={weatherIcon} />
        <label
          label={currentWeatherLabel}
          ellipsize={Pango.EllipsizeMode.END}
        />
      </box>
      <popover
        $={(self) => {
          self.connect("notify::visible", () => {
            if (self.visible) self.add_css_class("popover-open");
            else if (self.get_child()) self.remove_css_class("popover-open");
          });
        }}
      >
        <Weather />
      </popover>
    </menubutton>
  );
}
