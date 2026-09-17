import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme
import qs.widgets.shared
import qs.services

// Port of sub-components/Volume.tsx — icon + %, right-click opens pavucontrol,
// hover reveals slider. Also used as the transient "volume" pulse page.
// icon, %, change-triggered reveal w/ 2s auto-hide,
// "Volume: N%" tooltip, right-click → pavucontrol.
Rectangle {
    id: root

    property bool pulse: false          // true when shown as a bar-state pulse
    readonly property int fixedWidth: 220

    width: pulse ? fixedWidth : content.width
    height: Theme.barContentHeight
    radius: Theme.radius
    color: pulse ? Theme.surface : "transparent"

    // default sink via Pipewire service
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: [sink]
    }

    readonly property real vol: {
        if (!sink?.audio)
            return 0;
        const v = sink.audio.volume;
        return isNaN(v) || v < 0 ? 0 : (v > 1 ? 1 : v);
    }

    // Reveal slider on volume change, auto-hide after the reveal-out
    // delay (hover keeps open).
    // Skip the mount notification — first vol evaluation must
    // not pop the slider open at launch.
    property bool sliderRevealed: false
    property bool keepOpen: false
    property bool _firstVol: true
    onVolChanged: {
        if (root._firstVol) {
            root._firstVol = false;
            return;
        }
        if (!root.pulse) {
            root.sliderRevealed = true;
            hideTimer.restart();
        }
    }
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

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: labelRow.width
            height: labelRow.height

            Row {
                id: labelRow
                spacing: Theme.spacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: VolumeWatcher.volumeIcon
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.vol * 100) + "%"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                enabled: !root.pulse
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        Quickshell.execDetached(["pavucontrol"]);
                    } else if (mouse.button === Qt.LeftButton) {
                        root.sliderRevealed = !root.sliderRevealed;
                        if (root.sliderRevealed)
                            hideTimer.restart();
                    }
                }
                onWheel: wheel => {
                    if (!root.sink?.audio)
                        return;
                    const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    root.sink.audio.volume = Math.max(0, Math.min(1, root.vol + step));
                }
            }
        }
        
        AppSlider {
            id: slider
            visible: root.pulse || root.sliderRevealed
            width: visible ? 100 : 0
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: 1
            stepSize: 0.01
            // Don't bind value directly: a direct `value: root.vol` binding
            // gets broken by the first manual drag, desyncing the slider.
            Component.onCompleted: slider.value = root.vol
            onMoved: if (root.sink?.audio)
                root.sink.audio.volume = slider.value
        }
        Binding {
            target: slider
            property: "value"
            value: root.vol
            when: !slider.pressed
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
    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hover.hovered) {
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
