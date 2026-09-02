import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

// Waifu widget ported from widgets/rightPanel/components/Waifu.tsx
// Shows the current waifu image or a placeholder with a link to open
// the BooruViewer in the left panel.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    readonly property string booruPath: `${Quickshell.env("HOME")}/.config/ags/cache/booru`
    readonly property string booruScript: `${Quickshell.env("HOME")}/.config/ags/scripts/booru.py`

    // Current waifu data from Settings — mirrors globalSettings.waifuWidget.current
    readonly property var waifuDataObj: Settings.waifu || null

    // Safe accessors (return null/empty when no waifu)
    readonly property var wd: root.waifuDataObj
    readonly property int wd_id: root.wd ? (root.wd.id || 0) : 0
    readonly property string wd_apiValue: root.wd && root.wd.api ? root.wd.api.value : "danbooru"
    readonly property string wd_extension: root.wd ? (root.wd.extension || "") : ""
    readonly property var wd_tags: root.wd ? (root.wd.tags || []) : []
    readonly property int wd_width: root.wd ? (root.wd.width || 0) : 0
    readonly property int wd_height: root.wd ? (root.wd.height || 0) : 0

    readonly property bool hasWaifu: root.wd_id > 0
    readonly property string imagePath: root.hasWaifu
        ? `${root.booruPath}/${root.wd_apiValue}/images/${root.wd_id}.${root.wd_extension || "jpg"}`
        : ""
    readonly property bool isVideo: ["mp4", "webm", "mkv", "gif", "zip"].includes(root.wd_extension.toLowerCase())

    // Loading state for fetch-by-ID
    property string loadingState: "idle"   // "loading" | "error" | "success" | "idle"
    property int selectedApiIndex: 0

    readonly property var booruApis: [
        { name: "Danbooru",  value: "danbooru",  url: "https://danbooru.donmai.us/",    idSearchUrl: "https://danbooru.donmai.us/posts/" },
        { name: "Gelbooru",  value: "gelbooru",  url: "https://gelbooru.com/",            idSearchUrl: "https://gelbooru.com/index.php?page=post&s=view&id=" },
        { name: "Safebooru", value: "safebooru", url: "https://safebooru.donmai.us/",     idSearchUrl: "https://safebooru.donmai.us/posts/" },
    ]

    // ---- placeholder: no image selected ----
    Item {
        anchors.fill: parent
        visible: !root.hasWaifu

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "No image selected"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
            }
            Text {
                text: "Open Booru Viewer to select an image"
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize
            }
            Button {
                text: "Open Booru Viewer"
                background: Rectangle {
                    color: Theme.accentBg
                    radius: 4
                    border.color: Theme.accent
                }
                contentItem: Text {
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                onClicked: {
                    // Switch left panel to BooruViewer
                    Ipc.handler("bar").call("toggleLeftPanel", Registry.monitorName)
                }
            }
        }
    }

    // ---- media display ----
    Item {
        id: mediaContainer
        anchors.top: parent.top
        anchors.bottom: actionsRow.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.hasWaifu

        Image {
            id: imageDisplay
            anchors.fill: parent
            anchors.margins: 4
            fillMode: Image.PreserveAspectFit
            source: root.imagePath
            sourceSize.width: parent.width
            asynchronous: true
            cache: true
            visible: !root.isVideo
        }

        // Video fallback
        Text {
            anchors.centerIn: parent
            text: root.isVideo ? "Video: " + root.imagePath : ""
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize
            visible: root.isVideo
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: root.wd_tags.length > 0 ? root.wd_tags.slice(0, 10).join(", ") : ""
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
            width: parent.width
            wrapMode: Text.Wrap
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            width: infoRow.implicitWidth + 8
            height: 18
            color: Theme.bg
            radius: 4
            border.color: Theme.border
            border.width: 1
            visible: root.wd_id > 0
            Row {
                id: infoRow
                anchors.centerIn: parent
                spacing: 6
                Text { text: "\u{f0c9}"; color: Theme.accent; font.pixelSize: 12 }
                Text { text: root.wd_id + ""; color: Theme.fg; font.pixelSize: 11 }
                Text { text: root.wd_width + "x" + root.wd_height; color: Theme.fgDim; font.pixelSize: 11 }
            }
        }
    }

    // ---- actions ----
    Row {
        id: actionsRow
        spacing: 8
        anchors.bottom: parent.bottom
        width: parent.width
        height: 36
        visible: root.hasWaifu

        // Bookmark toggle
        Button {
            property bool bookmarked: (Settings.booru.bookmarks || []).some(b =>
                b.id === root.wd_id && b.api?.value === root.wd_apiValue)
            text: root.bookmarked ? "\u{f004}" : "\u{f0160}"
            width: 36; height: 24
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: "Bookmark"
            onClicked: {
                const bookmarks = Settings.booru.bookmarks || []
                const idx = bookmarks.findIndex(b =>
                    b.id === root.wd_id && b.api?.value === root.wd_apiValue)
                if (idx >= 0) {
                    const next = bookmarks.slice()
                    next.splice(idx, 1)
                    Settings.booru.bookmarks = next
                } else {
                    Settings.booru.bookmarks = [...bookmarks, root.wd]
                }
                Settings.persist()
            }
            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
            contentItem: Text { color: Theme.accent; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
        }

        // Pin to terminal
        Button {
            property bool pinned: (Settings.booru.pins || []).some(p =>
                p.id === root.wd_id && p.api?.value === root.wd_apiValue)
            text: pinned ? "\u{f44c}" : "\u{f98b}"
            width: 36; height: 24
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: root.isVideo ? "Cannot pin videos" : "Pin to terminal"
            enabled: !root.isVideo
            onClicked: {
                const pins = Settings.booru.pins || []
                const existing = pins.findIndex(p =>
                    p.id === root.wd_id && p.api?.value === root.wd_apiValue)
                if (existing >= 0) {
                    const next = pins.slice()
                    next.splice(existing, 1)
                    Settings.booru.pins = next
                } else {
                    Settings.booru.pins = [...pins, root.wd]
                }
                Settings.persist()
            }
            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
            contentItem: Text { color: Theme.accent; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
        }

        // Open in viewer
        Button {
            text: "\u{f07c}"
            width: 36; height: 24
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: "Open in viewer"
            onClicked: Quickshell.execDetached(["xdg-open", root.imagePath])
            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
            contentItem: Text { color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
        }

        // Open in browser
        Button {
            text: "\u{f08e}"
            width: 36; height: 24
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: "Open in browser"
            onClicked: {
                const api = root.booruApis[root.selectedApiIndex]
                Quickshell.execDetached(["xdg-open", api.idSearchUrl + root.wd_id])
            }
            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
            contentItem: Text { color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
        }

        // Copy to clipboard
        Button {
            text: "\u{f0c5}"
            width: 36; height: 24
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: "Copy to clipboard"
            enabled: !root.isVideo
            onClicked: Quickshell.execDetached(["bash", "-c", `wl-copy --type image/png < '${root.imagePath}'`])
            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
            contentItem: Text { color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
        }

        // Search by ID
        Button {
            text: "\u{f002}"
            width: 36; height: 24
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: "Search by post ID"
            onClicked: root.idSearchField.forceActiveFocus()
            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
            contentItem: Text { color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
        }

        TextField {
            id: idSearchField
            width: 120; height: 24
            placeholderText: "Post ID..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            visible: root.hasWaifu
            background: Rectangle { color: Theme.bg; radius: 4; border.color: Theme.border }
            onAccepted: {
                root.loadingState = "loading"
                const api = root.booruApis[root.selectedApiIndex]
                const proc = Qt.createQmlObject(
                    'import Quickshell.Io; Process { command: ["python", "' + root.booruScript + '", "--api", "' + api.value + '", "--id", "' + text + '"] }',
                    root
                )
                proc.running = true
                proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
                proc.stdout.onStreamFinished.connect(function() {
                    const response = proc.stdout.text
                    try {
                        if (response && response.trim() !== "" && response.trim().startsWith("[")) {
                            const parsed = JSON.parse(response)
                            if (parsed.length > 0) {
                                const img = parsed[0]
                                const newWaifu = {
                                    id: img.id,
                                    width: img.width,
                                    height: img.height,
                                    api: api,
                                    tags: img.tags || [],
                                    extension: img.extension,
                                    url: img.url,
                                    preview: img.preview,
                                }
                                Settings.waifu = newWaifu
                                Settings.persist()
                                root.loadingState = "success"
                            }
                        }
                    } catch (e) {
                        root.loadingState = "error"
                    }
                    proc.destroy()
                })
            }
        }

        // API tabs
        Row {
            spacing: 2
            Repeater {
                model: root.booruApis
                delegate: Button {
                    text: modelData.name
                    width: 80; height: 24
                    checkable: true
                    checked: root.selectedApiIndex === index
                    onClicked: root.selectedApiIndex = index
                    font.pixelSize: Theme.fontSize - 2
                    background: Rectangle {
                        color: checked ? Theme.accentBg : Theme.moduleBg
                        radius: 4
                        border.color: checked ? Theme.accent : Theme.border
                    }
                    contentItem: Text { color: checked ? Theme.accent : Theme.fg; font.pixelSize: Theme.fontSize - 2; anchors.centerIn: parent }
                }
            }
        }
    }
}
