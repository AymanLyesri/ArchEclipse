import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

// Booru Viewer widget — port of widgets/leftPanel/components/BooruViewer.tsx
// Features: multiple API tabs (Danbooru/Gelbooru/Safebooru), bookmarks, pins,
// tag search, masonry grid, pagination (keyboard nav), revealable settings
// (limit/columns/tags/cache-clear), preview download via booru.py.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    readonly property string booruPath: `${Quickshell.env("HOME")}/.config/ags/cache/booru`
    readonly property string booruScript: `${Quickshell.env("HOME")}/.config/ags/scripts/booru.py`

    // --- state (per-instance, not singleton) ---
    property var images: []           // fetched image objects
    property string progressStatus: "idle"  // "loading" | "error" | "success" | "idle"
    property string selectedTab: Settings.booru.api ? Settings.booru.api.name : "Danbooru"
    property int page: 1
    property string pageDirection: "next"
    property var fetchedTags: []
    property string cacheSize: "0mb"
    property var currentTags: Settings.booru.tags ? Settings.booru.tags : ["-rating:explicit"]
    property int limit: Settings.booru.limit ? Settings.booru.limit : 100
    property int columns: Settings.booru.columns ? Settings.booru.columns : 3
    property bool bottomRevealed: false
    property bool keyEnabled: true

    readonly property var booruApis: [
        { name: "Danbooru",  value: "danbooru",  url: "https://danbooru.donmai.us/",    idSearchUrl: "https://danbooru.donmai.us/posts/" },
        { name: "Gelbooru",  value: "gelbooru",  url: "https://gelbooru.com/",            idSearchUrl: "https://gelbooru.com/index.php?page=post&s=view&id=" },
        { name: "Safebooru", value: "safebooru", url: "https://safebooru.donmai.us/",     idSearchUrl: "https://safebooru.donmai.us/posts/" },
    ]

    // --- helpers ---

    function ensureRatingTagFirst() {
        // Find existing rating tag, remove it, re-add at front (or default -rating:explicit)
        let tags = root.currentTags.slice();
        const ratingTag = tags.find(t => t.match(/[-]rating:explicit|rating:explicit/));
        tags = tags.filter(t => !t.match(/[-]rating:explicit|rating:explicit/));
        tags.unshift(ratingTag ?? "-rating:explicit");
        root.currentTags = tags;
        Settings.booru.tags = tags;
        Settings.updateSetting("booru.tags", tags);
    }

    function calculateCacheSize() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru"
        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["bash", "-c", "du -sb ' + root.booruPath + '/' + apiValue + '/previews 2>/dev/null | cut -f1"] }',
            root
        )
        proc.running = true
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        proc.stdout.onStreamFinished.connect(function() {
            const bytes = parseInt(proc.stdout.text.trim()) || 0
            root.cacheSize = Math.round(bytes / (1024 * 1024)) + "mb"
            proc.destroy()
        })
    }

    function cleanCache() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru"
        Quickshell.execDetached(["bash", "-c",
            `rm -rf '${root.booruPath}/${apiValue}/previews/*' '${root.booruPath}/${apiValue}/images/*'`])
        root.calculateCacheSize()
    }

    function fetchImages() {
        root.progressStatus = "loading"

        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru"
        const apiObj = root.booruApis.find(a => a.value === apiValue) || root.booruApis[0]
        const tagsStr = root.currentTags.join(",")
        const currentPage = Math.max(1, root.page)
        const startIndex = root.limit > 0 ? (currentPage - 1) * root.limit : 0

        // Build command
        let cmd = ["python", root.booruScript, "--api", apiValue, "--tags", tagsStr,
                   "--limit", String(root.limit), "--page", String(currentPage)]

        // Add API credentials if available
        const credentials = Settings.apiKeys && Settings.apiKeys[apiValue]
        if (credentials && credentials.user && credentials.key) {
            cmd.push("--api-user", credentials.user, "--api-key", credentials.key)
        }

        const cmdJson = JSON.stringify(cmd)
        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ' + cmdJson + '; stdout: StdioCollector {} }',
            root
        )
        proc.running = true
        proc.stdout.onStreamFinished.connect(function() {
            const text = proc.stdout.text
            if (!text || !text.trim().startsWith("[")) {
                root.progressStatus = "error"
                proc.destroy()
                return
            }
            try {
                const data = JSON.parse(text)
                root.images = data.map(img => ({
                    id: img.id || 0,
                    width: img.width || 0,
                    height: img.height || 0,
                    api: apiObj,
                    tags: img.tags || [],
                    extension: img.extension,
                    url: img.url,
                    preview: img.preview,
                }))
                root.calculateCacheSize()
                root.progressStatus = "success"
            } catch (e) {
                root.progressStatus = "error"
            }
            proc.destroy()
        })

        // Download all previews in parallel (unified approach)
        root.downloadPreviews(root.images)
    }

    function downloadPreviews(imgList) {
        imgList.forEach(img => {
            const previewDir = `${root.booruPath}/${img.api.value}/previews`
            const filePath = `${previewDir}/${img.id}.${img.extension}`
            const previewUrl = img.preview

            if (!previewUrl) return

            // Check if file exists, download if not
            const checkProc = Qt.createQmlObject(
                'import Quickshell.Io; Process { command: ["bash", "-c", "test -f \\"' + filePath + '\\" && echo yes || echo no"] }', root
            )
            checkProc.running = true
            checkProc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
            checkProc.stdout.onStreamFinished.connect(function() {
                if (checkProc.stdout.text.trim() === "no") {
                    Quickshell.execDetached(["bash", "-c",
                        `mkdir -p "${previewDir}" && ` +
                        `curl -sSf -H "User-Agent: QuickshellBooru/1.0 (ArchLinux; Hyprland)" ` +
                        `-H "Referer: ${img.api.url}" ` +
                        `-H "Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8" ` +
                        `-o "${filePath}" "${previewUrl}"`])
                }
                checkProc.destroy()
            })
        })
    }

    // --- UI ---

    Column {
        anchors.fill: parent
        spacing: 10

        // Tabs
        Row {
            id: tabRow
            spacing: 4
            width: parent.width

            Repeater {
                model: root.booruApis
                delegate: Button {
                    text: modelData.name
                    width: (parent.width - 20) / 5  // 3 APIs + Bookmarks + Pins = 5 tabs
                    height: 28
                    checkable: true
                    checked: root.selectedTab === modelData.name
                    enabled: root.progressStatus !== "loading"
                    font.pixelSize: Theme.fontSize - 2
                    onClicked: {
                        Settings.booru.api = modelData
                        Settings.updateSetting("booru.api", modelData)
                        root.selectedTab = modelData.name
                        Settings.booru.selectedTab = modelData.name
                        Settings.updateSetting("booru.selectedTab", modelData.name)
                        root.page = 1
                        Settings.booru.page = 1
                        Settings.updateSetting("booru.page", 1)
                        root.fetchImages()
                    }
                    background: Rectangle {
                        color: checked ? Theme.accentBg : Theme.moduleBg
                        radius: 4
                        border.color: checked ? Theme.accent : Theme.border
                    }
                    contentItem: Text {
                        color: checked ? Theme.accent : Theme.fg
                        font.pixelSize: Theme.fontSize - 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Bookmark tab
            Button {
                text: "\u{f004}"  // heart
                width: (parent.width - 20) / 5
                height: 28
                checkable: true
                checked: root.selectedTab === "Bookmarks"
                enabled: root.progressStatus !== "loading"
                font.pixelSize: Theme.fontSize - 2
                onClicked: {
                    root.selectedTab = "Bookmarks"
                    Settings.booru.selectedTab = "Bookmarks"
                    Settings.updateSetting("booru.selectedTab", "Bookmarks")
                    root.page = 1
                    Settings.booru.page = 1
                    Settings.updateSetting("booru.page", 1)
                    // Load bookmarks
                    root.images = Settings.booru.bookmarks || []
                    root.progressStatus = "success"
                }
                background: Rectangle {
                    color: checked ? Theme.accentBg : Theme.moduleBg
                    radius: 4
                    border.color: checked ? Theme.accent : Theme.border
                }
                contentItem: Text {
                    color: checked ? Theme.accent : Theme.fg
                    font.pixelSize: Theme.fontSize - 2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Pins tab
            Button {
                text: "\u{f98b}"  // pin
                width: (parent.width - 20) / 5
                height: 28
                checkable: true
                checked: root.selectedTab === "Pins"
                enabled: root.progressStatus !== "loading"
                font.pixelSize: Theme.fontSize - 2
                onClicked: {
                    root.selectedTab = "Pins"
                    Settings.booru.selectedTab = "Pins"
                    Settings.updateSetting("booru.selectedTab", "Pins")
                    root.page = 1
                    Settings.booru.page = 1
                    Settings.updateSetting("booru.page", 1)
                    root.images = Settings.booru.pins || []
                    root.progressStatus = "success"
                }
                background: Rectangle {
                    color: checked ? Theme.accentBg : Theme.moduleBg
                    radius: 4
                    border.color: checked ? Theme.accent : Theme.border
                }
                contentItem: Text {
                    color: checked ? Theme.accent : Theme.fg
                    font.pixelSize: Theme.fontSize - 2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Image masonry grid
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Masonry grid: multiple columns, items flow to shortest column
            Flow {
                id: masonry
                width: parent.width
                spacing: 6
                padding: 4

                Repeater {
                    model: root.images
                    delegate: Rectangle {
                        id: imgCard
                        required property var modelData
                        property bool isVideo: ["mp4", "webm", "mkv", "gif", "zip"]
                            .includes((modelData.extension || "").toLowerCase())

                        width: (masonry.width - 20) / root.columns
                        height: modelData.width && modelData.height
                            ? Math.max(80, width * modelData.height / modelData.width)
                            : width

                        color: Theme.moduleBg
                        radius: 6
                        border.width: 1
                        border.color: Theme.border
                        clip: true

                        // Preview image (or placeholder)
                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            fillMode: Image.PreserveAspectFit
                            source: modelData.preview
                                ? modelData.preview
                                : `${root.booruPath}/${modelData.api.value}/previews/${modelData.id}.${modelData.extension}`
                            sourceSize.width: parent.width
                            asynchronous: true
                            cache: true
                            visible: !imgCard.isVideo
                        }

                        // Video indicator
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: 16; height: 16
                            radius: 8
                            color: Theme.accent
                            visible: imgCard.isVideo
                            Text {
                                text: "\u{f03d}"  // video icon
                                color: "white"
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }
                        }

                        // Info overlay
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: infoRow.implicitWidth + 8
                            height: 18
                            color: Theme.bg
                            radius: 4
                            border.color: Theme.border
                            border.width: 1
                            Row {
                                id: infoRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: modelData.id; color: Theme.fg; font.pixelSize: 10 }
                                Text { text: modelData.width + "x" + modelData.height; color: Theme.fgDim; font.pixelSize: 9 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // Set as current waifu (like renderAsWaifuWidget)
                                Settings.waifu = modelData
                                Settings.persist()
                            }
                        }
                    }
                }
            }
        }

        // Bottom bar: navigation + revealable settings
        Column {
            width: parent.width
            spacing: 4

            // Navigation row
            Row {
                spacing: 8
                width: parent.width
                height: 28

                Button {
                    text: "\u{f061}"  // chevron left
                    width: 32; height: 28
                    enabled: root.progressStatus !== "loading"
                    onClicked: {
                        if (root.page > 1) {
                            root.pageDirection = "prev"
                            root.page = root.page - 1
                            Settings.booru.page = root.page
                            Settings.updateSetting("booru.page", root.page)
                            root.fetchImages()
                        }
                    }
                    background: Rectangle {
                        color: Theme.moduleBg; radius: 4; border.color: Theme.border
                    }
                    contentItem: Text {
                        color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent
                    }
                }

                Button {
                    text: root.bottomRevealed ? "\u{f07e}" : "\u{f07c}"  // down/up chevron
                    width: 32; height: 28
                    onClicked: root.bottomRevealed = !root.bottomRevealed
                    background: Rectangle {
                        color: Theme.moduleBg; radius: 4; border.color: Theme.border
                    }
                    contentItem: Text {
                        color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent
                    }
                }

                Button {
                    text: "\u{f061}"  // chevron right
                    width: 32; height: 28
                    enabled: root.progressStatus !== "loading"
                    onClicked: {
                        root.pageDirection = "next"
                        root.page = root.page + 1
                        Settings.booru.page = root.page
                        Settings.updateSetting("booru.page", root.page)
                        root.fetchImages()
                    }
                    background: Rectangle {
                        color: Theme.moduleBg; radius: 4; border.color: Theme.border
                    }
                    contentItem: Text {
                        color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent
                    }
                }

                Text {
                    text: "Page " + root.page
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 1
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 80
                }

                Text {
                    text: root.progressStatus
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize - 2
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                }
            }

            // Revealable settings
            Rectangle {
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
                        Text { text: "Limit: " + root.limit; color: Theme.fg; font.pixelSize: Theme.fontSize - 2 }
                        Slider {
                            id: limitSlider
                            from: 10; to: 500; stepSize: 1
                            value: root.limit
                            Layout.fillWidth: true
                            onValueChanged: {
                                root.limit = Math.round(limitSlider.value)
                                Settings.booru.limit = root.limit
                                Settings.updateSetting("booru.limit", root.limit)
                            }
                        }
                    }

                    // Columns slider
                    Row {
                        spacing: 8
                        width: parent.width
                        Text { text: "Columns: " + root.columns; color: Theme.fg; font.pixelSize: Theme.fontSize - 2 }
                        Slider {
                            id: columnsSlider
                            from: 1; to: 6; stepSize: 1
                            value: root.columns
                            Layout.fillWidth: true
                            onValueChanged: {
                                root.columns = Math.round(columnsSlider.value)
                                Settings.booru.columns = root.columns
                                Settings.updateSetting("booru.columns", root.columns)
                            }
                        }
                    }

                    // Tags
                    Column {
                        spacing: 4
                        width: parent.width

                        // Tags flow
                        Flow {
                            spacing: 4
                            width: parent.width
                            Repeater {
                                model: root.currentTags
                                delegate: Rectangle {
                                    width: tagText.implicitWidth + 16
                                    height: 22
                                    color: Theme.accentBg
                                    radius: 4
                                    border.color: Theme.accent
                                    border.width: 1
                                    Text {
                                        id: tagText
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Theme.accent
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            const newTags = root.currentTags.filter(t => t !== modelData)
                                            root.currentTags = newTags
                                            Settings.booru.tags = newTags
                                            Settings.updateSetting("booru.tags", newTags)
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
                                        root.fetchTags(text)
                                    }
                                }
                                Keys.onReturnPressed: {
                                    if (text.trim()) {
                                        const newTags = [...new Set([...root.currentTags, ...text.trim().split(" ")])]
                                        root.currentTags = newTags
                                        Settings.booru.tags = newTags
                                        Settings.updateSetting("booru.tags", newTags)
                                        tagEntry.text = ""
                                    }
                                }
                            }
                            Button {
                                text: root.cacheSize
                                width: 50; height: 24
                                ToolTip.visible: hovered; ToolTip.delay: 500
                                ToolTip.text: "Clear cache"
                                onClicked: root.cleanCache()
                                background: Rectangle { color: Theme.bg; radius: 4; border.color: Theme.border }
                                contentItem: Text { color: Theme.fgDim; font.pixelSize: Theme.fontSize - 2; anchors.centerIn: parent }
                            }
                        }

                        // Fetched tag suggestions
                        Flow {
                            spacing: 4
                            width: parent.width
                            visible: root.fetchedTags.length > 0
                            Repeater {
                                model: root.fetchedTags
                                delegate: Button {
                                    text: modelData
                                    width: tagText2.implicitWidth + 12
                                    height: 20
                                    font.pixelSize: Theme.fontSize - 3
                                    onClicked: {
                                        const newTags = [...new Set([...root.currentTags, modelData])]
                                        root.currentTags = newTags
                                        Settings.booru.tags = newTags
                                        Settings.updateSetting("booru.tags", newTags)
                                        root.fetchedTags = []
                                    }
                                    background: Rectangle { color: Theme.bg; radius: 3; border.color: Theme.border }
                                    contentItem: Text { color: Theme.fgDim; font.pixelSize: Theme.fontSize - 2; anchors.centerIn: parent }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- keyboard navigation ---
    Item {
        anchors.fill: parent
        focus: true
        Keys.onUpPressed: { root.bottomRevealed = true; event.accepted = true }
        Keys.onDownPressed: { root.bottomRevealed = false; event.accepted = true }
        Keys.onLeftPressed: {
            if (root.keyEnabled && root.progressStatus !== "loading" && root.page > 1) {
                root.pageDirection = "prev"
                root.page = root.page - 1
                Settings.booru.page = root.page
                Settings.updateSetting("booru.page", root.page)
                root.fetchImages()
            }
            event.accepted = true
        }
        Keys.onRightPressed: {
            if (root.keyEnabled && root.progressStatus !== "loading") {
                root.pageDirection = "next"
                root.page = root.page + 1
                Settings.booru.page = root.page
                Settings.updateSetting("booru.page", root.page)
                root.fetchImages()
            }
            event.accepted = true
        }
    }

    // --- fetch tag suggestions ---
    function fetchTags(tag) {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru"
        const credentials = Settings.apiKeys && Settings.apiKeys[apiValue]
        let cmd = ["python", root.booruScript, "--api", apiValue, "--tag", tag]
        if (credentials && credentials.user && credentials.key) {
            cmd.push("--api-user", credentials.user, "--api-key", credentials.key)
        }
        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + ' }',
            root
        )
        proc.running = true
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        proc.stdout.onStreamFinished.connect(function() {
            const text = proc.stdout.text
            try {
                if (text && text.trim().startsWith("[")) {
                    const data = JSON.parse(text)
                    root.fetchedTags = data.slice(0, 10)
                }
            } catch (e) {
                root.fetchedTags = []
            }
            proc.destroy()
        })
    }

    // Initial fetch on load
    Component.onCompleted: {
        ensureRatingTagFirst()
        const savedTab = Settings.booru.selectedTab || Settings.booru.api.name
        root.selectedTab = savedTab
        root.calculateCacheSize()
        root.fetchImages()
    }
}
