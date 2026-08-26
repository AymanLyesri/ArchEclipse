pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of variables.ts weather pipeline: IP geolocation -> open-meteo,
// refreshed every 10 minutes. Same endpoints as AGS.
QtObject {
    id: root

    property var data: null          // {city, current:{temp,temp_unit,...}, daily:{...}, hourly:{...}}

    function fetch() {
        geoProc.running = true;
    }

    property string _lat: ""
    property string _lon: ""

    property Process geoProc: Process {
        command: ["curl", "-fsSL", "--connect-timeout", "8", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root._lat = j.loc.split(",")[0];
                    root._lon = j.loc.split(",")[1];
                    root._city = j.city || "";
                    wxProc.running = true;
                } catch (e) { console.warn("[Weather] geo failed", e); }
            }
        }
    }
    property string _city: ""

    readonly property string _wxUrl:
        `https://api.open-meteo.com/v1/forecast?latitude=${root._lat}&longitude=${root._lon}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,apparent_temperature,is_day,precipitation,weather_code&hourly=temperature_2m,weather_code,precipitation&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_hours,wind_speed_10m_max&timezone=auto&forecast_days=2`

    property Process wxProc: Process {
        command: ["curl", "-fsSL", "--connect-timeout", "8", root._wxUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    root.data = { city: root._city || "Auto (IP)", current: p.current ?? {}, current_units: p.current_units ?? {},
                                  daily: p.daily ?? {}, hourly: p.hourly ?? {} };
                } catch (e) { console.warn("[Weather] parse failed", e); }
            }
        }
    }

    // icon mapping — mirrors weatherIcon() in Weather.tsx (\u escapes preserved)
    function icon(code) {
        if (code == null) return "\u{F0599}";
        if (code === 0) return "\u{F0599}";
        if (code <= 2) return "\u{F0595}";
        if (code === 3) return "\u{F0594}";
        if (code >= 45 && code <= 48) return "\u{F05B1}";
        if (code >= 51 && code <= 67) return "\u{F0597}";
        if (code >= 71 && code <= 86) return "\u{F059A}";
        if (code >= 95) return "\u{F05EB}";
        return "\u{F0596}";   // rainy fallback
    }
    readonly property var codeInfo: ({})
    function description(code) {
        if (code == null) return "Unknown";
        if (code === 0) return "Clear sky";
        if (code === 1) return "Mainly clear";
        if (code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Foggy";
        if ((code >= 51 && code <= 57)) return "Drizzle";
        if ((code >= 61 && code <= 67)) return "Rain";
        if ((code >= 71 && code <= 77)) return "Snow";
        if ((code >= 80 && code <= 82)) return "Showers";
        if (code >= 95) return "Thunderstorm";
        return "Unknown";
    }

    property Timer _refreshTimer: Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.fetch() }
}
