import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "components/BooruUtils.js" as BooruUtils
import qs.services
import qs.theme
import qs.widgets.leftPanel.BooruViewer.components as Booru
import qs.widgets.media
import qs.widgets.shared

// Booru Viewer widget — port of widgets/leftPanel/components/BooruViewer.tsx
// Features: multiple API tabs (Danbooru/Gelbooru/Safebooru), bookmarks, pins,
// tag search, masonry grid, pagination (keyboard nav), revealable settings
// (limit/columns/tags/cache-clear), preview download via booru.py.
Item {
    // set to an image object to open the dialog
    // --- helpers ---
    // --- UI ---

    id: root

    property int widgetWidth: parent.width
    property string className: ""
    readonly property string booruPath: `${Quickshell.env("HOME")}/.cache/quickshell/booru`
    readonly property string booruScript: `${Quickshell.env("HOME")}/.config/ags/scripts/booru.py`
    // --- state (per-instance, not singleton) ---
    property var images: []
    // fetched image objects
    property bool _firstImages: true
    // AGS createImagesContent masonry: distribute to the shortest column by
    // aspect ratio (NOT row-by-row Flow). NOTE: must live on root — a
    // property declared among ColumnLayout children belongs to the layout.
    readonly property var masonryColumns: {
        const imgs = root.images || [];
        const n = Math.max(1, root.columns);
        const cols = [];
        for (let i = 0; i < n; i++) cols.push({
            "h": 0,
            "items": []
        })
        for (const im of imgs) {
            const ratio = (im.width && im.height) ? im.height / im.width : 1;
            let t = cols[0];
            for (const c of cols) if (c.h < t.h) {
                t = c;
            }
            t.items.push(im);
            t.h += ratio;
        }
        return cols.map((c) => {
            return c.items;
        });
    }
    property string progressStatus: "idle" // "loading" | "error" | "success" | "idle"
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
    property var dialogImage: null
    // Grid width frozen at the moment the revealer opens: while open the
    // grid keeps this exact width (zero relayout/image rescaling) and only
    // the revealer + outer panel resize. Pure capture — no Settings writes.
    property real _gridWidth: 0
    // Revealer visibility lags dialogImage on close so the slide-out
    // animation finishes before content unmounts + panel snaps back.
    property bool _detailVisible: false
    property real detailW: 0
    Behavior on detailW { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    on_DetailVisibleChanged: {
        root.detailW = root._detailVisible ? 210 : 0;
    }
    function requestClose() {
        if (root.dialogImage === null && !root._detailVisible)
            return ;
        root._detailVisible = false;
        _closeTimer.restart();
    }
    Timer {
        id: _closeTimer
        interval: 190
        repeat: false
        onTriggered: {
            root.dialogImage = null;
        }
    }
    onDialogImageChanged: {
        if (root.dialogImage !== null) {
            _closeTimer.stop();
            root._gridWidth = grid.width;
            root._detailVisible = true;
        }
    }
    // Downloaded set: populated by downloadImage()'s completion poller (avoids
    // needing a synchronous filesystem-exists primitive in QML).
    property var downloadedIds: ({
    })
    // forces dialog overlay to recompute toggle states after downloads
    property int dialogVersion: 0
    property bool bottomRevealed: false
    property bool keyEnabled: true
    property Timer _limitDebounce
    readonly property var booruApis: [{
        "name": "Danbooru",
        "value": "danbooru",
        "url": "https://danbooru.donmai.us/",
        "idSearchUrl": "https://danbooru.donmai.us/posts/"
    }, {
        "name": "Gelbooru",
        "value": "gelbooru",
        "url": "https://gelbooru.com/",
        "idSearchUrl": "https://gelbooru.com/index.php?page=post&s=view&id="
    }, {
        "name": "Safebooru",
        "value": "safebooru",
        "url": "https://safebooru.donmai.us/",
        "idSearchUrl": "https://safebooru.donmai.us/posts/"
    }]
    // The currently selected API object (for preview path resolution in bookmark/pin tabs)
    readonly property var currentApiObj: {
        const v = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        return root.booruApis.find((a) => {
            return a.value === v;
        }) || root.booruApis[0];
    }
    // Local preview-file ids verified present on disk. Grid prefers these
    // (AGS renders the downloaded local preview via getPreviewPath()).
    property var previewIds: ({
    })

    // --------- helpers for image dialog (mirror BooruImage.class) ---------
    function getIconPath(img, which) {
        return BooruUtils.getIconPath(root.booruPath, img, which);
    }

    function apiOf(img) {
        return BooruUtils.apiOf(img);
    }

    function isInArray(arr, img) {
        return BooruUtils.isInArray(arr, img);
    }

    function isBookmarked(img) {
        return root.isInArray(Settings.booru.bookmarks, img);
    }

    function isPinned(img) {
        return root.isInArray(Settings.booru.pins, img);
    }

    function isCurrentWaifu(img) {
        const w = Settings.waifu;
        return w && (String(w.id) === String(img.id));
    }

    function isInfoTagged(img) {
        return root.isPinned(img) || root.isBookmarked(img) || root.isCurrentWaifu(img);
    }

    function isVideo(img) {
        // AGS isVideo = mp4/webm/mkv/gif; zip is a separate isZip with its
        // own placeholder (dialog special-cases it below)
        return ["mp4", "webm", "mkv", "gif"].includes((img.extension || "").toLowerCase());
    }

    function isDownloaded(img) {
        return !!img && !!root.downloadedIds[String(img.id)];
    }

    function imageFileUrl(img) {
        return BooruUtils.imageFileUrl(root.booruPath, root.downloadedIds, img);
    }

    function openInBrowser(img) {
        const base = img.api.idSearchUrl || "https://danbooru.donmai.us/posts/";
        Quickshell.execDetached(["xdg-open", base + img.id]);
    }

    // AGS BooruImage.toggleBookmark: goes through booru.py toggle-bookmark
    // (validates payload, syncs the shared settings.json) instead of mutating
    // local state. Flush pending persists first so the script's
    // read-modify-write doesn't race a debounced write.
    function toggleBookmark(img) {
        if (!img || typeof img.id !== "number" || !root.apiOf(img)) {
            Notifications.notify({
                "summary": "Error updating bookmark",
                "body": "Invalid image data."
            });
            return root.isBookmarked(img);
        }
        Settings.persist();
        const payload = JSON.stringify({
            "bookmark": img
        });
        const p = bookmarkProc.createObject(root);
        p.command = ["python", root.booruScript, "--action", "toggle-bookmark", "--payload-json", payload];
        p.running = true;
        return !root.isBookmarked(img); // optimistic; corrected on response
    }

    function onBookmarkToggled(exitOk, stdoutText) {
        // File already written by the script — no persist needed.

        if (!exitOk) {
            Notifications.notify({
                "summary": "Error updating bookmark",
                "body": "Bookmark script failed."
            });
            return ;
        }
        try {
            const parsed = JSON.parse((stdoutText || "").trim());
            const marked = parsed.bookmarked === true;
            if (Array.isArray(parsed.bookmarks)) {
                Settings.booru.bookmarks = parsed.bookmarks;
                Settings.booru = Settings.booru; // touch: nested assign must emit
            } else {
                Settings.reload();
            }
            Notifications.notify({
                "summary": "Success",
                "body": marked ? "Image bookmarked" : "Bookmark removed"
            });
            if (root.selectedTab === "Bookmarks")
                root.loadBookmarks();

        } catch (e) {
            Settings.reload();
            Notifications.notify({
                "summary": "Error updating bookmark",
                "body": "Invalid bookmark response."
            });
        }
    }

    function togglePinned(img) {
        const arr = (Settings.booru.pins || []).slice();
        const i = arr.findIndex((x) => {
            return x && String(x.id) === String(img.id) && root.apiOf(x) === root.apiOf(img);
        });
        if (i >= 0)
            arr.splice(i, 1);
        else
            arr.push(img);
        Settings.booru.pins = arr;
        Settings.booru = Settings.booru; // touch parent var (see above)
        Settings.schedulePersist();
        FastfetchPins.scheduleSync();
        return i < 0;
    }

    function downloadImage(img) {
        root.progressStatus = "loading";
        const dir = `${root.booruPath}/${img.api.value}/images`;
        const target = `${dir}/${img.id}.${img.extension}`;
        Quickshell.execDetached(["bash", "-c", `mkdir -p '${dir}' && curl -sL -o '${target}' '${img.url}'`]);
        // poll for a non-empty file to appear (network fetch may take time)
        const poll = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Timer { interval: 1200; repeat: true; ' + 'property var check: null }', root);
        poll.triggered.connect(function() {
            if (poll.check && poll.check.running)
                return ;

            // one check at a time
            poll.check = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
            const targetJson = JSON.stringify(target);
            poll.check.command = ["bash", "-c", `[ -s ${targetJson} ] && echo yes`];
            const p = poll.check;
            p.running = true;
            p.stdout.onStreamFinished.connect(function() {
                if (p.stdout.text.trim() === "yes") {
                    poll.stop();
                    poll.destroy();
                    const ids = root.downloadedIds;
                    ids[String(img.id)] = true;
                    root.downloadedIds = ids;
                    root.progressStatus = "success";
                    root.dialogVersion++;
                }
                p.destroy();
                poll.check = null;
            });
        });
        poll.start();
    }

    function setAsWaifu(img) {
        Settings.waifu = img;
        Settings.schedulePersist();
    }

    function openTags(tag) {
        root.currentTags = [tag];
        root.page = 1;
        root.fetchImages();
    }

    function copyTag(tag) {
        Quickshell.execDetached(["bash", "-c", "echo -n '" + tag + "' | wl-copy"]);
    }

    function formatTagForDisplay(tag) {
        return tag;
    }

    // Manual property copy (QML JS has no object-spread `{...obj}`). AGS
    // parity (BooruViewer.tsx:219-221 via new BooruImage(b)): preserve the
    // item's own stored api so cross-API bookmarks/pins resolve to the right
    // preview dir and idSearchUrl — never overwrite with the current tab.
    function clonify(img) {
        return BooruUtils.clonify(img, root.currentApiObj);
    }

    function ensureRatingTagFirst() {
        // Find existing rating tag, remove it, re-add at front (or default -rating:explicit)
        let tags = root.currentTags.slice();
        const ratingTag = tags.find((t) => {
            return t.match(/[-]rating:explicit|rating:explicit/);
        });
        tags = tags.filter((t) => {
            return !t.match(/[-]rating:explicit|rating:explicit/);
        });
        tags.unshift(ratingTag ?? "-rating:explicit");
        root.currentTags = tags;
        Settings.booru.tags = tags;
        Settings.updateSetting("booru.tags", tags);
    }

    function calculateCacheSize() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        proc.command = ["bash", "-c", "du -sb " + JSON.stringify(root.booruPath + '/' + apiValue + '/previews') + " 2>/dev/null | cut -f1"];
        proc.stdout.onStreamFinished.connect(function() {
            const bytes = parseInt(proc.stdout.text.trim()) || 0;
            root.cacheSize = Math.round(bytes / (1024 * 1024)) + "mb";
            proc.destroy();
        });
        proc.running = true;
    }

    function cleanCache() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        Quickshell.execDetached(["bash", "-c", `rm -rf '${root.booruPath}/${apiValue}/previews/*' '${root.booruPath}/${apiValue}/images/*'`]);
        root.calculateCacheSize();
    }

    function fetchImages() {
        root.progressStatus = "loading";
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const apiObj = root.booruApis.find((a) => {
            return a.value === apiValue;
        }) || root.booruApis[0];
        const tagsStr = root.currentTags.join(",");
        const currentPage = Math.max(1, root.page);
        const startIndex = root.limit > 0 ? (currentPage - 1) * root.limit : 0;
        // Build command
        let cmd = ["python", root.booruScript, "--api", apiValue, "--tags", tagsStr, "--limit", String(root.limit), "--page", String(currentPage)];
        // Add API credentials if available (AGS: credentials.user.value /
        // credentials.key.value; Settings.apiKey unwraps either shape and
        // falls back to the shipped public defaults)
        const apiUser = Settings.apiKey(apiValue, "user");
        const apiPass = Settings.apiKey(apiValue, "key");
        if (apiUser !== "" && apiPass !== "")
            cmd.push("--api-user", apiUser, "--api-key", apiPass);

        const cmdJson = JSON.stringify(cmd);
        root.lastFetchCmd = JSON.stringify(cmd.map((a, i) => {
            return (a === "--api-key" || a === "--api-user") ? a : (cmd[i - 1] === "--api-key" || cmd[i - 1] === "--api-user" ? "***" : a);
        }));
        root.lastFetchError = "";
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ' + cmdJson + ' }', root);
        // Collectors must be attached before running (never after), and
        // inline `stderr:` is rejected by the QML parser — assign here.
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        proc.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        proc.running = true;
        // NOTE: read streams on process exit, NOT on stdout.onStreamFinished:
        // stderr may not have flushed when stdout closes, which hid the
        // script's real error envelope (empty stderr reads).
        proc.exited.connect(function(exitCode, exitStatus) {
            const text = proc.stdout.text;
            // booru.py emit_error() writes to STDERR with empty stdout, so a
            // credential rejection would otherwise surface as a generic error.
            const errText = proc.stderr.text;
            if ((!text || !text.trim()) && errText && errText.trim()) {
                root.progressStatus = "error";
                let msg = errText.trim().slice(0, 300);
                try {
                    const ej = JSON.parse(errText.trim());
                    if (ej && ej.message)
                        msg = String(ej.message);

                } catch (e) {
                }
                Notifications.notify({
                    "summary": "Booru error",
                    "body": msg
                });
                proc.destroy();
                return ;
            }
            // AGS parseBooruArrayResponse: surface the script's error envelope
            // message (e.g. missing API credentials) instead of a generic error
            let parsed = null;
            try {
                parsed = text && text.trim() ? JSON.parse(text) : null;
            } catch (e) {
                parsed = null;
            }
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed) && parsed.error === true) {
                root.progressStatus = "error";
                const msg = (parsed.message && String(parsed.message).trim()) || "Unknown booru error";
                Notifications.notify({
                    "summary": "Booru error",
                    "body": msg
                });
                proc.destroy();
                return ;
            }
            if (!Array.isArray(parsed)) {
                root.progressStatus = "error";
                // AGS notifies per-tab error (bookmarks/pins/images)
                const tab = root.selectedTab;
                const summary = tab === "Bookmarks" ? "Error loading bookmarks" : tab === "Pins" ? "Error loading pins" : "Error fetching images";
                const body = tab === "Bookmarks" ? "Failed to load bookmarks" : tab === "Pins" ? "Failed to load pins" : "Failed to fetch images";
                const detail = text && text.trim() ? text.trim().slice(0, 200) : body;
                root.lastFetchError = "stdout[" + (text ? text.trim().slice(0, 200) : "<empty>") + "] stderr[" + (errText ? errText.slice(0, 200) : "<empty>") + "]";
                Notifications.notify({
                    "summary": summary,
                    "body": detail
                });
                proc.destroy();
                return ;
            }
            try {
                const data = parsed;
                root.images = data.map((img) => {
                    return ({
                        "id": img.id || 0,
                        "width": img.width || 0,
                        "height": img.height || 0,
                        "api": apiObj,
                        "tags": img.tags || [],
                        "extension": img.extension,
                        "url": img.url,
                        "preview": img.preview
                    });
                });
                root.calculateCacheSize();
                root.progressStatus = "success";
                // Download previews for the NEW images (was previously called
                // on the stale list before the fetch completed)
                root.downloadPreviews(root.images);
            } catch (e) {
                root.progressStatus = "error";
                Notifications.notify({
                    "summary": "Error fetching images",
                    "body": String(e)
                });
            }
            proc.destroy();
        });
    }

    function isPreviewCached(img) {
        return !!img && !!root.previewIds[String(img.id)];
    }

    // Grid source: full image file if downloaded, else cached preview file,
    // else the remote preview URL.
    function gridSource(img) {
        return BooruUtils.gridSource(root.booruPath, root.downloadedIds, root.previewIds, img);
    }

    function downloadPreviews(imgList) {
        const pending = [];
        imgList.forEach((img) => {
            const previewDir = `${root.booruPath}/${img.api.value}/previews`;
            const filePath = `${previewDir}/${img.id}.${img.extension}`;
            const previewUrl = img.preview;
            if (!previewUrl)
                return ;

            pending.push({
                "id": String(img.id),
                "path": filePath
            });
            // Check if file exists, download if not. NOTE: the stdout
            // collector must be attached in the constructor — setting
            // running=true before assigning stdout races and drops output.
            const checkProc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
            checkProc.command = ["bash", "-c", "test -f " + JSON.stringify(filePath) + " && echo yes || echo no"];
            checkProc.stdout.onStreamFinished.connect(function() {
                if (checkProc.stdout.text.trim() === "no") {
                    Quickshell.execDetached(["bash", "-c", `mkdir -p \"${previewDir}\" && ` + `curl -sSf -H \"User-Agent: QuickshellBooru/1.0 (ArchLinux; Hyprland)\" ` + `-H \"Referer: ${img.api.url}\" ` + `-H \"Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8\" ` + `-o \"${filePath}\" \"${previewUrl}\"`]);
                } else {
                    const ids = Object.assign({
                    }, root.previewIds);
                    ids[String(img.id)] = true;
                    root.previewIds = ids;
                }
                checkProc.destroy();
            });
            checkProc.running = true;
        });
        // Single delayed verification pass: curls run detached, so re-check
        // the batch once and flip the grid to file:// URLs as files land.
        if (pending.length === 0)
            return ;

        const verify = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 6000 }', root);
        verify.triggered.connect(function() {
            const script = pending.map((p) => {
                return "test -s " + JSON.stringify(p.path) + " && echo " + p.id;
            }).join(" || true; ");
            const vp = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
            vp.command = ["bash", "-c", script + " || true"];
            vp.stdout.onStreamFinished.connect(function() {
                const ids = Object.assign({
                }, root.previewIds);
                vp.stdout.text.trim().split(/\s+/).forEach((id) => {
                    if (id)
                        ids[id] = true;

                });
                root.previewIds = ids;
                vp.destroy();
            });
            vp.running = true;
            verify.destroy();
        });
        verify.start();
    }

    // --- fetch tag suggestions ---
    function fetchTags(tag) {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const apiUser = Settings.apiKey(apiValue, "user");
        const apiPass = Settings.apiKey(apiValue, "key");
        let cmd = ["python", root.booruScript, "--api", apiValue, "--tag", tag];
        if (apiUser !== "" && apiPass !== "")
            cmd.push("--api-user", apiUser, "--api-key", apiPass);

        const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + ' }', root);
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        proc.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        proc.running = true;
        proc.stdout.onStreamFinished.connect(function() {
            const text = proc.stdout.text;
            try {
                if (text && text.trim().startsWith("[")) {
                    const data = JSON.parse(text);
                    root.fetchedTags = data.slice(0, 10);
                } else {
                    // Surface script errors (stderr envelope) instead of
                    // silently clearing suggestions
                    const errText = (proc.stderr.text || "").trim();
                    if (errText)
                        console.warn("[Booru] fetchTags failed: " + errText.slice(0, 200));

                    root.fetchedTags = [];
                }
            } catch (e) {
                root.fetchedTags = [];
            }
            proc.destroy();
        });
    }

    // Build page-number buttons with AGS PageDisplay logic:
    // show "1 ..." if page > 3, then a window of ~(width/100+2) pages;
    // current page labelled with refresh glyph, others with the number.
    function buildPageButtons() {
        return BooruUtils.buildPageButtons(root.widgetWidth, root.page);
    }

    // Local tabs (AGS: paginate local list with (page-1)*limit offset)
    function pagedSlice(list) {
        return BooruUtils.pagedSlice(list, root.limit, root.page);
    }

    function loadBookmarks() {
        const bookmarks = Settings.booru.bookmarks || [];
        root.images = root.pagedSlice(bookmarks).map((b) => {
            return root.clonify(b);
        });
        root.downloadPreviews(root.images);
        root.progressStatus = "success";
    }

    function loadPins() {
        const pins = Settings.booru.pins || [];
        root.images = root.pagedSlice(pins).map((p) => {
            return root.clonify(p);
        });
        root.downloadPreviews(root.images);
        root.progressStatus = "success";
    }

    function loadLocalTab() {
        if (root.selectedTab === "Bookmarks") {
            root.loadBookmarks();
            return true;
        }
        if (root.selectedTab === "Pins") {
            root.loadPins();
            return true;
        }
        return false;
    }

    function gotoPage(p) {
        // AGS page buttons always fetchImages() — same-page click refreshes.
        if (p < 1)
            return ;

        if (p !== root.page) {
            root.pageDirection = p > root.page ? "next" : "prev";
            root.page = p;
            Settings.booru.page = p;
            Settings.updateSetting("booru.page", p);
        }
        if (!root.loadLocalTab())
            root.fetchImages();

    }

    // AGS Images subscribe: slide new page in from the travel direction,
    // scroll to top; first render appears without transition.
    onImagesChanged: {
        grid.resetScroll();
        if (root._firstImages) {
            root._firstImages = false;
            return ;
        }
        grid.slideFrom(root.pageDirection === "next" ? 60 : -60);
    }
    // Initial fetch on load (AGS fetchImages branches to bookmarks/pins/API
    // from the restored tab — saved Bookmarks/Pins must not fetch the API)
    Component.onCompleted: {
        ensureRatingTagFirst();
        const savedTab = Settings.booru.selectedTab || Settings.booru.api.name;
        root.selectedTab = savedTab;
        root.calculateCacheSize();
        if (!root.loadLocalTab())
            root.fetchImages();

    }

    // ColumnLayout (NOT Column): the ScrollView needs Layout.fillHeight to
    // claim remaining space — in a plain Column fillHeight is ignored and
    // the grid collapses to zero height (images "not displayed").
    ColumnLayout {
        // --- grid (Flickable + masonry Row live in the ColumnLayout below) ---
        // Grid card extracted as a Component so the masonry column Repeaters can
        // instantiate it (AGS image.renderAsImageDialog per grid item).

        anchors.fill: parent
        spacing: 10

        // Tabs
        Booru.BooruToolbar {
            viewer: root
        }

        // Image masonry grid (Flickable: ScrollView hides contentY, and AGS
        // scrolls to top after every page transition) + right detail revealer
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            clip: true
            Booru.BooruGrid {
                id: grid

                viewer: root
            }
            Booru.BooruDialog {
                viewer: root
                Layout.preferredWidth: root.detailW
                Layout.fillHeight: true
                visible: root.dialogImage !== null
            }
        }

        // Backend bookmark toggle (booru.py toggle-bookmark --payload-json).
        // Stdout carries {bookmarked, bookmarks}; exit code gates the parse.
        Component {
            id: bookmarkProc

            Process {
                property string out: ""

                onExited: (code) => {
                    return root.onBookmarkToggled(code === 0, out);
                }

                stdout: StdioCollector {
                    onStreamFinished: {
                        out = text;
                    }
                }

            }

        }

        // Bottom bar: navigation + revealable settings
        Column {
            Layout.fillWidth: true
            width: parent.width
            spacing: 4

            Booru.BooruNavigation {
                viewer: root
            }

            Booru.BooruSettingsPanel {
                viewer: root
            }

        }

    }

    // --- keyboard navigation ---
    Item {
        anchors.fill: parent
        focus: true
        Keys.onUpPressed: {
            root.bottomRevealed = true;
            event.accepted = true;
        }
        Keys.onDownPressed: {
            root.bottomRevealed = false;
            event.accepted = true;
        }
        Keys.onLeftPressed: {
            if (root.keyEnabled && root.progressStatus !== "loading" && root.page > 1) {
                root.pageDirection = "prev";
                root.page = root.page - 1;
                Settings.booru.page = root.page;
                Settings.updateSetting("booru.page", root.page);
                root.fetchImages();
            }
            event.accepted = true;
        }
        Keys.onRightPressed: {
            if (root.keyEnabled && root.progressStatus !== "loading") {
                root.pageDirection = "next";
                root.page = root.page + 1;
                Settings.booru.page = root.page;
                Settings.updateSetting("booru.page", root.page);
                root.fetchImages();
            }
            event.accepted = true;
        }
    }

    _limitDebounce: Timer {
        interval: 300
        repeat: false
        onTriggered: root.fetchImages()
    }

}
