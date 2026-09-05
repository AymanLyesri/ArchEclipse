import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared
import qs.services

// API / Bookmarks / Pins tabs (extracted verbatim from BooruViewerWidget).
// viewer: entry root (selectedTab, progressStatus, fetchImages...).
Row {
    property var viewer
    id: tabRow
    Layout.fillWidth: true
    spacing: 4
    width: parent.width

    Repeater {
        model: viewer.booruApis
        delegate: AppButton {
            id: apiTabBtn
            text: modelData.name
            width: (parent.width - 20) / 5  // 3 APIs + Bookmarks + Pins = 5 tabs
            height: 28
            toggle: true
            checked: viewer.selectedTab === modelData.name
            enabled: viewer.progressStatus !== "loading"
            pixelSize: Theme.fontSize - 2
            onClicked: {
                Settings.booru.api = modelData
                Settings.updateSetting("booru.api", modelData)
                viewer.selectedTab = modelData.name
                Settings.booru.selectedTab = modelData.name
                Settings.updateSetting("booru.selectedTab", modelData.name)
                viewer.page = 1
                Settings.booru.page = 1
                Settings.updateSetting("booru.page", 1)
                viewer.fetchImages()
            }
        }
    }

    // Bookmark tab (AGS label F02E)
    AppButton {
        id: bookmarkBtn
        text: "\u{F02E}"
        width: (parent.width - 20) / 5
        height: 28
        toggle: true
        checked: viewer.selectedTab === "Bookmarks"
        enabled: viewer.progressStatus !== "loading"
        pixelSize: Theme.fontSize - 2
        onClicked: {
            viewer.selectedTab = "Bookmarks"
            Settings.booru.selectedTab = "Bookmarks"
            Settings.updateSetting("booru.selectedTab", "Bookmarks")
            viewer.page = 1
            Settings.booru.page = 1
            Settings.updateSetting("booru.page", 1)
            // Load bookmarks (AGS: paginate + download previews)
            viewer.loadBookmarks()
        }
    }

    // Pins tab (AGS label F435)
    AppButton {
        id: pinsBtn
        text: "\u{F435}"
        width: (parent.width - 20) / 5
        height: 28
        toggle: true
        checked: viewer.selectedTab === "Pins"
        enabled: viewer.progressStatus !== "loading"
        pixelSize: Theme.fontSize - 2
        onClicked: {
            viewer.selectedTab = "Pins"
            Settings.booru.selectedTab = "Pins"
            Settings.updateSetting("booru.selectedTab", "Pins")
            viewer.page = 1
            Settings.booru.page = 1
            Settings.updateSetting("booru.page", 1)
            // Load pins (AGS: paginate + download previews)
            viewer.loadPins()
        }
    }
}
