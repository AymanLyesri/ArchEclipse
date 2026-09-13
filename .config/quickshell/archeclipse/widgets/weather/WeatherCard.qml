import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services
import qs.widgets.shared

// Unified weather card — single UI for WeatherWidget (compact) and
// WeatherIsland (forecast). Current-conditions card with sunrise/sunset,
// humidity/precip/wind, and a city search (apply/clear). When
// showForecast=true, also renders Today's Forecast and Hourly Forecast.
Item {
    id: root
    property bool showForecast: true

    // Implicit size for island wrappers (a bare Item has none):
    // fixed card width, height follows the laid-out content.
    implicitWidth: 460
    implicitHeight: content.implicitHeight

    // Value formatting via Weather.fmt/fmtRaw/formatTime/formatDate.


    readonly property var cur: root.wx ? (root.wx.current ?? {}) : ({})
    readonly property var day: root.wx ? (root.wx.daily ?? {}) : ({})
    readonly property var hour: root.wx ? (root.wx.hourly ?? {}) : ({})
    readonly property var cu: root.wx ? (root.wx.current_units ?? {}) : ({})
    readonly property bool hasData: root.wx !== null

    property var wx: Weather.data

    readonly property string tempUnit: cu.temperature_2m || "°C"
    readonly property string windUnit: cu.wind_speed_10m || "km/h"
    readonly property string codeBg: hasData ? Weather.background(cur.weather_code) : "transparent"

    Column {
        id: content
        spacing: 12
        width: parent.width

        // No-data placeholder
        Label {
            visible: !root.hasData
            text: "Weather data unavailable"
            color: Theme.fgDim
        }

        Column {
            visible: root.hasData
            width: parent.width
            spacing: 12

            // Current conditions panel (code-colored background)
            Rectangle {
                width: parent.width
                height: headerCol.height + 28
                color: root.codeBg
                radius: Theme.radius

                Column {
                    id: headerCol
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 14
                    width: parent.width - 28
                    spacing: 10

                    Row {
                        spacing: 25
                        width: parent.width

                        // Main column: icon, city, temp, description, feels-like, date
                        Column {
                            spacing: 4
                            width: parent.width / 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.icon(root.cur.weather_code)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 12
                                color: Theme.accentFg
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.hasData ? "\u{F06EF} " + (root.wx.city || "Auto (IP)") : ""
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                color: Theme.accentFg
                                font.family: Theme.fontFamily
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.fmtRaw(root.cur.temperature_2m, root.tempUnit)
                                font.pixelSize: Theme.fontSize + 10
                                font.bold: true
                                color: Theme.accentFg
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.description(root.cur.weather_code)
                                color: "#E0E0E0"
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `Feels like: ${Weather.fmtRaw(root.cur.apparent_temperature, root.tempUnit)}`
                                color: "#CFCFCF"
                                font.pixelSize: Theme.fontSize - 2
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.formatDate(root.day.time?.[0])
                                color: "#CFCFCF"
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }

                        // Right column: sun, humidity, precip, wind
                        Column {
                            spacing: 5
                            width: parent.width / 2

                            Row {
                                spacing: 5
                                anchors.horizontalCenter: parent.horizontalCenter
                                Column {
                                    spacing: 2
                                    Text {
                                        text: "\u{E00E}"
                                        font.family: Theme.fontFamily
                                        color: Theme.accentFg
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: Weather.formatTime(root.day.sunrise?.[0])
                                        color: Theme.accentFg
                                        font.pixelSize: Theme.fontSize - 2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                                Text {
                                    text: "\u{F0E0}"
                                    color: "#DDD"
                                    font.pixelSize: Theme.fontSize
                                    font.family: Theme.fontFamily
                                }
                                Column {
                                    spacing: 2
                                    Text {
                                        text: "\u{E00F}"
                                        font.family: Theme.fontFamily
                                        color: Theme.accentFg
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: Weather.formatTime(root.day.sunset?.[0])
                                        color: Theme.accentFg
                                        font.pixelSize: Theme.fontSize - 2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Row {
                                spacing: 5
                                anchors.horizontalCenter: parent.horizontalCenter
                                Rectangle {
                                    width: 90
                                    height: 34
                                    radius: Theme.chipRadius
                                    color: "#22FFFFFF"
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            text: "\u{E04A}"
                                            font.family: Theme.fontFamily
                                            color: Theme.accentFg
                                            font.pixelSize: Theme.fontSize - 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: Weather.fmt(root.cur.relative_humidity_2m, "%")
                                            color: Theme.accentFg
                                            font.pixelSize: Theme.fontSize - 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 90
                                    height: 34
                                    radius: Theme.chipRadius
                                    color: "#22FFFFFF"
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            text: "\u{E04B}"
                                            font.family: Theme.fontFamily
                                            color: Theme.accentFg
                                            font.pixelSize: Theme.fontSize - 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: Weather.fmt(root.cur.precipitation, " mm")
                                            color: Theme.accentFg
                                            font.pixelSize: Theme.fontSize - 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 190
                                height: 34
                                radius: Theme.chipRadius
                                color: "#22FFFFFF"
                                anchors.horizontalCenter: parent.horizontalCenter
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        text: "\u{E04C}"
                                        font.family: Theme.fontFamily
                                        color: Theme.accentFg
                                        font.pixelSize: Theme.fontSize - 3
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: `${Weather.fmtRaw(root.cur.wind_speed_10m, "")} ${root.windUnit} ${Weather.windDirection(root.cur.wind_direction_10m)}`
                                        color: Theme.accentFg
                                        font.pixelSize: Theme.fontSize - 3
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }

                    // City search entry + apply + clear
                    Row {
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.9

                        AppTextField {
                            id: cityEntry
                            placeholderText: (root.wx?.city ? "Search..." : "Not " + (root.wx?.city || "IP") + "?...")
                            onAccepted: root.applyCity()
                            width: parent.width - 76
                            height: 30
                            color: Theme.accentFg
                            fillColor: "#33000000"
                            placeholderTextColor: "#CCFFFFFF"
                            Component.onCompleted: text = Weather._cityOverride
                        }
                        AppButton {
                            width: 32
                            height: 30
                            icon: "\u{F00C}"
                            pixelSize: 14
                            cornerRadius: Theme.chipRadius
                            idleBg: "#33000000"
                            idleFg: Theme.accentFg
                            hoverBg: "#33000000"
                            outlined: true
                            outlineColor: "#55FFFFFF"
                            tooltipText: "Search city"
                            onClicked: root.applyCity()
                        }
                        AppButton {
                            width: 32
                            height: 30
                            icon: "\u{F1A2}"
                            pixelSize: 14
                            cornerRadius: Theme.chipRadius
                            idleBg: "#33000000"
                            idleFg: Theme.accentFg
                            hoverBg: "#33000000"
                            outlined: true
                            outlineColor: "#55FFFFFF"
                            tooltipText: "Auto (IP)"
                            onClicked: root.clearCity()
                        }
                    }
                }
            }

            // Today's Forecast (showForecast only — popover mode)
            Column {
                visible: root.showForecast
                width: parent.width
                spacing: 12

                Label {
                    text: "Today's Forecast"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.fg
                }

                Row {
                    spacing: 8
                    width: parent.width
                    Repeater {
                        model: [
                            {
                                label: "Max",
                                value: Weather.fmtRaw(root.day.temperature_2m_max?.[0], root.tempUnit)
                            },
                            {
                                label: "Min",
                                value: Weather.fmtRaw(root.day.temperature_2m_min?.[0], root.tempUnit)
                            },
                            {
                                label: "Rain",
                                value: `${root.day.precipitation_sum?.[0] ?? 0} mm`
                            },
                            {
                                label: "Wind",
                                value: `${root.day.wind_speed_10m_max?.[0] ?? "N/A"} ${root.windUnit}`
                            }
                        ]
                        delegate: Rectangle {
                            width: parent.width / 4 - 6
                            height: 56
                            radius: Theme.cardRadius
                            color: Theme.surface
                            border.color: Theme.border
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    text: modelData.label
                                    color: Theme.fgDim
                                    font.pixelSize: Theme.fontSize - 3
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: modelData.value
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize - 2
                                    font.bold: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }

            // Hourly Forecast (showForecast only)
            Column {
                visible: root.showForecast
                width: parent.width
                spacing: 12

                Label {
                    text: "Hourly Forecast"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.fg
                }

                Row {
                    spacing: 8
                    width: parent.width
                    Repeater {
                        model: root.hourlyItems()
                        delegate: Rectangle {
                            width: parent.width / 4 - 6
                            height: 78
                            radius: Theme.cardRadius
                            color: Theme.surface
                            border.color: Theme.border
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: Weather.icon(modelData.code)
                                    font.family: Theme.fontFamily
                                    color: Theme.accent
                                    font.pixelSize: Theme.fontSize + 4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: `${Math.round(modelData.temp)}°  ${modelData.time}`
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize - 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    visible: modelData.precip > 0
                                    text: `${modelData.precip}mm`
                                    color: Theme.accent
                                    font.pixelSize: Theme.fontSize - 3
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Build hourly forecast items: starting from current hour, every 3h, 4 items
    function hourlyItems() {
        const h = root.hour;
        if (!h || !h.time || h.time.length === 0)
            return [];
        const curTime = root.cur.time;
        let currentHourISO;
        if (curTime) {
            currentHourISO = String(curTime).slice(0, 13) + ":00";
        } else {
            const now = new Date();
            currentHourISO = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}T${String(now.getHours()).padStart(2, "0")}:00`;
        }
        let startIndex = h.time.findIndex(t => t >= currentHourISO);
        let base = startIndex === -1 ? 0 : startIndex;
        const items = [];
        for (let i = 0; i < 4; i++) {
            const idx = base + i * 3;
            if (idx >= h.time.length)
                break;
            const timeStr = h.time[idx];
            const d = new Date(String(timeStr).replace("T", " ").replace(/-/g, "/"));
            const timeLabel = !isNaN(d.getTime()) ? d.toLocaleTimeString(Qt.locale(), "HH:mm") : "N/A";
            const temp = h.temperature_2m?.[idx];
            const code = h.weather_code?.[idx];
            const precip = h.precipitation?.[idx] ?? 0;
            items.push({
                time: timeLabel,
                temp: temp,
                code: code,
                precip: precip
            });
        }
        return items;
    }

    // City entry mirrors the persisted override: typing never writes
    // through until apply/clear, external changes fill the field unless
    // the user is actively editing it.
    Connections {
        target: Weather
        function on_CityOverrideChanged() {
            if (!cityEntry.activeFocus && cityEntry.text !== Weather._cityOverride)
                cityEntry.text = Weather._cityOverride;
        }
    }

    function applyCity() {
        const text = cityEntry.text;
        if (!text || text.trim() === "") {
            root.clearCity();
            return;
        }
        Weather.setCity(text);
    }
    function clearCity() {
        Weather.setCity("");
        cityEntry.text = "";
    }
}
