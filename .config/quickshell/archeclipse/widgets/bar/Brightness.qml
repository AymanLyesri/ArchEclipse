import QtQuick
import qs.theme
import qs.services
import qs.widgets.shared

Rectangle {
    id: root

    // Initialize from the service (not a hardcoded 1.0): DefaultBar is
    // recreated on every return to the default state, and a hardcoded
    // default would show a stale 100% until the next brightness change.
    property real level: Brightness.screen
    property bool pulse: false
    readonly property int fixedWidth: 220

    // Visible only when a backlight exists (no /sys/class/backlight/* on
    // desktops → hidden). Single source of truth is the Brightness service; the old local `backlightCheck.outputLines` read a
    // non-existent StdioCollector property, threw, and the catch{}
    // returned true — so the icon showed on desktops.
    readonly property bool hasBacklight: Brightness.hasBacklight

    width: pulse ? fixedWidth : content.width
    height: Theme.barContentHeight
    radius: Theme.radius
    color: pulse ? Theme.surface : "transparent"
    visible: root.hasBacklight

    // Live sync from the Brightness service (inotify file events, zero
    // polling): external changes update + reveal the slider, the first
    // sync is silent (mount / DefaultBar recreation on every return to
    // the default bar state) — Volume._firstVol parity.
    Connections {
        target: Brightness
        function onScreenChanged() {
            const newLevel = Brightness.screen;
            const first = root._firstLevel;
            root._firstLevel = false;
            if (Math.abs(newLevel - root.level) > 0.005) {
                root.level = newLevel;
                // reveal slider on external change, then auto-hide after 2s
                if (!first)
                    root.showSliderTemp();
            }
        }
    }

    // external change → reveal + 2s hide timeout
    property bool sliderRevealed: false
    property bool keepOpen: false
    property bool _firstLevel: true
    function showSliderTemp() {
        root.sliderRevealed = true;
        hideTimer.restart();
    }
    function hideSlider() {
        if (!root.keepOpen)
            root.sliderRevealed = false;
    }
    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.hideSlider()
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.level > 0.75 ? "\udb80\udce0" : root.level > 0.5 ? "\udb80\udcdf" : "\udb80\udcde"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.level * 100) + "%"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        AppSlider {
            id: briSlider
            visible: root.pulse || root.sliderRevealed || briHover.hovered
            width: visible ? 100 : 0
            anchors.verticalCenter: parent.verticalCenter
            from: 0.01
            to: 1
            stepSize: 0.01
            value: root.level
            onMoved: {
                root.level = briSlider.value;
                Brightness.setScreen(briSlider.value);
            }
        }
    }

    // Hover dwell (Settings.revealPressure, 0 = instant) so brushing the
    // cursor across the bar doesn't reveal the slider by accident.
    Timer {
        id: dwellTimer
        interval: Settings.revealPressure
        repeat: false
        onTriggered: {
            root.keepOpen = true;
            root.sliderRevealed = true;
            hideTimer.stop();
        }
    }
    // Hover keeps the reveal open; cancel + restart the 2s timer on leave
    HoverHandler {
        id: briHover
        onHoveredChanged: {
            if (briHover.hovered) {
                if (Settings.revealPressure <= 0) {
                    root.keepOpen = true;
                    root.sliderRevealed = true;
                    hideTimer.stop();
                } else {
                    dwellTimer.restart();
                }
            } else {
                dwellTimer.stop();
                root.keepOpen = false;
                hideTimer.restart();
            }
        }
    }
}
