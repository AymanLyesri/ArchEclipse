import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Io
import QtQuick.Controls

Item {
    id: root

    property string className: ""

    // Booru settings
    property var api: qs.theme.Settings.booru.api
    property var tags: qs.theme.Settings.booru.tags
    property int limit: qs.theme.Settings.booru.limit
    property int page: qs.theme.Settings.booru.page
    property int columns: qs.theme.Settings.booru.columns

    // Search state
    property string searchQuery: ""
    property var images: []
    property bool loading: false

    // Search
    function search() {
        root.loading = true
        root.page = 1

        const url = root.api.url + "posts.json?" +
            "tags=" + encodeURIComponent(root.tags.join(" ") + " " + root.searchQuery) +
            "&limit=" + root.limit +
            "&page=" + root.page

        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["curl", "-fsSL", "' + url + '"]; stdout: StdioCollector { onStreamFinished: { try { root.images = JSON.parse(text); root.loading = false } catch (e) { console.error("Failed to parse booru results:", e); root.loading = false } } } }',
            root
        )
        proc.running = true
    }

    function loadMore() {
        if (root.loading) return
        root.loading = true
        root.page++

        const url = root.api.url + "posts.json?" +
            "tags=" + encodeURIComponent(root.tags.join(" ") + " " + root.searchQuery) +
            "&limit=" + root.limit +
            "&page=" + root.page

        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["curl", "-fsSL", "' + url + '"]; stdout: StdioCollector { onStreamFinished: { try { const newImages = JSON.parse(text); root.images = [...root.images, ...newImages]; root.loading = false } catch (e) { console.error("Failed to parse booru results:", e); root.loading = false } } } }',
            root
        )
        proc.running = true
    }

    // Image grid
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Search bar
        Row {
            spacing: 10
            TextField {
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
                onAccepted: root.search()
                placeholderText: "Search tags..."
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                width: parent.width - 100
                padding: 8
            }
            Button {
                text: "Search"
                onClicked: root.search()
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                background: Rectangle { color: qs.theme.Theme.accentBg; border.color: qs.theme.Theme.accent; border.width: 1; radius: 4 }
                padding: 8
            }
        }

        // Image grid
        GridView {
            width: parent.width
            height: parent.height
            cellWidth: 200
            cellHeight: 200
            // columnSpacing: 8  // Not available in QtQuick 2.x GridView
            // rowSpacing: 8  // Not available in QtQuick 2.x GridView
            model: root.images

            delegate: Rectangle {
                width: 200
                height: 200
                radius: 8
                color: qs.theme.Theme.color0
                border.color: qs.theme.Theme.color8
                border.width: 1

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: modelData.preview
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (modelData.id && root.api.idSearchUrl) {
                            Qt.openUrlExternally(root.api.idSearchUrl + modelData.id)
                        }
                    }
                }

                // Load more when near end
                Component.onCompleted: {
                    if (index >= root.images.length - root.columns) {
                        root.loadMore()
                    }
                }
            }
        }

        // Loading indicator
        Rectangle {
            visible: root.loading
            width: parent.width
            height: 40
            radius: 4
            color: qs.theme.Theme.accentBg
            border.color: qs.theme.Theme.accent
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Loading..."
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                color: qs.theme.Theme.accent
            }
        }
    }
}