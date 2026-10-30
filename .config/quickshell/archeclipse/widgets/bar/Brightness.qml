import QtQuick
import qs.theme
import qs.services
import qs.widgets.shared

Rectangle {
    id: root

    property string monitorName: ""

    // Initialize from the service, never a hardcoded 1.0: DefaultBar is recreated on every
    // return to default, so a literal would show a stale 100%.
    property real level: Brightness.screenFor(root.monitorName)
    property bool pulse: false
    readonly property int fixedWidth: 220

    // Visible only when a backlight exists (desktops have no /sys/class/backlight/*); the old
    // local check read a non-existent property and threw, so the icon showed anyway.
    readonly property bool hasBacklight: Brightness.hasBacklightFor(root.monitorName)

    width: pulse ? fixedWidth : content.width
    height: Theme.barContentHeight
    radius: Theme.radius
    color: pulse ? Theme.surface : "transparent"
    visible: root.hasBacklight

    // Live sync from the Brightness service (inotify, zero polling): external changes update
    // the level silently and BarState pulses the OSD — hover dwell opens the slider.
    Connections {
        target: Brightness
        function onScreenChanged() { root.syncLevel(); }
        function onTargetNameChanged() { root.syncLevel(); }
    }
    onMonitorNameChanged: root.syncLevel()
    function syncLevel() {
        const newLevel = Brightness.screenFor(root.monitorName);
        if (Math.abs(newLevel - root.level) > 0.005)
            root.level = newLevel;
    }

    // Hover/click reveal + reveal-out hide timeout
    property bool sliderRevealed: false
    property bool keepOpen: false
    // True while the reveal glide is in flight (width between the two stops): DefaultBar
    // mirrors it into rigidWidth so the bar edge tracks the slider instead of chasing it.
    readonly property bool revealing: briSlider.width > 0.5 && briSlider.width < 99.5
    function hideSlider() {
        if (!root.keepOpen)
            root.sliderRevealed = false;
    }
    Timer {
        id: hideTimer
        interval: Settings.revealOutPressure
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
            font.preferShaping: false
        }
        AppSlider {
            id: briSlider
            // Reveal on DefaultSpatial so edge and track move as one: width glides 0 <-> 100,
            // opacity fades with it, clip keeps the handle in; visible holds through the fade.
            visible: (root.pulse || root.sliderRevealed) || briSlider.width > 0.5
            opacity: (root.pulse || root.sliderRevealed) ? 1 : 0
            width: (root.pulse || root.sliderRevealed) ? 100 : 0
            clip: true
            Behavior on width {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
            anchors.verticalCenter: parent.verticalCenter
            from: 0.01
            to: 1
            stepSize: 0.01
            value: root.level
            onMoved: {
                root.level = briSlider.value;
                Brightness.setScreen(briSlider.value, root.monitorName);
            }
            Binding {
                target: briSlider
                property: "value"
                value: root.level
                when: !briSlider.pressed
            }
        }
    }

    // Hover dwell (Settings.revealInPressure, 0 = instant) so brushing the
    // cursor across the bar doesn't reveal the slider by accident.
    Timer {
        id: dwellTimer
        interval: Settings.revealInPressure
        repeat: false
        onTriggered: {
            root.keepOpen = true;
            root.sliderRevealed = true;
            hideTimer.stop();
        }
    }
    // Hover keeps the reveal open; cancel + restart the reveal-out timer on leave
    HoverHandler {
        id: briHover
        onHoveredChanged: {
            if (briHover.hovered) {
                if (Settings.revealInPressure <= 0) {
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
