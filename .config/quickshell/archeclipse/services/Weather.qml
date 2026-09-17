pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Weather pipeline: IP geolocation -> open-meteo, refreshed every 10
// minutes, with optional city override. Same open-meteo endpoints throughout.
QtObject {
    id: root

    property var data: null          // {city, current:{...}, daily:{...}, hourly:{...}} (raw open-meteo shape)
    property string _cityOverride: ""  // persisted city override name (mirrors Settings.weatherCity)
    property string _lat: ""
    property string _lon: ""
    property bool _booted: false

    function parseJsonResponse(raw, source) {
        const payload = String(raw ?? "").trim();
        if (payload === "") {
            console.warn("[Weather] " + source + " returned an empty response");
            return null;
        }
        try {
            return JSON.parse(payload);
        } catch (e) {
            console.warn("[Weather] " + source + " returned invalid JSON");
            return null;
        }
    }

    // Boot once Settings are ready so a saved city wins over IP geo.
    // The refresh timer below no longer triggers on start — boot() owns
    // the first fetch.
    function boot() {
        if (root._booted)
            return;
        if (!Settings.ready)
            return;
        root._booted = true;
        _bootTimer.stop();
        const saved = (Settings.weatherCity || "").trim();
        if (saved !== "" && saved !== (root._cityOverride || "").trim())
            root.setCity(saved);
        else if (!root._lat || !root._lon)
            root.fetch();
    }

    // Re-check coordinates each fetch: if an override is set, skip IP geo.
    function fetch() {
        // Saved city raced ahead of boot (e.g. timer): resolve it first.
        if (!root._lat && !root._lon && !root._cityOverride) {
            const saved = (Settings.weatherCity || "").trim();
            if (saved !== "") {
                root.setCity(saved);
                return;
            }
        }
        if (root._lat && root._lon) { wxProc.running = true; return; }
        root.geoProc.running = true;
    }

    property Process geoProc: Process {
        command: ["curl", "-fsSL", "--retry", "2", "--retry-all-errors", "--connect-timeout", "8", "--max-time", "15", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parseJsonResponse(text, "ipinfo");
                if (j && typeof j.loc === "string" && j.loc.includes(",")) {
                    const coordinates = j.loc.split(",");
                    root._lat = coordinates[0];
                    root._lon = coordinates[1];
                    root._detectedCity = j.city || "";
                    wxProc.running = true;
                } else {
                    root.ifconfigFallback();
                }
            }
        }
    }
    property string _detectedCity: ""

    // ifconfig.co fallback for IP geolocation
    function ifconfigFallback() {
        fallbackProc.running = true;
    }
    property Process fallbackProc: Process {
        command: ["curl", "-fsSL", "--retry", "2", "--retry-all-errors", "--connect-timeout", "8", "--max-time", "15", "https://ifconfig.co/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parseJsonResponse(text, "ifconfig");
                if (j) {
                    if (j.latitude && j.longitude) {
                        root._lat = String(j.latitude);
                        root._lon = String(j.longitude);
                        root._detectedCity = j.city || "";
                        wxProc.running = true;
                    }
                }
            }
        }
    }

    readonly property string _wxUrl:
        `https://api.open-meteo.com/v1/forecast?latitude=${root._lat}&longitude=${root._lon}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,apparent_temperature,is_day,precipitation,weather_code&hourly=temperature_2m,weather_code,precipitation&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_hours,wind_speed_10m_max&timezone=auto&forecast_days=2`

    property Process wxProc: Process {
        command: ["curl", "-fsSL", "--retry", "2", "--retry-all-errors", "--connect-timeout", "8", "--max-time", "15", root._wxUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = root.parseJsonResponse(text, "open-meteo");
                if (p) {
                    const finalCity = root._cityOverride || root._detectedCity || "Unknown";
                    root.data = {
                        city: finalCity,
                        current: p.current ?? {},
                        current_units: p.current_units ?? {},
                        daily: p.daily ?? {},
                        hourly: p.hourly ?? {}
                    };
                }
            }
        }
    }

    property string _pendingCity: ""
    // setWeatherCity equivalent: "" clears override (Auto/IP), else geocodes.
    // Writes through to Settings.weatherCity so the choice survives restarts.
    function setCity(cityName) {
        if (!cityName || cityName.trim() === "") {
            root._cityOverride = "";
            root._pendingCity = "";
            if (Settings.weatherCity !== "")
                Settings.updateSetting("weather.city", "");
            root._lat = "";
            root._lon = "";
            root.fetch();
            return;
        }
        root._pendingCity = cityName.trim();
        geoCityProc.command = ["curl", "-fsSL", "--retry", "2", "--retry-all-errors", "--connect-timeout", "8", "--max-time", "15",
            "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(root._pendingCity) + "&count=1&format=json"];
        geoCityProc.running = true;
    }
    property Process geoCityProc: Process {
        command: ["curl", "-fsSL", "--connect-timeout", "8", "--max-time", "15", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const g = root.parseJsonResponse(text, "geocoding");
                if (g) {
                    if (g.results && g.results.length > 0) {
                        const r = g.results[0];
                        root._cityOverride = r.name;
                        root._lat = String(r.latitude);
                        root._lon = String(r.longitude);
                        if (Settings.weatherCity !== r.name)
                            Settings.updateSetting("weather.city", r.name);
                        root.fetch();
                    } else {
                        Notifications.notify({ summary: "Weather", body: "City '" + root._pendingCity + "' not found" });
                    }
                }
            }
        }
    }

    // --- mapping helpers (mirror Weather.tsx) ---

    // Nearest description + background color per WMO weather code
    readonly property var codeInfo: ({
        "0": { description: "Clear sky", background: "#0F4C81" },
        "1": { description: "Mainly clear", background: "#1F5D8A" },
        "2": { description: "Partly cloudy", background: "#2E5984" },
        "3": { description: "Overcast", background: "#4A5568" },
        "45": { description: "Foggy", background: "#4B5563" },
        "48": { description: "Depositing rime fog", background: "#4B5563" },
        "51": { description: "Light drizzle", background: "#0C4A6E" },
        "53": { description: "Moderate drizzle", background: "#0B3A67" },
        "55": { description: "Dense drizzle", background: "#1E3A8A" },
        "56": { description: "Light freezing drizzle", background: "#0C4A6E" },
        "57": { description: "Dense freezing drizzle", background: "#1E3A8A" },
        "61": { description: "Slight rain", background: "#0C4A6E" },
        "63": { description: "Moderate rain", background: "#0B3A67" },
        "65": { description: "Heavy rain", background: "#1E3A8A" },
        "66": { description: "Light freezing rain", background: "#0C4A6E" },
        "67": { description: "Heavy freezing rain", background: "#1E3A8A" },
        "71": { description: "Slight snow fall", background: "#334155" },
        "73": { description: "Moderate snow fall", background: "#1E40AF" },
        "75": { description: "Heavy snow fall", background: "#1E3A8A" },
        "77": { description: "Snow grains", background: "#334155" },
        "80": { description: "Slight rain showers", background: "#0C4A6E" },
        "81": { description: "Moderate rain showers", background: "#0B3A67" },
        "82": { description: "Violent rain showers", background: "#1E3A8A" },
        "85": { description: "Slight snow showers", background: "#334155" },
        "86": { description: "Heavy snow showers", background: "#1E3A8A" },
        "95": { description: "Thunderstorm", background: "#9A3412" },
        "96": { description: "Thunderstorm with slight hail", background: "#7C2D12" },
        "99": { description: "Thunderstorm with heavy hail", background: "#7F1D1D" }
    })
    function description(code) {
        if (code == null) return "Unknown";
        const info = root.codeInfo[String(code)];
        return info ? info.description : "Unknown";
    }
    function background(code) {
        if (code == null) return "#000000";
        const info = root.codeInfo[String(code)];
        return info ? info.background : "#000000";
    }

    // icon mapping — mirrors weatherIcon() in Weather.tsx
    function icon(code) {
        if (code == null) return "\u{F0599}";
        if (code === 0) return "\u{F0599}";
        if (code <= 2) return "\u{F0595}";
        if (code === 3) return "\u{F0594}";
        if (code >= 45 && code <= 48) return "\u{F05B1}";
        if (code >= 56 && code <= 57) return "\u{F0595}"; // hail
        if (code >= 65 && code <= 67) return "\u{F0596}"; // pouring
        if ((code >= 51 && code <= 64) || (code >= 80 && code <= 82)) return "\u{F0597}";
        if (code >= 71 && code <= 86) return "\u{F059A}";
        if (code >= 95) return "\u{F05EB}";
        return "\u{F0599}";
    }

    // Wind direction (16-point compass)
    readonly property var windDirNames: ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
    function windDirection(degrees) {
        if (degrees == null) return "";
        const idx = Math.round((degrees % 360) / 22.5) % 16;
        return root.windDirNames[idx];
    }

    // Shared value formatters (verbatim from widgets/weather/WeatherWidget.qml,
    // the single UI now living in WeatherCard.qml). null/empty -> "N/A".
    function fmt(v, unit) {
        return v != null && v !== "" ? `${Math.round(v)}${unit}` : "N/A";
    }
    function fmtRaw(v, unit) {
        return v != null && v !== "" ? `${v}${unit}` : "N/A";
    }

    // Format open-meteo ISO "YYYY-MM-DDTHH:MM" -> HH:MM
    function formatTime(iso) {
        if (!iso)
            return "N/A";
        const s = String(iso).replace("T", " ").replace(/-/g, "/");
        const d = new Date(s);
        if (isNaN(d.getTime()))
            return "N/A";
        return d.toLocaleTimeString(Qt.locale(), "HH:mm");
    }
    // Format open-meteo ISO -> "Weekday D Mon"
    function formatDate(iso) {
        if (!iso)
            return "N/A";
        const s = String(iso).replace("T", " ").replace(/-/g, "/");
        const d = new Date(s);
        if (isNaN(d.getTime()))
            return "N/A";
        return d.toLocaleDateString(Qt.locale(), "ddd d MMM");
    }

    property Timer _refreshTimer: Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: false; onTriggered: root.fetch() }
    property Timer _bootTimer: Timer { interval: 200; repeat: true; onTriggered: root.boot() }

    // Follow external Settings edits (settings UI / file reload) without
    // looping back on our own writes.
    property Connections _settingsConn: Connections {
        target: Settings
        function onWeatherCityChanged() {
            if (!root._booted || !Settings.ready)
                return;
            const saved = (Settings.weatherCity || "").trim();
            const cur = (root._cityOverride || "").trim();
            const pend = (root._pendingCity || "").trim();
            if (saved === cur || saved === pend)
                return;
            root.setCity(saved);
        }
        function onReadyChanged() {
            if (Settings.ready)
                root.boot();
        }
    }

    Component.onCompleted: {
        if (Settings.ready)
            root.boot();
        else
            _bootTimer.start();
    }
}
