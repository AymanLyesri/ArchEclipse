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
    // polling): external changes update the level silently and pulse the
    // OSD via BarState — the bar slider opens on hover dwell only.
    // (No onAdjusted hookup: value changes must not pop the slider.)
    Connections {
        target: Brightness
        // Value follows the controlled (focused) monitor silently — moving focus
        // to a monitor with another brightness must not pop the slider.
        function onScreenChanged() {
            const newLevel = Brightness.screen;
            if (Math.abs(newLevel - root.level) > 0.005)
                root.level = newLevel;
        }
    }

    // Hover/click reveal + reveal-out hide timeout
    property bool sliderRevealed: false
    property bool keepOpen: false
    // True exactly while the reveal glide is in flight (width parked between
    // the two stops). DefaultBar mirrors this into the pill's rigidWidth so
    // the bar edge tracks the slider per-frame instead of easing toward a
    // target that moves every frame.
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
        }
        AppSlider {
            id: briSlider
            // Animated reveal, on the pill's own DefaultSpatial curve so the
            // bar edge and the slider track move as one unit.
            //   width   — glides 0 <-> 100 (was a one-frame snap)
            //   opacity — rides FastEffects so the track fades in/out with it
            //   clip    — the 14px handle would otherwise spill left out of the
            //              Row while the track is mid-grow
            // visible stays on through the fade-out (flag || width > 0.5) so
            // the shrink is continuous and the Row keeps its spacing until the
            // glide finishes. No binding cycle: width depends only on the
            // reveal flags, visible only reads width.
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
                Brightness.setScreen(briSlider.value);
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
