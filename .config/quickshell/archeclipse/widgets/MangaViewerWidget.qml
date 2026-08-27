import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Io

Item {
    id: root

    property string className: ""

    // Booru settings (reuse for manga source)
    property var api: qs.theme.Settings.booru.api
    property var tags: ["manga", "english"]
    property int limit: 20
    property int page: 1

    // Search state
    property string searchQuery: ""
    property var mangas: []
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
            'import Quickshell.Io; Process { command: ["curl", "-fsSL", "' + url + '"] }',
            root
        )
        proc.running = true
        proc.stdout = StdioCollector {
            onStreamFinished: {
                try {
                    root.mangas = JSON.parse(text)
                    root.loading = false
                } catch (e) {
                    console.error("Failed to parse manga results:", e)
                    root.loading = false
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Search bar
        Row {
            spacing: 10
            TextInput {
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
                onAccepted: root.search()
                placeholderText: "Search manga..."
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                Layout.fillWidth: true
                background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
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

        // Manga list
        Column {
            spacing: 10
            Repeater {
                model: root.mangas
                delegate: Rectangle {
                    width: parent.width
                    height: 120
                    radius: 8
                    color: qs.theme.Theme.color0
                    border.color: qs.theme.Theme.color8
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        spacing: 10
                        anchors.margins: 10

                        // Cover
                        Image {
                            width: 80
                            height: 100
                            fillMode: Image.PreserveAspectFit
                            source: modelData.preview
                            radius: 4
                        }

                        // Info
                        Column {
                            Layout.fillWidth: true
                            spacing: 4
                            verticalAlignment: AlignVCenter

                            Text {
                                text: modelData.tags.join(", ").slice(0, 50)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 12
                                font.bold: true
                                color: qs.theme.Theme.foreground
                                elide: Text.ElideRight
                                width: 250
                            }

                            Text {
                                text: "Rating: " + (modelData.rating ?? "unknown")
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 10
                                color: qs.theme.Theme.color8
                            }

                            Text {
                                text: modelData.width + "x" + modelData.height
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 10
                                color: qs.theme.Theme.color8
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Actions
                        Column {
                            spacing: 4
                            verticalAlignment: AlignVCenter
                            Button {
                                text: "Read"
                                onClicked: {
                                    if (modelData.id && root.api.idSearchUrl) {
                                        Qt.openUrlExternally(root.api.idSearchUrl + modelData.id)
                                    }
                                }
                                font.pixelSize: 10
                                background: Rectangle { color: qs.theme.Theme.accentBg; border.color: qs.theme.Theme.accent; border.width: 1; radius: 3 }
                                padding: 4
                            }
                            Button {
                                text: "Bookmark"
                                onClicked: {
                                    // Add to bookmarks
                                }
                                font.pixelSize: 10
                                background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 3 }
                                padding: 4
                            }
                        }
                    }
                }
            }
        }

        // Load more
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