import Quickshell
import QtQuick
import qs.theme

Item {
    id: root

    property string className: ""

    // Waifu data from settings
    property var waifu: qs.theme.Settings.waifuWidget.current

    // Placeholder with Booru link
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        verticalAlignment: AlignVCenter

        Image {
            id: waifuImage
            width: 200
            height: 200
            fillMode: Image.PreserveAspectFit
            source: root.waifu?.preview ?? ""
            visible: !!root.waifu?.preview
        }

        Text {
            visible: !root.waifu?.preview
            text: "No waifu selected"
            font.family: "JetBrainsMono NFP"
            font.pixelSize: 14
            color: qs.theme.Theme.color8
        }

        Row {
            spacing: 10
            Button {
                text: "Open in Booru"
                onClicked: {
                    if (root.waifu?.api?.idSearchUrl && root.waifu?.id) {
                        Qt.openUrlExternally(root.waifu.api.idSearchUrl + root.waifu.id)
                    }
                }
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                background: Rectangle { color: qs.theme.Theme.accentBg; border.color: qs.theme.Theme.accent; border.width: 1; radius: 4 }
                padding: 8
            }

            Button {
                text: "Search Waifus"
                onClicked: {
                    const leftPanel = Quickshell.Window.byName("left-panel-" + Quickshell.Window.current?.monitorName)
                    if (leftPanel) {
                        // Switch to BooruViewer widget
                        qs.theme.Settings.updateSetting("leftPanel.widget", { name: "BooruViewer", icon: "", enabled: true })
                        leftPanel.visible = true
                    }
                }
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                padding: 8
            }
        }
    }
}