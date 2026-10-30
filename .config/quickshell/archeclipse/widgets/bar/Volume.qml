import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme
import qs.widgets.shared
import qs.services

// Icon + %, right-click opens pavucontrol, hover reveals the slider; also the transient
// "volume" pulse page. Tooltip "Volume: N%".
Rectangle {
    id: root

    property string monitorName: ""
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

    // Slider opens on direct interaction only (hover dwell, click, wheel) and auto-hides after
    // the reveal-out delay; the mount notification is skipped so launch never pops it open.
    property bool sliderRevealed: false
    property bool keepOpen: false
    property bool _firstVol: true
    // True while the reveal glide is in flight (width between stops): DefaultBar mirrors it
    // into rigidWidth so the bar edge tracks the slider instead of easing toward it.
    readonly property bool revealing: slider.width > 0.5 && slider.width < 99.5
    // Mount guard only: value changes never reveal the slider (keys/IPC/external are OSD-only);
    // direct wheel contact below reveals explicitly.
    onVolChanged: {
        if (root._firstVol)
            root._firstVol = false;
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
                    font.preferShaping: false
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
                    BarState.noteVolumeTarget(root.monitorName);
                    root.sink.audio.volume = Math.max(0, Math.min(1, root.vol + step));
                    // Direct contact with the widget reveals like hover/click; value changes moved
                    // to OSD-only, so keys and IPC never open it.
                    if (!root.pulse) {
                        root.sliderRevealed = true;
                        hideTimer.restart();
                    }
                }
            }
        }
        
        AppSlider {
            id: slider
            // Reveal on DefaultSpatial so edge and track move as one: width glides 0 <-> 100,
            // opacity fades with it, clip keeps the handle in; visible holds through the fade.
            visible: (root.pulse || root.sliderRevealed) || slider.width > 0.5
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
            from: 0
            to: 1
            stepSize: 0.01
            // Don't bind value directly: a direct `value: root.vol` binding
            // gets broken by the first manual drag, desyncing the slider.
            Component.onCompleted: slider.value = root.vol
            onMoved: if (root.sink?.audio) {
                BarState.noteVolumeTarget(root.monitorName);
                root.sink.audio.volume = slider.value;
            }
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
