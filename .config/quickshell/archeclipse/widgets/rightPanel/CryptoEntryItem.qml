import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.shared

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

            AppButton {
                icon: "\u{F091}"
                width: 28; height: 24
                pixelSize: 11
                cornerRadius: 4
                idleBg: Theme.moduleBg
                idleFg: Theme.accent
                outlined: true
                tooltipText: "Pin to bar"
                onClicked: {
                    Settings.cryptoFavorite = { symbol: root.entry.symbol, timeframe: root.entry.timeframe }
                    Settings.updateSetting("crypto.favorite", Settings.cryptoFavorite)
                    Quickshell.execDetached(["notify-send", "Crypto Display", (root.entry.symbol || "").toUpperCase() + " pinned to top bar"])
                }
            }

            AppButton {
                icon: "\u{F044}"
                width: 28; height: 24
                pixelSize: 11
                cornerRadius: 4
                idleBg: Theme.moduleBg
                outlined: true
                tooltipText: "Edit"
                onClicked: root.editClicked(root.entry)
            }

            AppButton {
                icon: "\u{F00D}"
                width: 28; height: 24
                pixelSize: 11
                cornerRadius: 4
                idleBg: Theme.dangerBg
                idleFg: Theme.danger
                outlined: true
                outlineColor: Theme.danger
                tooltipText: "Delete"
                onClicked: root.deleteClicked(root.entry.id)
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
