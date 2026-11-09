import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared
import qs.services

// Filter controls: limit/columns/tags/cache. Lives in the shared navigation panel,
// rendered as titled cards so the panel reads with the Settings/KeyBinds rhythm.
Column {
    id: settingsCol
    property var viewer

    width: parent.width
    spacing: Theme.spacing

    Card {
        width: parent.width
        height: limitBody.implicitHeight + Theme.pad * 2

        Column {
            id: limitBody

            width: parent.width
            spacing: Theme.spacing

            Label {
                width: parent.width
                topPadding: Theme.pad / 2
                text: "Limit"
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.accent
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            AppSpinBox {
                id: limitSpin
                width: parent.width
                from: 0
                to: 100
                stepSize: 10
                value: viewer.limit
                onValueChanged: {
                    // Guard: creating the spinbox (or a settings reload) sets value from
                    // viewer.limit, so writing it back breaks the binding (limit stuck at 100).
                    const v = Math.round(limitSpin.value);
                    if (v === viewer.limit)
                        return;
                    viewer.limit = v;
                    Settings.booru.limit = viewer.limit;
                    Settings.updateSetting("booru.limit", viewer.limit);
                    // Changing the limit triggers fetchImages (debounced 300ms)
                    viewer._limitDebounce.restart();
                }
            }
        }
    }

    Card {
        width: parent.width
        height: columnsBody.implicitHeight + Theme.pad * 2

        Column {
            id: columnsBody

            width: parent.width
            spacing: Theme.spacing

            Label {
                width: parent.width
                topPadding: Theme.pad / 2
                text: "Columns"
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.accent
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            AppSpinBox {
                id: columnsSpin
                width: parent.width
                from: 1
                to: 5
                stepSize: 1
                value: viewer.columns
                onValueChanged: {
                    // Same binding guard as the limit spinbox above.
                    const v = Math.round(columnsSpin.value);
                    if (v === viewer.columns)
                        return;
                    viewer.columns = v;
                    Settings.booru.columns = viewer.columns;
                    Settings.updateSetting("booru.columns", viewer.columns);
                    // Columns only re-layout the loaded pages: the stack is untouched.
                }
            }
        }
    }

    Card {
        width: parent.width
        height: tagsBody.implicitHeight + Theme.pad * 2

        Column {
            id: tagsBody

            width: parent.width
            spacing: Theme.spacing

            Label {
                width: parent.width
                topPadding: Theme.pad / 2
                text: "Tags"
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.accent
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Tags flow
            Flow {
                spacing: Theme.spacing
                width: parent.width
                Repeater {
                    model: viewer.currentTags
                    delegate: AppButton {
                        readonly property bool isRating: modelData.match(/[-]rating:e|rating:e/) !== null
                        height: 22
                        cornerRadius: 4
                        pixelSize: Theme.fontSize - 2
                        idleBg: isRating ? Theme.surfaceActive : Theme.bg
                        idleFg: isRating ? Theme.accent : Theme.fg
                        hoverFg: isRating ? Theme.accent : Theme.fg
                        outlined: true
                        outlineColor: isRating ? Theme.accent : Theme.border
                        text: modelData
                        tooltipText: isRating ? "Toggle explicit filter" : "Remove tag"
                        onClicked: {
                            // Hoist: assigning currentTags destroys this delegate mid-click, after
                            // which `viewer` lookups throw and the refetch below never runs.
                            const v = viewer;
                            if (isRating) {
                                // Toggle -rating:e <-> rating:e, move to front, refetch
                                const newRating = modelData.startsWith("-") ? "rating:e" : "-rating:e";
                                let newTags = v.currentTags.filter(t => !t.match(/[-]rating:e|rating:e/));
                                newTags.unshift(newRating);
                                v.currentTags = newTags;
                                Settings.booru.tags = newTags;
                                Settings.updateSetting("booru.tags", newTags);
                            } else {
                                // Remove tag, refetch
                                const newTags = v.currentTags.filter(t => t !== modelData);
                                console.info("[Booru] chip remove:", modelData, "->", JSON.stringify(newTags));
                                v.currentTags = newTags;
                                Settings.booru.tags = newTags;
                                Settings.updateSetting("booru.tags", newTags);
                            }
                            // Refetch except in Bookmarks/Pins tabs
                            if (v.selectedTab !== "Bookmarks" && v.selectedTab !== "Pins") {
                                v.fetchImages();
                            }
                        }
                    }
                }
            }

            // Add tag entry + search
            AppTextField {
                id: tagEntry
                placeholderText: "Search tags..."
                font.pixelSize: Theme.fontSize - 2
                width: parent.width
                cornerRadius: 4
                onTextChanged: {
                    // Debounced tag fetch
                    if (text.length > 0) {
                        viewer.fetchTags(text);
                    }
                }
                Keys.onReturnPressed: {
                    if (text.trim()) {
                        const newTags = [...new Set([...viewer.currentTags, ...text.trim().split(" ")])];
                        viewer.currentTags = newTags;
                        Settings.booru.tags = newTags;
                        Settings.updateSetting("booru.tags", newTags);
                        tagEntry.text = "";
                        // Adding tags always refetches
                        if (viewer.selectedTab !== "Bookmarks" && viewer.selectedTab !== "Pins") {
                            viewer.fetchImages();
                        }
                    }
                }
            }

            AppButton {
                width: parent.width
                text: viewer.cacheSize
                tooltipText: "Clear cache"
                onClicked: viewer.cleanCache()
            }

            // Fetched tag suggestions
            Flow {
                spacing: Theme.spacing
                width: parent.width
                visible: viewer.fetchedTags.length > 0
                Repeater {
                    model: viewer.fetchedTags
                    delegate: AppButton {
                        text: modelData
                        tooltipText: "Add this tag to the search"
                        height: 20
                        pixelSize: Theme.fontSize - 3
                        onClicked: {
                            // Hoist (same delegate-destruction hazard as
                            // the tag chips above).
                            const v = viewer;
                            if (v.currentTags.includes(modelData)) {
                                return;
                            }
                            const newTags = [...v.currentTags, modelData];
                            v.currentTags = newTags;
                            Settings.booru.tags = newTags;
                            Settings.updateSetting("booru.tags", newTags);
                            // Fetched-tag click refetches (except local tabs)
                            if (v.selectedTab !== "Bookmarks" && v.selectedTab !== "Pins") {
                                v.fetchImages();
                            }
                        }
                    }
                }
            }
    }
}
}
