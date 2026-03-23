export interface weatherInterface {
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
