import QtQuick
import QtQuick.Controls
import qs.theme

SpinBox {
    id: root
    editable: true

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
        implicitHeight: 28
        color: Theme.surface
        border.color: root.activeFocus ? Theme.accent : Theme.border
        border.width: 1
        radius: 6
    }

    up.indicator: Rectangle {
        x: parent.width - width
        height: parent.height / 2
        width: 24
        color: root.up.pressed ? Theme.surfaceActive : "transparent"
        border.color: Theme.border
        border.width: 1
        radius: 4
        Text {
            text: "+"
            color: Theme.fg
            anchors.centerIn: parent
            font.bold: true
        }
    }

    down.indicator: Rectangle {
        x: parent.width - width
        y: parent.height / 2
        height: parent.height / 2
        width: 24
        color: root.down.pressed ? Theme.surfaceActive : "transparent"
        border.color: Theme.border
        border.width: 1
        radius: 4
        Text {
            text: "-"
            color: Theme.fg
            anchors.centerIn: parent
            font.bold: true
        }
    }
}
