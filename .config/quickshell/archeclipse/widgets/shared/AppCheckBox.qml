import QtQuick
import QtQuick.Controls
import qs.theme

CheckBox {
    id: root

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: root.leftPadding
        y: parent.height / 2 - height / 2
        radius: 4
        color: root.checked ? Theme.accent : Theme.surface
        border.color: root.checked ? Theme.accent : Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "\u{F012C}" // or checkmark Nerd Font
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.bg
            visible: root.checked
        }
    }

    contentItem: Text {
        text: root.text
        font: root.font
        color: Theme.fg
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.indicator.width + root.spacing
    }
}
