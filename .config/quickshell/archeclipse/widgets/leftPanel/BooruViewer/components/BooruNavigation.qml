import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme
import qs.widgets.shared

// Bottom bar: tabs + progress + page buttons + prev/reveal/next (BooruToolbar merged in, so
// the viewer only instantiates this and the settings panel). viewer: entry root.
Column {
    property var viewer

    Layout.fillWidth: true
    width: parent.width
    spacing: Theme.spacing

    // Tab values mirror viewer.selectedTab: API names + Bookmarks + Pins.
    readonly property var tabValues: viewer ? viewer.booruApis.map(a => a.name).concat(["Bookmarks", "Pins"]) : []

    // Shared tab-switch plumbing (page reset); the per-tab load call differs.
    function resetPage() {
        viewer.page = 1;
        Settings.booru.page = 1;
        Settings.updateSetting("booru.page", 1);
    }
    function activateTab(v) {
        if (v === "Bookmarks") {
            viewer.selectedTab = "Bookmarks";
            Settings.booru.selectedTab = "Bookmarks";
            Settings.updateSetting("booru.selectedTab", "Bookmarks");
            resetPage();
            // Load bookmarks (paginate + download previews)
            viewer.loadBookmarks();
        } else if (v === "Pins") {
            viewer.selectedTab = "Pins";
            Settings.booru.selectedTab = "Pins";
            Settings.updateSetting("booru.selectedTab", "Pins");
            resetPage();
            // Load pins (paginate + download previews)
            viewer.loadPins();
        } else {
            const api = viewer.booruApis.find(a => a.name === v) || viewer.booruApis[0];
            Settings.booru.api = api;
            Settings.updateSetting("booru.api", api);
            viewer.selectedTab = api.name;
            Settings.booru.selectedTab = api.name;
            Settings.updateSetting("booru.selectedTab", api.name);
            resetPage();
            viewer.fetchImages();
        }
    }

    // Progress pill at the very bottom (ChatBot parity: full-width pill,
    // visible on loading/error only, default Working... / Error texts).
    AppProgress {
        width: parent.width
        // Plain Column ignores implicitHeight — bind it explicitly.
        height: implicitHeight
        status: viewer.progressStatus
        variant: "pill"
    }

    Row {
        id: pageBar

        spacing: Theme.spacing
        anchors.horizontalCenter: parent.horizontalCenter

        // Windowed page buttons as a sliding segment ("..." is a disabled cell). viewer.page and
        // widgetWidth are read directly — inside buildPageButtons() the highlight stuck.
        AppSegmentedControl {
            enabled: viewer.progressStatus !== "loading"
            pixelSize: Theme.fontSize - 2
            model: {
                if (!viewer)
                    return [];
                viewer.page;
                viewer.widgetWidth;
                return viewer.buildPageButtons().map(b => ({
                            value: b.page,
                            label: b.label,
                            enabled: b.page > 0
                        }));
            }
            currentIndex: {
                if (!viewer)
                    return -1;
                viewer.page;
                viewer.widgetWidth;
                return viewer.buildPageButtons().findIndex(b => b.active);
            }
            onActivated: (i, v) => viewer.gotoPage(v)
        }
    }

    // API / Bookmarks / Pins tabs (was BooruToolbar).
    Row {
        id: tabBar

        spacing: Theme.spacing
        anchors.horizontalCenter: parent.horizontalCenter

        AppSegmentedControl {
            enabled: viewer && viewer.progressStatus !== "loading"
            pixelSize: Theme.fontSize - 2
            model: viewer ? viewer.booruApis.map(a => ({
                        value: a.name,
                        label: a.name
                    })).concat([
                {
                    value: "Bookmarks",
                    label: "\u{F02E}",
                    tooltip: "Bookmarks"
                },
                {
                    value: "Pins",
                    label: "\u{F435}",
                    tooltip: "Pins"
                }
            ]) : []
            currentIndex: tabValues.indexOf(viewer ? viewer.selectedTab : "")
            onActivated: (i, v) => activateTab(v)
        }
    }

    // Revealer trigger: prev / expand-to-fill toggle / next; the middle chevron claims all
    // leftover width so the whole bar is an easy target.
    Row {
        id: triggerRow

        spacing: Theme.spacing
        width: parent.width
        height: 28

        AppButton {
            text: "\u{F053}" // chevron left (prev)
            tooltipText: "Previous page"
            width: 32
            height: 28
            enabled: viewer.progressStatus !== "loading"
            onClicked: {
                if (viewer.page > 1) {
                    viewer.gotoPage(viewer.page - 1);
                }
            }
        }

        AppButton {
            text: viewer.bottomRevealed ? "\uf107" : "\uf106" // down/up chevron
            width: Math.max(0, parent.width - 32 - 32 - parent.spacing * 2)
            height: 28
            tooltipText: viewer.bottomRevealed ? "Hide settings" : "Show settings"
            onClicked: viewer.bottomRevealed = !viewer.bottomRevealed
        }

        AppButton {
            text: "\u{F054}" // chevron right (next)
            tooltipText: "Next page"
            width: 32
            height: 28
            enabled: viewer.progressStatus !== "loading"
            onClicked: {
                viewer.gotoPage(viewer.page + 1);
            }
        }
    }
}
