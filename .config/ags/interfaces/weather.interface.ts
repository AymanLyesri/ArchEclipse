// Weather data shapes returned by Open-Meteo (times are ISO strings).
// Two layers are modeled on purpose:
//   1. Raw wire format — CurrentWeather / DailyWeather / HourlyWeather /
//      OpenMeteoResponse — mirrors the API's own field names exactly.
//   2. App-facing shape — weatherInterface — the normalized state that
//      updateWeather() (variables.ts) builds from the raw response and that
//      the Weather widget actually renders.

// Raw shape of a single Open-Meteo /v1/forecast JSON response, as fetched in
// updateWeather() (variables.ts). Field names match the API exactly
// (snake_case, unit baked into the name) — this is intentionally distinct
// from `weatherInterface`, which is the normalized shape the app actually
// renders (renamed fields, units split out). CurrentWeather/DailyWeather/
// HourlyWeather describe the wire format; weatherInterface.current describes
// the post-mapping app state.
export interface CurrentWeather {
  time?: string;
  interval?: number;
  temperature_2m: number;
  relative_humidity_2m?: number;
  wind_speed_10m?: number;
  wind_direction_10m?: number;
  apparent_temperature?: number;
  is_day?: number;
  precipitation?: number;
  weather_code?: number;
}

export interface DailyWeather {
  time: string[];
  temperature_2m_max: number[];
  temperature_2m_min: number[];
  sunrise: string[];
  sunset: string[];
  precipitation_sum?: number[];
  precipitation_hours?: number[];
  wind_speed_10m_max?: number[];
}

export interface HourlyWeather {
  time: string[];
  temperature_2m?: number[];
  weather_code?: number[];
  precipitation?: number[];
  relative_humidity_2m?: number[];
  wind_speed_10m?: number[];
  wind_direction_10m?: number[];
}

// Full shape returned by https://api.open-meteo.com/v1/forecast. Use this to
// type the JSON.parse() result of the curl response instead of leaving it as
// implicit `any` — that was previously masking any field-name typo or API
// shape change from the type checker.
export interface OpenMeteoResponse {
  latitude: number;
  longitude: number;
  generationtime_ms: number;
  utc_offset_seconds: number;
  timezone: string;
  timezone_abbreviation: string;
  elevation: number;
  current_units?: Record<string, string>;
  current: CurrentWeather;
  hourly_units?: Record<string, string>;
  hourly: HourlyWeather;
  daily_units?: Record<string, string>;
  daily: DailyWeather;
}

export interface weatherInterface {
  city?: string;
  current: {
    time?: string;
    temp: number;
    temp_unit: string;
    humidity?: number;
    wind_speed?: number;
    wind_unit: string;
    wind_direction?: number;
    apparent_temp?: number;
    is_day?: number;
    precipitation?: number;
    weather_code?: number;
  };

  daily: DailyWeather;
  hourly: HourlyWeather;

  current_units?: Record<string, string>;
  hourly_units?: Record<string, string>;
  daily_units?: Record<string, string>;
}
