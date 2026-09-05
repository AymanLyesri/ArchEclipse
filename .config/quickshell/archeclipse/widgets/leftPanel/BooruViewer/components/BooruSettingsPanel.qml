import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared
import qs.services

// Revealable settings: limit/columns/tags/cache (extracted verbatim).
// viewer: entry root (limit, columns, tags, fetchTags...).
// NOTE: original `width: tagText2.implicitWidth` referenced a missing id
// (runtime error when suggestions show); binding dropped, AppButton
// sizes to content.
    Rectangle {
    property var viewer
        id: settingsReveal
        width: parent.width
        height: bottomRevealed ? settingsCol.implicitHeight + 16 : 0
        color: "transparent"
        clip: true
        border.width: 0

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

        Column {
            id: settingsCol
            spacing: 8
            width: parent.width
            anchors.margins: 8

            // Limit slider
            Row {
                spacing: 8
                width: parent.width
                Text { text: "Limit: " + viewer.limit; color: Theme.fg; font.pixelSize: Theme.fontSize - 2 }
                Slider {
                    id: limitSlider
                    from: 0; to: 100; stepSize: 10
                    value: viewer.limit
                    Layout.fillWidth: true
                    onValueChanged: {
                        viewer.limit = Math.round(limitSlider.value)
                        Settings.booru.limit = viewer.limit
                        Settings.updateSetting("booru.limit", viewer.limit)
                        // AGS LimitDisplay setValue triggers fetchImages (debounced 300ms)
                        viewer._limitDebounce.restart()
                    }
                }
            }

            // Columns slider
            Row {
                spacing: 8
                width: parent.width
                Text { text: "Columns: " + viewer.columns; color: Theme.fg; font.pixelSize: Theme.fontSize - 2 }
                Slider {
                    id: columnsSlider
                    from: 1; to: 5; stepSize: 1
                    value: viewer.columns
                    Layout.fillWidth: true
                    onValueChanged: {
                        viewer.columns = Math.round(columnsSlider.value)
                        Settings.booru.columns = viewer.columns
                        Settings.updateSetting("booru.columns", viewer.columns)
                        // AGS ColumnDisplay setValue triggers fetchImages (debounced 300ms)
                        viewer._limitDebounce.restart()
                    }
                }
            }

            // Tags
            Column {
                spacing: 4
                width: parent.width

                // Tags flow (AGS TagDisplay)
                Flow {
                    spacing: 4
                    width: parent.width
                    Repeater {
                        model: viewer.currentTags
                        delegate: Rectangle {
                            readonly property bool isRating: modelData.match(/[-]rating:explicit|rating:explicit/) !== null
                            width: tagText.implicitWidth + 16
                            height: 22
                            color: isRating ? Theme.accentBg : Theme.bg
                            radius: 4
                            border.color: isRating ? Theme.accent : Theme.border
                            border.width: 1
                            Text {
                                id: tagText
                                anchors.centerIn: parent
                                text: modelData
                                color: isRating ? Theme.accent : Theme.fg
                                font.pixelSize: Theme.fontSize - 2
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (isRating) {
                                        // AGS: toggle -rating:explicit <-> rating:explicit, move to front, refetch
                                        const newRating = modelData.startsWith("-")
                                            ? "rating:explicit" : "-rating:explicit"
                                        let newTags = viewer.currentTags.filter(t => !t.match(/[-]rating:explicit|rating:explicit/))
                                        newTags.unshift(newRating)
                                        viewer.currentTags = newTags
                                        Settings.booru.tags = newTags
                                        Settings.updateSetting("booru.tags", newTags)
                                    } else {
                                        // AGS: remove tag, refetch
                                        const newTags = viewer.currentTags.filter(t => t !== modelData)
                                        viewer.currentTags = newTags
                                        Settings.booru.tags = newTags
                                        Settings.updateSetting("booru.tags", newTags)
                                    }
                                    // AGS refetches except in Bookmarks/Pins tabs
                                    if (viewer.selectedTab !== "Bookmarks" && viewer.selectedTab !== "Pins") {
                                        viewer.fetchImages()
                                    }
                                }
                            }
                        }
                    }
                }

                // Add tag entry + search
                Row {
                    spacing: 4
                    width: parent.width
                    TextField {
                        id: tagEntry
                        placeholderText: "Search tags..."
                        font.pixelSize: Theme.fontSize - 2
                        width: parent.width - 60
                        background: Rectangle { color: Theme.bg; radius: 4; border.color: Theme.border }
                        onTextChanged: {
                            // Debounced tag fetch
                            if (text.length > 0) {
                                viewer.fetchTags(text)
                            }
                        }
                        Keys.onReturnPressed: {
                            if (text.trim()) {
                                const newTags = [...new Set([...viewer.currentTags, ...text.trim().split(" ")])]
                                viewer.currentTags = newTags
                                Settings.booru.tags = newTags
                                Settings.updateSetting("booru.tags", newTags)
                                tagEntry.text = ""
                            }
                        }
                    }
                    AppButton {
                        text: viewer.cacheSize
                        width: 50; height: 24
                        tooltipText: "Clear cache"
                        onClicked: viewer.cleanCache()
                    }
                }

                // Fetched tag suggestions
                Flow {
                    spacing: 4
                    width: parent.width
                    visible: viewer.fetchedTags.length > 0
                    Repeater {
                        model: viewer.fetchedTags
                        delegate: AppButton {
                            text: modelData
                            height: 20
                            pixelSize: Theme.fontSize - 3
                            onClicked: {
                                const newTags = [...new Set([...viewer.currentTags, modelData])]
                                viewer.currentTags = newTags
                                Settings.booru.tags = newTags
                                Settings.updateSetting("booru.tags", newTags)
                                viewer.fetchedTags = []
                            }
                        }
                    }
                }
            }
        }
    }
