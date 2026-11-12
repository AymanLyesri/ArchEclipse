import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.shared

// Unified card for WeatherWidget (compact) and WeatherIsland: a poster condition panel with a
// stat band inside, then the forecast as two flat bands instead of little boxes.
Item {
    id: root
    property bool showForecast: true

    // Implicit size for island wrappers (a bare Item has none):
    // fixed card width, height follows the laid-out content.
    implicitWidth: 460
    implicitHeight: content.implicitHeight

    readonly property var cur: root.wx ? (root.wx.current ?? {}) : ({})
    readonly property var day: root.wx ? (root.wx.daily ?? {}) : ({})
    readonly property var hour: root.wx ? (root.wx.hourly ?? {}) : ({})
    readonly property var cu: root.wx ? (root.wx.current_units ?? {}) : ({})
    readonly property bool hasData: root.wx !== null

    property var wx: Weather.data

    readonly property string tempUnit: cu.temperature_2m || "°C"
    readonly property string windUnit: cu.wind_speed_10m || "km/h"
    readonly property string codeBg: hasData ? Weather.background(cur.weather_code) : "transparent"

    // Today's headline numbers, shared by the stat band and the forecast strip.
    readonly property var statItems: [
        {
            icon: Icons.sunrise,
            label: "Sunrise",
            value: Weather.formatTime(root.day.sunrise?.[0])
        },
        {
            icon: Icons.sunset,
            label: "Sunset",
            value: Weather.formatTime(root.day.sunset?.[0])
        },
        {
            icon: Icons.humidity,
            label: "Humidity",
            value: Weather.fmt(root.cur.relative_humidity_2m, "%")
        },
        {
            icon: Icons.wind,
            label: "Wind",
            value: Weather.fmtRaw(root.cur.wind_speed_10m, "") + " " + root.windUnit
        }
    ]

    Column {
        id: content
        spacing: Theme.spaceMd
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
            spacing: Theme.spaceMd

            // ---- condition poster: city + temperature lead, stats sit inside the same plane ----
            Rectangle {
                width: parent.width
                height: hero.implicitHeight + Theme.pad * 4
                color: root.codeBg
                radius: Theme.radius

                ColumnLayout {
                    id: hero
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.pad * 2
                    spacing: Theme.spaceMd

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceXs

                            RowLayout {
                                spacing: Theme.spaceXs
                                Text {
                                    text: Icons.location
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeLabel
                                    color: Theme.onPlateInkDim
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.wx.city || "Auto (IP)"
                                    elide: Text.ElideRight
                                    color: Theme.accentFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeSubtitle
                                    font.weight: Font.DemiBold
                                }
                            }

                            // The temperature is the one number the card is about.
                            Text {
                                text: Weather.fmtRaw(root.cur.temperature_2m, root.tempUnit)
                                color: Theme.accentFg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.typeDisplay
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: Weather.description(root.cur.weather_code)
                                color: Theme.onPlateInk
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.typeBody
                            }

                            Text {
                                text: "Feels like " + Weather.fmtRaw(root.cur.apparent_temperature, root.tempUnit)
                                    + " · " + Weather.formatDate(root.day.time?.[0])
                                color: Theme.onPlateInkDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.typeCaption
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: Weather.icon(root.cur.weather_code)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeDisplay * 1.6
                            color: Theme.accentFg
                        }
                    }

                    // Stat band: four peers, evenly split, no per-cell plates or outlines.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceXs
                        spacing: Theme.spaceSm

                        Repeater {
                            model: root.statItems
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: modelData.icon
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeLabel
                                    color: Theme.accentFg
                                }
                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeCaption
                                    color: Theme.onPlateInkDim
                                }
                                Text {
                                    text: modelData.value
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeLabel
                                    font.weight: Font.DemiBold
                                    color: Theme.accentFg
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // City search: one quiet row under the poster content.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm

                        AppTextField {
                            id: cityEntry
                            Layout.fillWidth: true
                            height: 30
                            color: Theme.accentFg
                            fillColor: Theme.scrimSoft
                            placeholderTextColor: Qt.alpha(Theme.onMediaInk, 0.8)
                            placeholderText: "Search a city..."
                            onAccepted: root.applyCity()
                            Component.onCompleted: text = Weather._cityOverride
                        }
                        AppButton {
                            height: 30
                            icon: Icons.check
                            pixelSize: Theme.typeLabel
                            cornerRadius: Theme.radius
                            idleBg: Theme.scrimSoft
                            idleFg: Theme.accentFg
                            hoverBg: Theme.scrimSoft
                            tooltipText: "Search city"
                            onClicked: root.applyCity()
                        }
                        AppButton {
                            height: 30
                            icon: Icons.location
                            pixelSize: Theme.typeLabel
                            cornerRadius: Theme.radius
                            idleBg: Theme.scrimSoft
                            idleFg: Theme.accentFg
                            hoverBg: Theme.scrimSoft
                            tooltipText: "Auto (IP)"
                            onClicked: root.clearCity()
                        }
                    }
                }
            }

            // ---- today: one band, four numbers, label on the left edge ----
            Column {
                visible: root.showForecast
                width: parent.width
                spacing: Theme.spaceSm

                Text {
                    text: "TODAY"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeCaption
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }

                Card {
                    width: parent.width
                    height: contentMargins * 2 + todayRow.height
                    contentMargins: Theme.pad
                    contentSpacing: Theme.spaceSm

                    RowLayout {
                        id: todayRow
                        width: parent.width
                        spacing: Theme.spaceSm
                        Repeater {
                            model: [
                                {
                                    label: "High",
                                    value: Weather.fmtRaw(root.day.temperature_2m_max?.[0], root.tempUnit)
                                },
                                {
                                    label: "Low",
                                    value: Weather.fmtRaw(root.day.temperature_2m_min?.[0], root.tempUnit)
                                },
                                {
                                    label: "Rain",
                                    value: (root.day.precipitation_sum?.[0] ?? 0) + " mm"
                                },
                                {
                                    label: "Gust",
                                    value: (root.day.wind_speed_10m_max?.[0] ?? "N/A") + " " + root.windUnit
                                }
                            ]
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: modelData.label
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeCaption
                                }
                                Text {
                                    text: modelData.value
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeLabel
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // ---- next hours: one band, each hour a small column ----
            Column {
                visible: root.showForecast
                width: parent.width
                spacing: Theme.spaceSm

                Text {
                    text: "NEXT HOURS"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeCaption
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }

                Card {
                    width: parent.width
                    height: contentMargins * 2 + hourRow.height
                    contentMargins: Theme.pad
                    contentSpacing: Theme.spaceSm

                    RowLayout {
                        id: hourRow
                        width: parent.width
                        spacing: Theme.spaceSm
                        Repeater {
                            model: root.hourlyItems()
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.time
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeCaption
                                }
                                Text {
                                    text: Weather.icon(modelData.code)
                                    font.family: Theme.fontFamily
                                    color: Theme.accent
                                    font.pixelSize: Theme.typeTitle
                                }
                                Text {
                                    text: Math.round(modelData.temp) + "°"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeLabel
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    visible: modelData.precip > 0
                                    text: modelData.precip + "mm"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeCaption
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

    // City entry mirrors the persisted override: typing writes nothing until apply/clear, and
    // external changes fill the field unless the user is editing it.
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
