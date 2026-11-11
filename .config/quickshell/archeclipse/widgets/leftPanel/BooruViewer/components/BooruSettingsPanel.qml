import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared
import qs.services

// Filter controls: limit, columns, tags, cache. No card chrome — each section is a
// small caps header over flat rows; the parent spacing alone separates the sections.
Column {
    id: settingsCol
    property var viewer

    width: parent.width
    // Gap BETWEEN sections only — rows inside a section use Theme.spacing.
    spacing: Theme.pad

    Column {
        id: displaySection
        width: parent.width
        spacing: Theme.spacing

        Label {
            width: parent.width
            text: "Display".toUpperCase()
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            color: Theme.accent
        }

        // Rows take explicit width from the section column (children deriving it would loop back).
        Row {
            width: parent.width
            spacing: Theme.spacing

            Label {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                text: "Limit"
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }

            AppSpinBox {
                id: limitSpin
                width: parent.width - 44 - Theme.spacing
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

        Row {
            width: parent.width
            spacing: Theme.spacing

            Label {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                text: "Columns"
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }

            AppSpinBox {
                id: columnsSpin
                width: parent.width - 44 - Theme.spacing
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

    Column {
        id: tagsSection
        width: parent.width
        spacing: Theme.spacing

        Label {
            width: parent.width
            text: "Tags".toUpperCase()
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            color: Theme.accent
        }

        // Tags flow — removable pills; rating tags stay active, others are removable.
        Flow {
            spacing: Theme.spacing
            width: parent.width
            Repeater {
                model: viewer.currentTags
                delegate: AppPill {
                    // Match standard ratings plus the empty-string sentinel.
                    readonly property bool isRating: modelData.match(/[-+]rating:e|rating:e/) !== null || modelData === ""
                    // Keep the stored sign visible (-/+/none) so the filter state reads at a glance.
                    readonly property string display: modelData === "" ? "rating:e" : modelData
                    text: display
                    // Empty-sentinel renders with strikethrough; nothing else does.
                    strike: modelData === ""
                    tooltipText: modelData === "" ? "Click to activate filter"
                              : isRating        ? "Click to cycle"
                                                 : "Remove tag"
                    // Rating-e is never removed from the search: click only cycles its state.
                    enabled: true
                    onClicked: {
                        const v = viewer;
                        if (!isRating) {
                            // Non-rating: remove entirely.
                            const newTags = v.currentTags.filter(t => t !== modelData);
                            console.info("[Booru] chip remove:", modelData, "->", JSON.stringify(newTags));
                            v.currentTags = newTags;
                            Settings.booru.tags = newTags;
                            Settings.updateSetting("booru.tags", newTags);
                        } else {
                            // Three-state cycle: -rating:e -> +rating:e -> off (struck) -> -rating:e
                            const next = modelData === "-rating:e" ? "+rating:e"
                                       : modelData === "+rating:e" ? ""
                                                                  : "-rating:e";
                            let newTags = v.currentTags.filter(t => t !== "" && !t.match(/[-+]rating:e|rating:e/));
                            newTags.unshift(next);
                            v.currentTags = newTags;
                            Settings.booru.tags = newTags;
                            Settings.updateSetting("booru.tags", newTags);
                        }
                        if (v.selectedTab !== "Bookmarks" && v.selectedTab !== "Pins")
                            v.fetchImages();
                    }
                    onRemoved: onClicked();
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
                    const raw = text.trim().split(" ").map(t => t.trim()).filter(Boolean);
                    const newTags = [...new Set([...viewer.currentTags, ...raw])];
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
                delegate: AppPill {
                    text: modelData
                    tooltipText: "Add this tag to the search"
                    active: viewer.currentTags.indexOf(modelData) >= 0
                    onClicked: {
                        const trimmed = String(modelData).trim();
                        if (!trimmed)
                            return;
                        const v = viewer;
                        if (v.currentTags.indexOf(trimmed) >= 0)
                            return;
                        const newTags = [...v.currentTags, trimmed];
                        v.currentTags = newTags;
                        Settings.booru.tags = newTags;
                        Settings.updateSetting("booru.tags", newTags);
                        if (v.selectedTab !== "Bookmarks" && v.selectedTab !== "Pins")
                            v.fetchImages();
                    }
                }
            }
        }
    }
}
