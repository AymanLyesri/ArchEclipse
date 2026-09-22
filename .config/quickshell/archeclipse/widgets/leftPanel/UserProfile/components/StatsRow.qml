import QtQuick
import QtQuick.Controls
import qs.theme

// Favorites + pins side by side.
Row {
    id: root
    required property var store
    width: parent.width
    spacing: 10
    visible: !!store.profile
    Rectangle {
        width: (parent.width - 10) / 2
        implicitHeight: favCol.implicitHeight + 20
        color: Theme.bg
        radius: 8

        Column {
            id: favCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 5
            Label {
                text: "Booru Favorites"
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.fg
            }
            Repeater {
                model: store.booruApis
                delegate: Row {
                    width: parent.width
                    spacing: 5
                    Label {
                        width: parent.width - 32
                        text: modelData.name
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                        elide: Text.ElideRight
                    }
                    Label {
                        width: 27
                        horizontalAlignment: Text.AlignRight
                        text: store.profile ? String(store.booruFavoriteCounts[modelData.value] ?? 0) : ""
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                    }
                }
            }
        }
    }
    Rectangle {
        width: (parent.width - 10) / 2
        implicitHeight: pinCol.implicitHeight + 20
        color: Theme.bg
        radius: 8

        Column {
            id: pinCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 5
            Label {
                text: "Pinned Images"
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.fg
            }
            Label {
                width: parent.width
                text: "Fastfetch cache"
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fg
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: store.profile ? String(store.pinnedCount) : ""
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.accent
            }
        }
    }
}
