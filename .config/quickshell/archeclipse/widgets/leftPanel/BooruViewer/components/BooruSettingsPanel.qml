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
    id: settingsReveal
    property var viewer
    width: parent.width
    height: bottomRevealed ? settingsCol.implicitHeight + 16 : 0
    color: "transparent"
    clip: true
    border.width: 0

    Behavior on height {
        NumberAnimation {
            duration: Theme.anim.small
            easing.type: Easing.InOutQuad
        }
    }

    Column {
        id: settingsCol
        spacing: Theme.spacing
        width: parent.width
        anchors.margins: Theme.pad

        // Limit slider
        Row {
            spacing: Theme.spacing
            width: parent.width
            Text {
                text: "Limit: " + viewer.limit
                color: Theme.fg
                font.pixelSize: Theme.fontSize - 2
            }
            AppSlider {
                id: limitSlider
                from: 0
                to: 100
                stepSize: 10
                value: viewer.limit
                Layout.fillWidth: true
                onValueChanged: {
                    // Guard: creating the slider (or a settings reload)
                    // sets value from viewer.limit — writing it back
                    // unconditionally would break the Settings binding
                    // (seen: limit stuck at 100 after restart).
                    const v = Math.round(limitSlider.value);
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

        // Columns slider
        Row {
            spacing: Theme.spacing
            width: parent.width
            Text {
                text: "Columns: " + viewer.columns
                color: Theme.fg
                font.pixelSize: Theme.fontSize - 2
            }
            AppSlider {
                id: columnsSlider
                from: 1
                to: 5
                stepSize: 1
                value: viewer.columns
                Layout.fillWidth: true
                onValueChanged: {
                    // Same binding guard as the limit slider above.
                    const v = Math.round(columnsSlider.value);
                    if (v === viewer.columns)
                        return;
                    viewer.columns = v;
                    Settings.booru.columns = viewer.columns;
                    Settings.updateSetting("booru.columns", viewer.columns);
                    // Changing the column count triggers fetchImages (debounced 300ms)
                    viewer._limitDebounce.restart();
                }
            }
        }

        // Tags
        Column {
            spacing: Theme.spacing
            width: parent.width

            // Tags flow
            Flow {
                spacing: Theme.spacing
                width: parent.width
                Repeater {
                    model: viewer.currentTags
                    delegate: AppButton {
                        readonly property bool isRating: modelData.match(/[-]rating:explicit|rating:explicit/) !== null
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
                            // Hoist: assigning currentTags rebuilds this
                            // Repeater and destroys the delegate
                            // mid-click, after which bare `viewer`
                            // lookups throw (ReferenceError) and the
                            // refetch below never runs.
                            const v = viewer;
                            if (isRating) {
                                // Toggle -rating:explicit <-> rating:explicit, move to front, refetch
                                const newRating = modelData.startsWith("-") ? "rating:explicit" : "-rating:explicit";
                                let newTags = v.currentTags.filter(t => !t.match(/[-]rating:explicit|rating:explicit/));
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
            Row {
                spacing: Theme.spacing
                width: parent.width
                AppTextField {
                    id: tagEntry
                    placeholderText: "Search tags..."
                    font.pixelSize: Theme.fontSize - 2
                    width: parent.width - 60
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
                    text: viewer.cacheSize
                    width: 50
                    height: 24
                    tooltipText: "Clear cache"
                    onClicked: viewer.cleanCache()
                }
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
