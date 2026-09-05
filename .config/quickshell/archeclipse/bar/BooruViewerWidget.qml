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
    property bool _firstImages: true
    // AGS Images subscribe: slide new page in from the travel direction,
    // scroll to top; first render appears without transition.
    onImagesChanged: {
        gridScroll.contentY = 0
        if (root._firstImages) {
            root._firstImages = false
            return
        }
        slideAnim.stop()
        masonryRow.x = root.pageDirection === "next" ? 60 : -60
        slideAnim.start()
    }
    // AGS createImagesContent masonry: distribute to the shortest column by
    // aspect ratio (NOT row-by-row Flow). NOTE: must live on root — a
    // property declared among ColumnLayout children belongs to the layout.
    readonly property var masonryColumns: {
        const imgs = root.images || [];
        const n = Math.max(1, root.columns);
        const cols = [];
        for (let i = 0; i < n; i++) cols.push({ h: 0, items: [] });
        for (const im of imgs) {
            const ratio = (im.width && im.height) ? im.height / im.width : 1;
            let t = cols[0];
            for (const c of cols) if (c.h < t.h) t = c;
            t.items.push(im);
            t.h += ratio;
        }
        return cols.map(c => c.items);
    }
    property string progressStatus: "idle"  // "loading" | "error" | "success" | "idle"
    property string selectedTab: Settings.booru.api ? Settings.booru.api.name : "Danbooru"
    property int page: 1
    property string pageDirection: "next"
    property var fetchedTags: []
    property string cacheSize: "0mb"
    property var currentTags: Settings.booru.tags ? Settings.booru.tags : ["-rating:explicit"]
    property int limit: Settings.booru.limit ? Settings.booru.limit : 100
    property int columns: Settings.booru.columns ? Settings.booru.columns : 3

    // Diagnostic: last fetch command with secrets redacted (IPC-readable)
    property string lastFetchCmd: ""
    property string lastFetchError: ""

    // AGS renderAsImageDialog state — the currently open image dialog
    property var dialogImage: null   // set to an image object to open the dialog

    // --------- helpers for image dialog (mirror BooruImage.class) ---------
    function getIconPath(img, which) {
        // which: "previews" | "images"
        return `${root.booruPath}/${img.api.value}/${which}/${img.id}.${img.extension}`
    }
    function isInArray(arr, img) {
        if (!img) return false
        return (arr || []).some(x => x && (String(x.id) === String(img.id)))
    }
    function isBookmarked(img) { return root.isInArray(Settings.booru.bookmarks, img) }
    function isPinned(img)     { return root.isInArray(Settings.booru.pins, img) }
    function isCurrentWaifu(img) {
        const w = Settings.waifu
        return w && (String(w.id) === String(img.id))
    }
    function isInfoTagged(img) { return root.isPinned(img) || root.isBookmarked(img) || root.isCurrentWaifu(img) }
    function isVideo(img) {
        return ["mp4","webm","mkv","gif","zip"].includes((img.extension||"").toLowerCase())
    }
    // Downloaded set: populated by downloadImage()'s completion poller (avoids
    // needing a synchronous filesystem-exists primitive in QML).
    property var downloadedIds: ({})
    function isDownloaded(img) { return !!img && !!root.downloadedIds[String(img.id)] }
    function imageFileUrl(img) {
        if (!img) return ""
        return root.isDownloaded(img)
            ? "file://" + root.getIconPath(img, "images")
            : (img.preview ? img.preview : "file://" + root.getIconPath(img, "previews"))
    }
    function openInBrowser(img) {
        const base = img.api.idSearchUrl || "https://danbooru.donmai.us/posts/"
        Quickshell.execDetached(["xdg-open", base + img.id])
    }
    function toggleBookmark(img) {
        const arr = (Settings.booru.bookmarks || []).slice()
        const i = arr.findIndex(x => x && String(x.id) === String(img.id))
        if (i >= 0) { arr.splice(i, 1) } else { arr.push(img) }
        Settings.booru.bookmarks = arr
        Settings.booru = Settings.booru  // touch parent var: nested field
        Settings.schedulePersist()        // assignment does NOT emit booruChanged
        return i < 0   // true = now bookmarked
    }
    function togglePinned(img) {
        const arr = (Settings.booru.pins || []).slice()
        const i = arr.findIndex(x => x && String(x.id) === String(img.id))
        if (i >= 0) { arr.splice(i, 1) } else { arr.push(img) }
        Settings.booru.pins = arr
        Settings.booru = Settings.booru  // touch parent var (see above)
        Settings.schedulePersist()
        FastfetchPins.scheduleSync()
        return i < 0
    }
    function downloadImage(img) {
        root.progressStatus = "loading"
        const dir = `${root.booruPath}/${img.api.value}/images`
        const target = `${dir}/${img.id}.${img.extension}`
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p '${dir}' && curl -sL -o '${target}' '${img.url}'`])
        // poll for a non-empty file to appear (network fetch may take time)
        const poll = Qt.createQmlObject(
            'import QtQuick; import Quickshell.Io; Timer { interval: 1200; repeat: true; ' +
            'property var check: null }', root)
        poll.triggered.connect(function() {
            if (poll.check && poll.check.running) return   // one check at a time
            poll.check = Qt.createQmlObject(
                'import Quickshell.Io; Process { stdout: StdioCollector {} }', root)
            const targetJson = JSON.stringify(target)
            poll.check.command = ["bash", "-c", `[ -s ${targetJson} ] && echo yes`]
            const p = poll.check
            p.running = true
            p.stdout.onStreamFinished.connect(function() {
                if (p.stdout.text.trim() === "yes") {
                    poll.stop(); poll.destroy()
                    const ids = root.downloadedIds
                    ids[String(img.id)] = true
                    root.downloadedIds = ids
                    root.progressStatus = "success"
                    root.dialogVersion++
                }
                p.destroy()
                poll.check = null
            })
        })
        poll.start()
    }
    function setAsWaifu(img) {
        Settings.waifu = img
        Settings.schedulePersist()
    }
    function openTags(tag) { root.currentTags = [tag]; root.page = 1; root.fetchImages() }
    function copyTag(tag) { Quickshell.execDetached(["bash","-c", "echo -n '" + tag + "' | wl-copy"]) }
    function formatTagForDisplay(tag) { return tag }

    // forces dialog overlay to recompute toggle states after downloads
    property int dialogVersion: 0
    property bool bottomRevealed: false
    property bool keyEnabled: true
    property Timer _limitDebounce: Timer { interval: 300; repeat: false; onTriggered: root.fetchImages() }

    readonly property var booruApis: [
        { name: "Danbooru",  value: "danbooru",  url: "https://danbooru.donmai.us/",    idSearchUrl: "https://danbooru.donmai.us/posts/" },
        { name: "Gelbooru",  value: "gelbooru",  url: "https://gelbooru.com/",            idSearchUrl: "https://gelbooru.com/index.php?page=post&s=view&id=" },
        { name: "Safebooru", value: "safebooru", url: "https://safebooru.donmai.us/",     idSearchUrl: "https://safebooru.donmai.us/posts/" },
    ]

    // The currently selected API object (for preview path resolution in bookmark/pin tabs)
    readonly property var currentApiObj: {
        const v = Settings.booru.api ? Settings.booru.api.value : "danbooru"
        return root.booruApis.find(a => a.value === v) || root.booruApis[0]
    }

    // Manual property copy (QML JS has no object-spread `{...obj}`). AGS
    // parity (BooruViewer.tsx:219-221 via new BooruImage(b)): preserve the
    // item's own stored api so cross-API bookmarks/pins resolve to the right
    // preview dir and idSearchUrl — never overwrite with the current tab.
    function clonify(img) {
        return {
            id: img.id,
            width: img.width,
            height: img.height,
            tags: img.tags || [],
            url: img.url,
            preview: img.preview,
            extension: img.extension,
            api: img.api || root.currentApiObj,
        }
    }

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
            'import Quickshell.Io; Process { stdout: StdioCollector {} }',
            root
        )
        proc.command = ["bash", "-c", "du -sb " + JSON.stringify(root.booruPath + '/' + apiValue + '/previews') + " 2>/dev/null | cut -f1"]
        proc.stdout.onStreamFinished.connect(function() {
            const bytes = parseInt(proc.stdout.text.trim()) || 0
            root.cacheSize = Math.round(bytes / (1024 * 1024)) + "mb"
            proc.destroy()
        })
        proc.running = true
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

        // Add API credentials if available (AGS: credentials.user.value /
        // credentials.key.value; Settings.apiKey unwraps either shape and
        // falls back to the shipped public defaults)
        const apiUser = Settings.apiKey(apiValue, "user")
        const apiPass = Settings.apiKey(apiValue, "key")
        if (apiUser !== "" && apiPass !== "") {
            cmd.push("--api-user", apiUser, "--api-key", apiPass)
        }

        const cmdJson = JSON.stringify(cmd)
        root.lastFetchCmd = JSON.stringify(cmd.map((a, i) =>
            (a === "--api-key" || a === "--api-user") ? a : (cmd[i-1] === "--api-key" || cmd[i-1] === "--api-user" ? "***" : a)))
        root.lastFetchError = ""
        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ' + cmdJson + ' }',
            root
        )
        // Collectors must be attached before running (never after), and
        // inline `stderr:` is rejected by the QML parser — assign here.
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        proc.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        proc.running = true
        // NOTE: read streams on process exit, NOT on stdout.onStreamFinished:
        // stderr may not have flushed when stdout closes, which hid the
        // script's real error envelope (empty stderr reads).
        proc.exited.connect(function(exitCode, exitStatus) {
            const text = proc.stdout.text
            // booru.py emit_error() writes to STDERR with empty stdout, so a
            // credential rejection would otherwise surface as a generic error.
            const errText = proc.stderr.text
            if ((!text || !text.trim()) && errText && errText.trim()) {
                root.progressStatus = "error"
                let msg = errText.trim().slice(0, 300)
                try {
                    const ej = JSON.parse(errText.trim())
                    if (ej && ej.message) msg = String(ej.message)
                } catch (e) {}
                Notifications.notify({ summary: "Booru error", body: msg })
                proc.destroy()
                return
            }
            // AGS parseBooruArrayResponse: surface the script's error envelope
            // message (e.g. missing API credentials) instead of a generic error
            let parsed = null
            try { parsed = text && text.trim() ? JSON.parse(text) : null } catch (e) { parsed = null }
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed) && parsed.error === true) {
                root.progressStatus = "error"
                const msg = (parsed.message && String(parsed.message).trim()) || "Unknown booru error"
                Notifications.notify({ summary: "Booru error", body: msg })
                proc.destroy()
                return
            }
            if (!Array.isArray(parsed)) {
                root.progressStatus = "error"
                // AGS notifies per-tab error (bookmarks/pins/images)
                const tab = root.selectedTab
                const summary = tab === "Bookmarks" ? "Error loading bookmarks"
                               : tab === "Pins" ? "Error loading pins" : "Error fetching images"
                const body = tab === "Bookmarks" ? "Failed to load bookmarks"
                             : tab === "Pins" ? "Failed to load pins" : "Failed to fetch images"
                const detail = text && text.trim() ? text.trim().slice(0, 200) : body
                root.lastFetchError = "stdout[" + (text ? text.trim().slice(0, 200) : "<empty>") + "] stderr[" + (errText ? errText.slice(0, 200) : "<empty>") + "]"
                Notifications.notify({ summary: summary, body: detail })
                proc.destroy()
                return
            }
            try {
                const data = parsed
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
                // Download previews for the NEW images (was previously called
                // on the stale list before the fetch completed)
                root.downloadPreviews(root.images)
            } catch (e) {
                root.progressStatus = "error"
                Notifications.notify({ summary: "Error fetching images", body: String(e) })
            }
            proc.destroy()
        })
    }

    // Local preview-file ids verified present on disk. Grid prefers these
    // (AGS renders the downloaded local preview via getPreviewPath()).
    property var previewIds: ({})
    function isPreviewCached(img) { return !!img && !!root.previewIds[String(img.id)] }
    // Grid source: full image file if downloaded, else cached preview file,
    // else the remote preview URL.
    function gridSource(img) {
        if (!img) return ""
        if (root.isDownloaded(img)) return "file://" + root.getIconPath(img, "images")
        if (root.isPreviewCached(img)) return "file://" + root.getIconPath(img, "previews")
        return img.preview ? img.preview : "file://" + root.getIconPath(img, "previews")
    }

    function downloadPreviews(imgList) {
        const pending = []
        imgList.forEach(img => {
            const previewDir = `${root.booruPath}/${img.api.value}/previews`
            const filePath = `${previewDir}/${img.id}.${img.extension}`
            const previewUrl = img.preview

            if (!previewUrl) return
            pending.push({ id: String(img.id), path: filePath })

            // Check if file exists, download if not. NOTE: the stdout
            // collector must be attached in the constructor — setting
            // running=true before assigning stdout races and drops output.
            const checkProc = Qt.createQmlObject(
                'import Quickshell.Io; Process { stdout: StdioCollector {} }', root
            )
            checkProc.command = ["bash", "-c", "test -f " + JSON.stringify(filePath) + " && echo yes || echo no"]
            checkProc.stdout.onStreamFinished.connect(function() {
                if (checkProc.stdout.text.trim() === "no") {
                    Quickshell.execDetached(["bash", "-c",
                        `mkdir -p \"${previewDir}\" && ` +
                        `curl -sSf -H \"User-Agent: QuickshellBooru/1.0 (ArchLinux; Hyprland)\" ` +
                        `-H \"Referer: ${img.api.url}\" ` +
                        `-H \"Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8\" ` +
                        `-o \"${filePath}\" \"${previewUrl}\"`])
                } else {
                    const ids = Object.assign({}, root.previewIds)
                    ids[String(img.id)] = true
                    root.previewIds = ids
                }
                checkProc.destroy()
            })
            checkProc.running = true
        })
        // Single delayed verification pass: curls run detached, so re-check
        // the batch once and flip the grid to file:// URLs as files land.
        if (pending.length === 0) return
        const verify = Qt.createQmlObject(
            'import QtQuick; Timer { repeat: false; interval: 6000 }', root)
        verify.triggered.connect(function() {
            const script = pending.map(p =>
                "test -s " + JSON.stringify(p.path) + " && echo " + p.id).join(" || true; ")
            const vp = Qt.createQmlObject(
                'import Quickshell.Io; Process { stdout: StdioCollector {} }', root)
            vp.command = ["bash", "-c", script + " || true"]
            vp.stdout.onStreamFinished.connect(function() {
                const ids = Object.assign({}, root.previewIds)
                vp.stdout.text.trim().split(/\s+/).forEach(id => { if (id) ids[id] = true })
                root.previewIds = ids
                vp.destroy()
            })
            vp.running = true
            verify.destroy()
        })
        verify.start()
    }

    // --- UI ---

    // ColumnLayout (NOT Column): the ScrollView needs Layout.fillHeight to
    // claim remaining space — in a plain Column fillHeight is ignored and
    // the grid collapses to zero height (images "not displayed").
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Tabs
        Row {
            id: tabRow
            Layout.fillWidth: true
            spacing: 4
            width: parent.width

            Repeater {
                model: root.booruApis
                delegate: Button {
                    id: apiTabBtn
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
                        color: apiTabBtn.checked ? Theme.accentBg : Theme.moduleBg
                        radius: 4
                        border.color: apiTabBtn.checked ? Theme.accent : Theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: apiTabBtn.checked ? Theme.accent : Theme.fg
                        font.pixelSize: Theme.fontSize - 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Bookmark tab
            Button {
                id: bookmarkBtn
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
                    // Load bookmarks (AGS: paginate + download previews)
                    root.loadBookmarks()
                }
                background: Rectangle {
                    color: bookmarkBtn.checked ? Theme.accentBg : Theme.moduleBg
                    radius: 4
                    border.color: bookmarkBtn.checked ? Theme.accent : Theme.border
                }
                contentItem: Text {
                    text: parent.text
                    color: bookmarkBtn.checked ? Theme.accent : Theme.fg
                    font.pixelSize: Theme.fontSize - 2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Pins tab
            Button {
                id: pinsBtn
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
                    // Load pins (AGS: paginate + download previews)
                    root.loadPins()
                }
                background: Rectangle {
                    color: pinsBtn.checked ? Theme.accentBg : Theme.moduleBg
                    radius: 4
                    border.color: pinsBtn.checked ? Theme.accent : Theme.border
                }
                contentItem: Text {
                    text: parent.text
                    color: pinsBtn.checked ? Theme.accent : Theme.fg
                    font.pixelSize: Theme.fontSize - 2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

    // --- grid (Flickable + masonry Row live in the ColumnLayout below) ---

        // Image masonry grid (Flickable: ScrollView hides contentY, and AGS
        // scrolls to top after every page transition)
        Flickable {
            id: gridScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: masonryRow.height
            ScrollBar.vertical: ScrollBar {}

            // Masonry row: N shortest-column Columns (AGS algorithm above)
            Row {
                id: masonryRow
                width: parent.width
                spacing: 6

                // Slide transition on page change (AGS Gtk.Stack
                // SLIDE_LEFT/RIGHT + scroll-to-top after transition)
                NumberAnimation { id: slideAnim; target: masonryRow; property: "x"; duration: 200; to: 0 }

                Repeater {
                    model: root.masonryColumns
                    delegate: Column {
                        required property var modelData
                        property var columnItems: modelData
                        width: (masonryRow.width - (root.columns - 1) * 6) / root.columns
                        spacing: 6
                        Repeater {
                            model: parent.columnItems
                            delegate: imgCardComp
                        }
                    }
                }
            }
        }

    // Grid card extracted as a Component so the masonry column Repeaters can
    // instantiate it (AGS image.renderAsImageDialog per grid item).
    Component {
        id: imgCardComp
        Rectangle {
            id: imgCard
            required property var modelData
            property bool isVideo: ["mp4", "webm", "mkv", "gif", "zip"]
                .includes((modelData.extension || "").toLowerCase())

            width: parent ? parent.width : 0
            height: modelData.width && modelData.height
                ? Math.max(80, width * modelData.height / modelData.width)
                : width

                        color: Theme.moduleBg
                        radius: 6
                        border.width: 1
                        border.color: Theme.border
                        clip: true

                        // Preview image (or placeholder). AGS renders the
                        // downloaded local preview; prefer the local file once
                        // cached instead of re-downloading the remote URL.
                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            fillMode: Image.PreserveAspectFit
                            source: root.gridSource(modelData)
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
                            id: imgMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    // Right-click: set as waifu (AGS renderAsWaifuWidget)
                                    Settings.waifu = modelData
                                    Settings.persist()
                                } else {
                                    // Left-click: open full AGS-style image dialog
                                    root.dialogImage = modelData
                                }
                            }
                        }

                        // Pinned / bookmarked / waifu badges (AGS info icons)
                        Rectangle {
                            anchors.top: imgCard.top
                            anchors.left: imgCard.left
                            anchors.margins: 6
                            height: 16; width: infoBadges.implicitWidth + 8
                            radius: 8; color: Theme.accent
                            visible: root.isInfoTagged(modelData)
                            Row {
                                id: infoBadges
                                anchors.centerIn: parent
                                spacing: 3
                                Text { text: root.isPinned(modelData) ? "\u{f96c}" : "\u{f02e}"; color: "white"; font.pixelSize: 9 }
                                Text { text: root.isCurrentWaifu(modelData) ? "\u{f004}" : ""; color: "white"; font.pixelSize: 9 }
                            }
                        }

                        ToolTip.visible: imgMa.containsMouse
                        ToolTip.text: `Click to Open\nID: ${modelData.id}  ${modelData.width}x${modelData.height}\nRight-click: Set as waifu`
                    }
                }

        // Bottom bar: navigation + revealable settings
        Column {
            Layout.fillWidth: true
            width: parent.width
            spacing: 4

            // Loading/error/success progress indicator (AGS Progress component)
            Rectangle {
                width: parent.width
                height: root.progressStatus === "idle" ? 0 : 4
                radius: 2
                color: root.progressStatus === "loading" ? Theme.accent
                      : root.progressStatus === "error" ? Theme.danger : "transparent"
                visible: root.progressStatus !== "idle" && root.progressStatus !== "success"
                Behavior on height { NumberAnimation { duration: 150 } }
            }

            // Page number navigation bar (AGS PageDisplay)
            Flow {
                id: pageBar
                width: parent.width
                height: 28
                spacing: 4
                anchors.horizontalCenter: parent.horizontalCenter

                // First-page button + ellipsis when page > 3 (AGS logic)
                Repeater {
                    model: root.buildPageButtons()
                    delegate: Button {
                        readonly property var modelDataObj: modelData  // {label, active}
                        text: modelData.label
                        width: modelData.active ? 40 : 28
                        height: 28
                        enabled: root.progressStatus !== "loading"
                        font.pixelSize: Theme.fontSize - 2
                        onClicked: root.gotoPage(modelData.page)
                        background: Rectangle {
                            color: modelData.active ? Theme.accentBg : Theme.moduleBg
                            radius: 4
                            border.color: modelData.active ? Theme.accent : Theme.border
                        }
                        contentItem: Text {
                            text: modelData.label
                            color: modelData.active ? Theme.accent : Theme.fg
                            font.pixelSize: Theme.fontSize - 2
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // Navigation row (prev / reveal / next)
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
                        text: parent.text
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
                        text: parent.text
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
                        text: parent.text
                        color: Theme.fg; font.pixelSize: Theme.fontSize; anchors.centerIn: parent
                    }
                }

                Text {
                    id: pageLabel
                    text: "Page " + root.page
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 1
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    id: navSpacer
                    height: 1
                    width: Math.max(0, parent.width - 96 - pageLabel.width - statusLabel.width - 40)
                }

                Text {
                    id: statusLabel
                    text: root.progressStatus
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize - 2
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
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
                            from: 0; to: 100; stepSize: 10
                            value: root.limit
                            Layout.fillWidth: true
                            onValueChanged: {
                                root.limit = Math.round(limitSlider.value)
                                Settings.booru.limit = root.limit
                                Settings.updateSetting("booru.limit", root.limit)
                                // AGS LimitDisplay setValue triggers fetchImages (debounced 300ms)
                                root._limitDebounce.restart()
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
                            from: 1; to: 5; stepSize: 1
                            value: root.columns
                            Layout.fillWidth: true
                            onValueChanged: {
                                root.columns = Math.round(columnsSlider.value)
                                Settings.booru.columns = root.columns
                                Settings.updateSetting("booru.columns", root.columns)
                                // AGS ColumnDisplay setValue triggers fetchImages (debounced 300ms)
                                root._limitDebounce.restart()
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
                                model: root.currentTags
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
                                                let newTags = root.currentTags.filter(t => !t.match(/[-]rating:explicit|rating:explicit/))
                                                newTags.unshift(newRating)
                                                root.currentTags = newTags
                                                Settings.booru.tags = newTags
                                                Settings.updateSetting("booru.tags", newTags)
                                            } else {
                                                // AGS: remove tag, refetch
                                                const newTags = root.currentTags.filter(t => t !== modelData)
                                                root.currentTags = newTags
                                                Settings.booru.tags = newTags
                                                Settings.updateSetting("booru.tags", newTags)
                                            }
                                            // AGS refetches except in Bookmarks/Pins tabs
                                            if (root.selectedTab !== "Bookmarks" && root.selectedTab !== "Pins") {
                                                root.fetchImages()
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
                                contentItem: Text { text: parent.text; color: Theme.fgDim; font.pixelSize: Theme.fontSize - 2; anchors.centerIn: parent }
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
                                    contentItem: Text { text: parent.text; color: Theme.fgDim; font.pixelSize: Theme.fontSize - 2; anchors.centerIn: parent }
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
        const apiUser = Settings.apiKey(apiValue, "user")
        const apiPass = Settings.apiKey(apiValue, "key")
        let cmd = ["python", root.booruScript, "--api", apiValue, "--tag", tag]
        if (apiUser !== "" && apiPass !== "") {
            cmd.push("--api-user", apiUser, "--api-key", apiPass)
        }
        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + ' }',
            root
        )
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        proc.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        proc.running = true
        proc.stdout.onStreamFinished.connect(function() {
            const text = proc.stdout.text
            try {
                if (text && text.trim().startsWith("[")) {
                    const data = JSON.parse(text)
                    root.fetchedTags = data.slice(0, 10)
                } else {
                    // Surface script errors (stderr envelope) instead of
                    // silently clearing suggestions
                    const errText = (proc.stderr.text || "").trim()
                    if (errText) console.warn("[Booru] fetchTags failed: " + errText.slice(0, 200))
                    root.fetchedTags = []
                }
            } catch (e) {
                root.fetchedTags = []
            }
            proc.destroy()
        })
    }

    // Build page-number buttons with AGS PageDisplay logic:
    // show "1 ..." if page > 3, then a window of ~(width/100+2) pages;
    // current page labelled with refresh glyph, others with the number.
    function buildPageButtons() {
        const buttons = []
        const totalPagesToShow = Math.floor(root.widgetWidth / 100) + 2
        const current = root.page
        if (current > 3) {
            buttons.push({ label: "1", page: 1, active: false })
            buttons.push({ label: "...", page: -1, active: false })
        }
        let startPage = Math.max(1, current - Math.floor(totalPagesToShow / 2))
        let endPage = startPage + totalPagesToShow - 1
        if (endPage - startPage + 1 < totalPagesToShow) endPage = startPage + totalPagesToShow - 1
        for (let p = startPage; p <= endPage; p++) {
            buttons.push({ label: p === current ? "\u{F021}" : String(p), page: p, active: p === current })
        }
        return buttons
    }

    // Local tabs (AGS: paginate local list with (page-1)*limit offset)
    function pagedSlice(list) {
        if (!(root.limit > 0)) return list
        const startIndex = (Math.max(1, root.page) - 1) * root.limit
        return list.slice(startIndex, startIndex + root.limit)
    }

    function loadBookmarks() {
        const bookmarks = Settings.booru.bookmarks || []
        root.images = root.pagedSlice(bookmarks).map(b => root.clonify(b))
        root.downloadPreviews(root.images)
        root.progressStatus = "success"
    }

    function loadPins() {
        const pins = Settings.booru.pins || []
        root.images = root.pagedSlice(pins).map(p => root.clonify(p))
        root.downloadPreviews(root.images)
        root.progressStatus = "success"
    }

    function loadLocalTab() {
        if (root.selectedTab === "Bookmarks") { root.loadBookmarks(); return true }
        if (root.selectedTab === "Pins") { root.loadPins(); return true }
        return false
    }

    function gotoPage(p) {
        if (p < 1 || p === root.page) return
        root.pageDirection = p > root.page ? "next" : "prev"
        root.page = p
        Settings.booru.page = p
        Settings.updateSetting("booru.page", p)
        if (!root.loadLocalTab()) root.fetchImages()
    }

    // Initial fetch on load
    Component.onCompleted: {
        ensureRatingTagFirst()
        const savedTab = Settings.booru.selectedTab || Settings.booru.api.name
        root.selectedTab = savedTab
        root.calculateCacheSize()
        root.fetchImages()
    }

    // ═══════════════════════════════════════════════════════════════
    // Import dialog — full AGS-style image preview (renderAsImageDialog)
    // ═══════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: root.dialogImage !== null
        z: 100

        // dimmer — close on click
        MouseArea { anchors.fill: parent; onClicked: root.dialogImage = null }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 24, 560)
            height: Math.min(parent.height - 24, Math.max(400, dialogMedia.height + dialogBottom.height + 60))
            radius: Theme.radius
            color: Theme.backgroundSecondary

            Column {
                id: dialogInner
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 8

                // media (image / video-placeholder / zip-placeholder)
                Rectangle {
                    id: dialogMedia
                    width: parent.width
                    height: 340
                    radius: 6
                    color: Theme.bg
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: root.dialogImage ? root.imageFileUrl(root.dialogImage) : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: parent.width
                        asynchronous: true
                        visible: root.dialogImage ? !root.isVideo(root.dialogImage) : false
                    }
                    // video downloaded → playable via QtMultimedia (AGS Video.tsx)
                    MediaVideo {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: root.dialogImage ? root.imageFileUrl(root.dialogImage).replace(/^file:\/\//, "") : ""
                        autoplay: true
                        loop: true
                        fill: true
                        visible: root.dialogImage ? root.isVideo(root.dialogImage) && root.isDownloaded(root.dialogImage) && (root.dialogImage.extension||"").toLowerCase() !== "zip" : false
                    }
                    // video not downloaded → placeholder
                    Rectangle {
                        anchors.fill: parent
                        visible: root.dialogImage ? root.isVideo(root.dialogImage) && !root.isDownloaded(root.dialogImage) : false
                        color: "black"
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\u{f03d}"; font.pixelSize: 48; color: Theme.fgDim }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.dialogImage && (root.dialogImage.extension||"").toLowerCase()==="zip" ? "This type of file cannot be played." : "Video — download to play"; color: Theme.fgDim; font.pixelSize: 12 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Open in browser to view media."; color: Theme.fgDim; font.pixelSize: 11 }
                        }
                    }
                    // download progress overlay
                    BusyIndicator {
                        anchors.centerIn: parent
                        running: root.progressStatus === "loading"
                        visible: running
                    }
                    // zoom-to-full on click
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openInBrowser(root.dialogImage)
                    }
                }

                // caption bar: id + dimensions
                Row {
                    width: parent.width
                    spacing: 6
                    Text { text: "ID: " + (root.dialogImage ? root.dialogImage.id : ""); color: Theme.fg; font.pixelSize: 11; font.bold: true }
                    Text { text: root.dialogImage ? `${root.dialogImage.width}x${root.dialogImage.height}` : ""; color: Theme.fgDim; font.pixelSize: 11 }
                    Text { text: root.dialogImage && root.isDownloaded(root.dialogImage) ? "  \u{f019} Downloaded" : ""; color: "lightgreen"; font.pixelSize: 11 }
                }

                // tags flow
                Flow {
                    id: tagFlow
                    width: parent.width
                    height: 68
                    spacing: 4
                    clip: true
                    Repeater {
                        model: root.dialogImage && root.dialogImage.tags ? root.dialogImage.tags.slice(0, 8) : []
                        delegate: Rectangle {
                            width: tagDetail.implicitWidth + 12
                            height: 20
                            radius: 10
                            color: tagDetailMa.containsMouse ? Theme.accentBg : Theme.moduleBg
                            Text {
                                id: tagDetail
                                anchors.centerIn: parent
                                text: modelData
                                color: Theme.fgDim
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: tagDetailMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyTag(modelData)
                                onPressAndHold: root.openTags(modelData)
                            }
                        }
                    }
                }

                // action rows
                Column {
                    id: dialogBottom
                    width: parent.width
                    spacing: 4

                    Row {
                        width: parent.width
                        spacing: 6
                        Button { text: "\u{f31b} Browser"; Layout.fillWidth: true; onClicked: root.openInBrowser(root.dialogImage) }
                        Button {
                            text: (root.isBookmarked(root.dialogImage) ? "\u{f02e} Unbookmark" : "\u{f02e} Bookmark")
                            Layout.fillWidth: true
                            onClicked: root.toggleBookmark(root.dialogImage)
                        }
                        Button {
                            text: (root.isPinned(root.dialogImage) ? "\u{f96c} Unpin" : "\u{f96c} Pin")
                            Layout.fillWidth: true
                            onClicked: root.togglePinned(root.dialogImage)
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 6
                        Button {
                            text: "\u{f019} Download"
                            Layout.fillWidth: true
                            enabled: !root.isDownloaded(root.dialogImage)
                            onClicked: root.downloadImage(root.dialogImage)
                        }
                        Button {
                            text: (root.isCurrentWaifu(root.dialogImage) ? "\u{f004} Current waifu" : "\u{f004} Set waifu")
                            Layout.fillWidth: true
                            onClicked: root.setAsWaifu(root.dialogImage)
                        }
                        Button {
                            text: "\u{f05e} Close"
                            Layout.fillWidth: true
                            onClicked: root.dialogImage = null
                        }
                    }
                }
            }
        }

        Keys.onEscapePressed: root.dialogImage = null
        Keys.onEnterPressed: root.dialogImage = null
        focus: visible
    }
}
