import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services

// Port of Weather.tsx WeatherButton — compact bar button with icon + temp,
// weather-code-colored background, click opens popover with full WeatherWidget.
// AGS: <button class="weather-button" css={dynamic background} onClicked={popover.popup/popdown}>
// QS: Rectangle + MouseArea + Popup with WeatherWidget { moreDetails: true }
Rectangle {
    id: root
    height: 22
    radius: Theme.radius
    // color set by weatherBg binding below
    property var popover: null

    // Reactive weather data
    readonly property var wx: Weather.data
    readonly property var cur: wx ? (wx.current ?? {}) : ({})
    readonly property var cu: wx ? (wx.current_units ?? {}) : ({})
    readonly property bool hasData: wx !== null

    // Dynamic background color based on weather code (matches AGS CSS)
    readonly property string weatherBg: hasData ? Weather.background(cur.weather_code) : "transparent"
    color: hasData ? root.weatherBg : "transparent"

    // Tooltip
    ToolTip.visible: hover.hovered
    ToolTip.text: hasData ? Weather.description(cur.weather_code) : "Weather data unavailable"
    ToolTip.delay: 400

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacing

        // Weather icon
        Text {
            visible: root.hasData
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.icon(root.cur.weather_code)
            color: "white"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }

        // Temp + description (ellided)
        Text {
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
            width: 200
            color: "white"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    // Click toggles popover
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.popover) return;
            if (root.popover.visible) root.popover.close();
            else root.popover.open();
        }
    }

    // Popover with full WeatherWidget (moreDetails=true)
    Popup {
        id: wxPopover
        parent: root
        y: root.height + 6
        x: root.width / 2 - wxPopover.implicitWidth / 2
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        // Background handled by WeatherWidget's own card background
        background: Rectangle { color: "transparent" }

        onVisibleChanged: {
            if (visible) wxPopover.add_css_class("popover-open");
            else wxPopover.remove_css_class("popover-open");
        }

        WeatherWidget {
            moreDetails: true
            compact: true
        }
    }

    HoverHandler { id: hover }

    // Auto-create popover on first use
    Component.onCompleted: {
        root.popover = wxPopover
    }
}