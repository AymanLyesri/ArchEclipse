import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.theme

// Port of sub-components/BrightnessWidget.tsx (brightnessctl backend, same as
// services/brightness.ts). Reproduces the AGS behaviors:
//  - icon threshold ( >0.75 󰃠 / >0.5 󰃟 / else 󰃞 )
//  - percent label
//  - change-triggered slider reveal (swing-left) with 2s auto-hide
//    (hover keeps it open; resumes 2s countdown on leave)
//  - "Brightness: N%" tooltip
//  - only visible when a backlight is present (hasBacklight)
Rectangle {
    id: root

    property real level: 1.0
    property bool pulse: false
    readonly property int fixedWidth: 220

    // AGS: visible only when hasBacklight (no /sys/class/backlight/* → hidden)
    readonly property bool hasBacklight: {
        try {
            return backlightCheck.outputLines.length > 0
        } catch (e) { return true }
    }
    Process {
        id: backlightCheck
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {}
    }

    width: pulse ? fixedWidth : content.width
    height: 22
    radius: Theme.radius
    color: pulse ? Theme.moduleBg : "transparent"
    visible: root.hasBacklight

    // tooltip (AGS tooltipText "Brightness: N%")
    ToolTip.visible: briHover.hovered
    ToolTip.text: "Brightness: " + Math.round(root.level * 100) + "%"
    ToolTip.delay: 400

    Process {
        id: getBri
        command: ["sh", "-c", "brightnessctl -m info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.split(",");
                if (m.length > 3) {
                    const newLevel = parseFloat(m[3].replace('%','')) / 100;
                    if (Math.abs(newLevel - root.level) > 0.005) {
                        root.level = newLevel;
                        // AGS: reveal slider on external change, then auto-hide after 2s
                        root.showSliderTemp();
                    }
                }
            }
        }
    }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: getBri.running = true }

    // AGS change → reveal + 2s hide timeout
    property bool sliderRevealed: false
    property bool keepOpen: false
    function showSliderTemp() {
        root.sliderRevealed = true
        hideTimer.restart()
    }
    function hideSlider() {
        if (!root.keepOpen) root.sliderRevealed = false
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
            text: root.level > 0.75 ? "\u{F00E0}" : root.level > 0.5 ? "\u{F00DF}" : "\u{F00DE}"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.level * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Slider {
            id: briSlider
            visible: root.pulse || root.sliderRevealed || briHover.hovered
            width: visible ? 100 : 0
            anchors.verticalCenter: parent.verticalCenter
            from: 0.01; to: 1; stepSize: 0.01
            value: root.level
            onMoved: {
                root.level = briSlider.value;
                Quickshell.execDetached(["brightnessctl", "set", Math.round(briSlider.value * 100) + "%"]);
            }
        }
    }

    // AGS EventControllerMotion: hover keeps reveal open, cancel+restart 2s on leave
    HoverHandler {
        id: briHover
        onHoveredChanged: {
            if (briHover.hovered) {
                root.keepOpen = true
                root.sliderRevealed = true
                hideTimer.stop()
            } else {
                root.keepOpen = false
                hideTimer.restart()
            }
        }
    }
}
