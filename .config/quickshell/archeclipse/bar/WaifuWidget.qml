import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Waifu widget ported from widgets/rightPanel/components/Waifu.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    Column {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            id: container
            width: parent.width
            color: Theme.moduleBg
            radius: 10
            border.width: 1
            border.color: Theme.border
            clip: true

            // Waifu content would go here - this is a placeholder
            Column {
                anchors.centerIn: parent
                spacing: 16
                Label {
                    text: "Waifu"
                    font.pixelSize: 24
                    color: Theme.fg
                }
                Label {
                    text: "Waifu widget"
                    color: Theme.fgDim
                }
                Button {
                    text: "Open Booru Viewer"
                    onClicked: {
                        // TODO: Open left panel with BooruViewer
                    }
                    background: Rectangle {
                        color: Theme.accentBg
                        radius: 4
                        border.width: 1
                        border.color: Theme.accent
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        color: Theme.accent
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
}