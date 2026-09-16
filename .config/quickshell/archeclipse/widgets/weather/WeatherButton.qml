import QtQuick
import qs.theme
import qs.services

// Compact bar button with icon + temp on a weather-code-colored background.
// Hover/click pulses the full weather island (BarState "weather").
Rectangle {
    id: root
    height: Theme.barContentHeight
    // implicitWidth (not width) so the button keeps its natural size in
    // Row layouts but can stretch via anchors when there is empty space.
    implicitWidth: content.implicitWidth + 14
    radius: Theme.radius
    // color set by weatherBg binding below

    // Reactive weather data
    readonly property var wx: Weather.data
    readonly property var cur: wx ? (wx.current ?? {}) : ({})
    readonly property var cu: wx ? (wx.current_units ?? {}) : ({})
    readonly property bool hasData: wx !== null

    // Dynamic background color based on weather code
    readonly property string weatherBg: hasData ? Weather.background(cur.weather_code) : "transparent"
    color: hover.hovered ? (hasData ? root.weatherBg : Theme.surfaceHover) : (hasData ? root.weatherBg : "transparent")

    Behavior on color { ColorAnimation { duration: 200 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        // Weather icon
        Text {
            id: iconText
            visible: root.hasData
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.icon(root.cur.weather_code)
            color: "white"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }

        // Temp + description (ellided only if it overflows the stretched button)
        Text {
            id: descText
            visible: root.hasData
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.hasData) return "";
                const t = Math.round(root.cur.temperature_2m ?? 0);
                const unit = root.cu.temperature_2m || "°C";
                const desc = Weather.description(root.cur.weather_code);
                return `${t}${unit} ${desc}`;
            }
            elide: Text.ElideRight
            width: {
                const avail = root.width - 14 - content.spacing - (iconText.visible ? iconText.implicitWidth : 0);
                // root.width is 0 before anchors resolve — fall back to natural size
                if (root.width <= 0 || avail < 0)
                    return Math.min(implicitWidth, 120);
                return Math.min(implicitWidth, avail);
            }
            color: "white"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: BarState.activate("weather", 3000)
    }

    // Hover dwell (Settings.revealInPressure, 0 = instant) so brushing the
    // cursor across the bar doesn't pulse the island by accident.
    Timer {
        id: dwellTimer
        interval: Settings.revealInPressure
        repeat: false
        onTriggered: BarState.activate("weather", 3000)
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hover.hovered) {
                if (Settings.revealInPressure <= 0)
                    BarState.activate("weather", 3000);
                else
                    dwellTimer.restart();
            } else {
                dwellTimer.stop();
            }
        }
    }
}
