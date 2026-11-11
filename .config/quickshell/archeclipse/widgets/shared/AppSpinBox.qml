import QtQuick
import QtQuick.Controls
import qs.theme

// Shared numeric stepper: one recessed pill holding the value and two icon steppers, so the
// control reads as a single object instead of three outlined boxes.
SpinBox {
    id: root
    editable: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    implicitHeight: Math.max(30, Theme.fontSize + 18)

    contentItem: TextInput {
        z: 2
        text: root.textFromValue(root.value, root.locale)
        font: root.font
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.bg
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !root.editable
        validator: root.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    background: Rectangle {
        implicitWidth: 120
        color: Theme.surfaceRaised
        radius: Theme.radius
    }

    up.indicator: Rectangle {
        x: parent.width - width
        y: 3
        height: parent.height / 2 - 4
        width: 24
        radius: Theme.radius
        color: root.up.pressed ? Theme.surfaceOverlay : (root.up.hovered ? Theme.surfaceHover : "transparent")

        Behavior on color {
            CAnim {}
        }
        Text {
            text: Icons.plus
            color: Theme.muted
            anchors.centerIn: parent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeCaption
        }
    }

    down.indicator: Rectangle {
        x: parent.width - width
        y: parent.height / 2 + 1
        height: parent.height / 2 - 4
        width: 24
        radius: Theme.radius
        color: root.down.pressed ? Theme.surfaceOverlay : (root.down.hovered ? Theme.surfaceHover : "transparent")

        Behavior on color {
            CAnim {}
        }
        Text {
            text: Icons.minus
            color: Theme.muted
            anchors.centerIn: parent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeCaption
        }
    }
}
