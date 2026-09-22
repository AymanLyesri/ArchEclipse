// Shared keybind chips — renders each entry of `keys` as a rounded chip
// rounded chip with a "+" separator between them. Used by CustomScripts and
// the app-launcher help/commands list so both stay visually identical.
import QtQuick
import QtQuick.Controls
import qs.theme

Row {
    id: root

    property var keys: []
    property int chipHeight: 22
    property int chipRadius: 4
    property int pixelSize: Theme.fontSizeSmall
    property color chipBg: Theme.surface
    property color chipFg: Theme.accent
    property color separatorColor: Theme.fgDim

    visible: keys.length > 0
    spacing: 3

    Repeater {
        model: root.keys
        delegate: Row {
            required property string modelData
            required property int index
            spacing: 3
            // Fixed height so the "+" label can center deterministically
            // (anchors are ignored inside positioners).
            height: root.chipHeight
            Rectangle {
                width: kChip.implicitWidth + 10
                height: root.chipHeight
                radius: root.chipRadius
                color: root.chipBg

                Label {
                    id: kChip
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: root.pixelSize
                    font.bold: true
                    color: root.chipFg
                    font.family: Theme.fontFamily
                }
            }
            Label {
                text: "+"
                y: (parent.height - height) / 2
                visible: index < (root.keys.length - 1)
                color: root.separatorColor
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
            }
        }
    }
}
