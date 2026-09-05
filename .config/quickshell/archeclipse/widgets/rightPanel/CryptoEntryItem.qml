import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar

// Crypto entry item — combines CryptoItem (price/graph) with entry management
// (bookmark/pin, edit, delete). Port of CryptoViewer.tsx CryptoEntryItem.
Item {
    id: root
    property var entry: {}
    signal deleteClicked(string id)
    signal editClicked(var entry)
    property bool isHovered: false

    Column {
        anchors.fill: parent
        spacing: 6

        // Crypto price/graph display
        Rectangle {
            id: entryRect
            width: parent.width
            height: 80
            color: Theme.moduleBg
            radius: Theme.radius
            border.width: 1
            border.color: Theme.border

            CryptoItem {
                anchors.fill: parent
                anchors.margins: 8
                entry: root.entry
                itemWidth: parent.width
            }
        }

        // Hover actions row
        Row {
            spacing: 4
            visible: root.isHovered
            anchors.right: parent.right

            Button {
                text: "\u{f091}"  // pin
                width: 28; height: 24
                ToolTip.visible: hovered; ToolTip.delay: 500
                ToolTip.text: "Pin to bar"
                onClicked: {
                    Settings.cryptoFavorite = { symbol: root.entry.symbol, timeframe: root.entry.timeframe }
                    Settings.updateSetting("crypto.favorite", Settings.cryptoFavorite)
                    Quickshell.execDetached(["notify-send", "Crypto Display", (root.entry.symbol || "").toUpperCase() + " pinned to top bar"])
                }
                background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                contentItem: Text { color: Theme.accent; font.pixelSize: 11; anchors.centerIn: parent }
            }

            Button {
                text: "\u{f044}"  // edit/pencil (using Nerd Font icon)
                width: 28; height: 24
                ToolTip.visible: hovered; ToolTip.delay: 500
                ToolTip.text: "Edit"
                onClicked: root.editClicked(root.entry)
                background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                contentItem: Text { color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
            }

            Button {
                text: "\u{f00d}"  // x
                width: 28; height: 24
                ToolTip.visible: hovered; ToolTip.delay: 500
                ToolTip.text: "Delete"
                onClicked: root.deleteClicked(root.entry.id)
                background: Rectangle { color: Theme.dangerBg; radius: 4; border.color: Theme.danger }
                contentItem: Text { color: Theme.danger; font.pixelSize: 11; anchors.centerIn: parent }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.isHovered = true
            onExited: root.isHovered = false
        }
    }
}
