import QtQuick
import qs.theme
import qs.services
import qs.widgets.shared

// Compact bar button with icon + temp on a weather-code-colored background; hover/click pulses
// the weather island. While the launcher is open the pill unfolds stats rows vertically.
Rectangle {
    id: root
    property string monitorName: ""
    property bool expanded: false
    // bottom-oriented bars grow upward instead of off-screen
    readonly property bool growUp: !Settings.barOrientation
    readonly property real extraGap: Theme.spacing / 2
    readonly property real extraH: (statLine.visible ? statLine.implicitHeight + extraGap : 0)
        + (rangeLine.visible ? rangeLine.implicitHeight + extraGap : 0)

    height: root.expanded ? Theme.sidePillHeight + root.extraH : Theme.sidePillHeight
    Behavior on height { Anim {} }
    // implicitWidth (not width) so the button keeps its natural size in
    // Row layouts but can stretch via anchors when there is empty space.
    implicitWidth: content.implicitWidth + Theme.islandPad * 2
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

    Behavior on color { ColorAnimation { duration: Theme.anim.defaultEffects } }

    Row {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        // pinned inside the pill's compact band so extra rows hang off it
        y: growUp ? parent.height - Theme.sidePillHeight + (Theme.sidePillHeight - height) / 2
                  : (Theme.sidePillHeight - height) / 2
        spacing: Theme.spacing

        // Weather icon
        Text {
            id: iconText
            visible: root.hasData
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.icon(root.cur.weather_code)
            color: Theme.onPlateInk
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
                const avail = root.width - Theme.islandPad * 2 - content.spacing - (iconText.visible ? iconText.implicitWidth : 0);
                // root.width is 0 before anchors resolve — fall back to natural size
                if (root.width <= 0 || avail < 0)
                    return Math.min(implicitWidth, 120);
                return Math.min(implicitWidth, avail);
            }
            color: Theme.onPlateInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    // extra rows revealed while expanded: feels/wind/humidity + today's range
    Text {
        id: statLine
        visible: root.hasData
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { Anim { type: Anim.FastEffects } }
        x: Theme.islandPad
        width: Math.max(0, root.width - Theme.islandPad * 2)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        y: growUp ? content.y - height - root.extraGap
                  : content.y + content.height + root.extraGap
        text: {
            if (!root.hasData) return "";
            const feels = Math.round(root.cur.apparent_temperature ?? 0);
            const unit = root.cu.apparent_temperature || "°";
            const wind = Math.round(root.cur.wind_speed_10m ?? 0);
            const windUnit = root.cu.wind_speed_10m || "";
            const hum = Math.round(root.cur.relative_humidity_2m ?? 0);
            return `feels ${feels}${unit} · ${wind}${windUnit} · ${hum}%`;
        }
        color: Theme.onPlateInk
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }

    Text {
        id: rangeLine
        visible: root.hasData && (root.wx.daily?.temperature_2m_max?.length ?? 0) > 0
            && (root.wx.daily?.temperature_2m_min?.length ?? 0) > 0
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { Anim { type: Anim.FastEffects } }
        x: Theme.islandPad
        width: Math.max(0, root.width - Theme.islandPad * 2)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        y: growUp ? statLine.y - height - root.extraGap
                  : statLine.y + statLine.height + root.extraGap
        text: {
            const d = root.wx ? root.wx.daily : null;
            if (!d) return "";
            const u = root.cu.temperature_2m || "°";
            return `↑${Math.round(d.temperature_2m_max[0])}${u} ↓${Math.round(d.temperature_2m_min[0])}${u}`;
        }
        color: Theme.onPlateInk
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: BarState.activate("weather", 3000, root.monitorName)
    }

    // Hover dwell (Settings.revealInPressure, 0 = instant) so brushing the
    // cursor across the bar doesn't pulse the island by accident.
    Timer {
        id: dwellTimer
        interval: Settings.revealInPressure
        repeat: false
        onTriggered: BarState.activate("weather", 3000, root.monitorName)
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hover.hovered) {
                if (Settings.revealInPressure <= 0)
                    BarState.activate("weather", 3000, root.monitorName);
                else
                    dwellTimer.restart();
            } else {
                dwellTimer.stop();
            }
        }
    }
}
