import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme

// Port of sub-components/Volume.tsx — icon + %, click opens pavucontrol,
// hover reveals slider. Also used as the transient "volume" pulse page.
Rectangle {
    id: root

    property bool pulse: false          // true when shown as a bar-state pulse
    readonly property int fixedWidth: 220

    width: pulse ? fixedWidth : content.width
    height: 22
    radius: Theme.radius
    color: pulse ? Theme.moduleBg : "transparent"

    // default sink via Pipewire service
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [sink] }

    readonly property real vol: {
        if (!sink?.audio) return 0;
        const v = sink.audio.volume;
        return isNaN(v) || v < 0 ? 0 : (v > 1 ? 1 : v);
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.vol <= 0 ? "\u{F055F}" : "\u{F058E}"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.vol * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Slider {
            id: slider
            visible: root.pulse || hover.hovered
            width: visible ? 100 : 0
            anchors.verticalCenter: parent.verticalCenter
            from: 0; to: 1; stepSize: 0.01
            value: root.vol
            onMoved: if (root.sink?.audio) root.sink.audio.volume = slider.value
        }
    }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: content
        acceptedButtons: Qt.LeftButton
        enabled: !root.pulse
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["pavucontrol"])
    }
}
