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

// Booru viewer: API tabs (Danbooru/Gelbooru/Safebooru), bookmarks, pins, tag search, masonry
// grid, keyboard pagination and preview downloads through booru.py.
Item {

    id: root

    property int widgetWidth: parent.width
    property string className: ""
    readonly property string booruPath: `${Quickshell.env("HOME")}/.cache/quickshell/booru`
    readonly property string booruScript: `${Quickshell.env("HOME")}/.config/quickshell/archeclipse/scripts/booru.py`
    // --- state (per-instance, not singleton) ---
    property var images: []
    // fetched image objects
    property bool _firstImages: true
    // Monotonic fetch sequence: rapid tag changes fire overlapping fetches and a stale
    // response must not overwrite a newer one.
    property int _fetchSeq: 0
    // Download generation: a new downloadPreviews() supersedes the previous queue, so
    // leftover tasks are dropped instead of spending bandwidth on a stale grid.
    property int _dlSeq: 0
    // Masonry: shortest-column-by-aspect-ratio distribution. Must live on root — a property
    // among ColumnLayout children belongs to the layout.
    readonly property var masonryColumns: {
        const imgs = root.images || [];
        const n = Math.max(1, root.columns);
        const cols = [];
        for (let i = 0; i < n; i++)
            cols.push({
                "h": 0,
                "items": []
            });
        for (const im of imgs) {
            const ratio = (im.width && im.height) ? im.height / im.width : 1;
            let t = cols[0];
            for (const c of cols)
                if (c.h < t.h) {
                    t = c;
                }
            t.items.push(im);
            t.h += ratio;
        }
        return cols.map(c => {
            return c.items;
        });
    }
    property string progressStatus: "idle" // "loading" | "error" | "success" | "idle"
    property string selectedTab: Settings.booru.api ? Settings.booru.api.name : "Danbooru"
    property int page: Settings.booru.page ?? 1
    property string pageDirection: "next"
    property var fetchedTags: []
    property string cacheSize: "0mb"
    property var currentTags: Settings.booru.tags ? Settings.booru.tags : ["-rating:explicit"]
    property int limit: Settings.booru.limit ? Settings.booru.limit : 100
    property int columns: Settings.booru.columns ? Settings.booru.columns : 3
    // Diagnostic: last fetch command with secrets redacted (IPC-readable)
    property string lastFetchCmd: ""
    property string lastFetchError: ""
    // Image-dialog state. The detail is a root-level overlay, so opening it resizes nothing
    // and no frozen grid widths or revealer flags exist.
    property var dialogImage: null
    // Floating-dialog anchor: viewport Y of the clicked card at open time; dialogTop follows
    // the live scroll until it leaves the viewport (auto-close).
    property real dialogAnchorCenterVy: 0
    property real dialogAnchorContentY: 0
    property real dialogAnchorH: 100
    property real dialogTop: 0
    property real dialogH: 560
    // Detached dialog: the grip moves the card into a FloatingWindow (floating is the
    // compositor's job). It outlives island close and tab switch until explicitly closed.
    property bool dialogDetached: false
    // Whether the float window was aspect-fit for the current dialog
    // session (keeps the user's resize across post swaps; reset on close).
    property bool floatSized: false
    // Hover handoff with the floating popup (a separate surface): the island stays open while
    // this is true and re-arms its hide when it clears.
    property bool popupHovered: false
    // Back-reference injected by LeftIsland (booruView.hostPanel = island).
    property var hostPanel: null
    readonly property string panelMonitorName: root.hostPanel && root.hostPanel.monitorName
        ? root.hostPanel.monitorName : Registry.monitorName
    // Reactive binding, not a one-shot onLoaded assign: the nested booru Loader can finish
    // before the island's screen arrives, which left this null and the float never visible.
    property var hostScreen: root.hostPanel && root.hostPanel.screen ? root.hostPanel.screen : null

    // Screen size for the float panel (ShellScreen logical pixels, with
    // fallbacks so clamping never divides by zero).
    function screenW() {
        try {
            const w = root.hostScreen && root.hostScreen.width;
            if (w > 0)
                return w;
        } catch (e) {}
        return 1920;
    }
    function screenH() {
        try {
            const h = root.hostScreen && root.hostScreen.height;
            if (h > 0)
                return h;
        } catch (e) {}
        return 1080;
    }
    // Post aspect for the size lock (width / height, sane fallback).
    function dialogAspect() {
        const d = root.dialogImage;
        if (d && d.width > 0 && d.height > 0)
            return d.width / d.height;
        return 3 / 4;
    }
    // Overlay entrance driver (0 parked, 1 in): slide/opacity only, so it cannot feed back
    // into the layout the way a width animation did.
    property real detailSlide: 0
    // Downloaded set, filled by fetchOriginal() when the full file lands; keys are api:id
    // because sites share numeric ids.
    property var downloadedIds: ({})
    // forces dialog overlay to recompute toggle states after downloads
    property int dialogVersion: 0
    property bool bottomRevealed: false
    property bool keyEnabled: true
    property Timer _limitDebounce
    readonly property var booruApis: [
        {
            "name": "Danbooru",
            "value": "danbooru",
            "url": "https://danbooru.donmai.us/",
            "idSearchUrl": "https://danbooru.donmai.us/posts/"
        },
        {
            "name": "Gelbooru",
            "value": "gelbooru",
            "url": "https://gelbooru.com/",
            "idSearchUrl": "https://gelbooru.com/index.php?page=post&s=view&id="
        },
        {
            "name": "Safebooru",
            "value": "safebooru",
            "url": "https://safebooru.donmai.us/",
            "idSearchUrl": "https://safebooru.donmai.us/posts/"
        }
    ]
    // The currently selected API object (for preview path resolution in bookmark/pin tabs)
    readonly property var currentApiObj: {
        const v = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        return root.booruApis.find(a => {
            return a.value === v;
        }) || root.booruApis[0];
    }
    // Local preview files verified on disk (the grid prefers them); keys are api:id — the
    // same numeric id on two sites is not the same file.
    property var previewIds: ({})
    // Cards allowed to fade in: previewIds flips as soon as a file lands, and revealedIds is
    // drained one key per tick so cards pop in sequentially instead of bursting.
    property var revealedIds: ({})

    // Bumped on every reveal mutation: isRevealed() reads it so delegate
    // bindings re-evaluate without reassigning the whole ids object.
    property int revealVersion: 0
    property int _revealIdx: 0
    property var _revealQueue: []
    // Local full-image ids verified on disk (dialog cache), keys api:id. Remote danbooru URLs
    // 403 inside Qt, so the dialog only shows files downloaded with a Referer.
    property var fullIds: ({})
    // Initial fetch, branched to bookmarks/pins/API from the restored tab. Deferred until
    // Settings.ready — booting on defaults fetched with the wrong limit and persisted them.
    property bool _booted: false
    // Dialog-host mode (waifu's private host): only floating dialogs, so the grid boot fetch
    // (network + previews + tag persistence) is skipped entirely.
    property bool dialogOnly: false
    // Pinned-dialog mode: dialogImage is bound externally (Settings.waifu), so every path that
    // would clear it becomes a no-op instead of snapping the binding.
    property bool dialogPinned: false

    // Slide-out, then unmount: the overlay glides/fades away first and
    // only then (_closeTimer) is the content dropped.
    function requestClose() {
        if (root.dialogPinned || root.dialogImage === null)
            return;

        root.detailSlide = 0;
        _closeTimer.restart();
    }

    // Immediate teardown: the detail PopupWindow is a separate surface driven only by
    // dialogImage and outlives the viewer in the cached Loader, so drop the content at once.
    function closeDialogNow() {
        if (root.dialogPinned || root.dialogImage === null)
            return;

        _closeTimer.stop();
        root.detailSlide = 0;
        // Reset to docked so the next open starts at its anchor card.
        root.dialogDetached = false;
        root.floatSized = false;
        root.dialogImage = null;
    }

    // Detach into the FloatingWindow and aspect-fit the post within the screen, once per
    // dialog session — a later user resize is left alone across post swaps.
    function detachDialog() {
        if (root.dialogDetached || root.dialogImage === null)
            return;
        // A pending slide-out close (anchor scrolled out, _closeTimer
        // armed) must not nuke the freshly detached float 190ms later.
        _closeTimer.stop();
        // Size BEFORE flipping detached (which maps the window): the surface commits its size
        // at map time, so post-map writes lose to the declared implicit defaults.
        if (!root.floatSized) {
            const sw = root.screenW(), sh = root.screenH(), a = root.dialogAspect();
            let w = Math.min(380, sw - 40);
            let h = w / a;
            if (h > sh - 40) {
                h = sh - 40;
                w = h * a;
            }
            detailFloat.implicitWidth = Math.max(240, Math.min(sw, w));
            detailFloat.implicitHeight = Math.max(200, Math.min(sh, h));
            root.floatSized = true;
        }
        root.dialogDetached = true;
    }

    // System move for the float window (called on first drag motion so
    // the window is mapped when the compositor checks the gesture).
    function moveFloat() {
        try {
            if (typeof detailFloat.startSystemMove === "function")
                detailFloat.startSystemMove();
        } catch (e) {}
    }

    // Corner resize on the float window, aspect-locked: SE drag drives width, height follows
    // the ratio, clamped to minimums and the screen. Detaches first from the docked card.
    function resizeFloat(dx, dy) {
        if (root.dialogImage === null)
            return;
        if (!root.dialogDetached)
            root.detachDialog();
        if (!root.dialogDetached)
            return;
        root.floatSized = true;
        const sw = root.screenW(), sh = root.screenH(), a = root.dialogAspect();
        const reqW = Math.max(240, Math.min(sw, detailFloat.width + dx));
        const reqH = Math.max(200, Math.min(sh, detailFloat.height + dy));
        const w = Math.max(240, Math.min(reqW, reqH * a));
        const h = Math.max(200, Math.min(reqH, w / a));
        detailFloat.implicitWidth = w;
        detailFloat.implicitHeight = h;
    }

    // Viewer hidden directly (e.g. Loader deactivated) → drop a docked
    // dialog. A detached card is its own window and stays open.
    onVisibleChanged: {
        if (!root.visible && !root.dialogDetached && !root.dialogPinned)
            root.closeDialogNow();
    }

    Component.onDestruction: {
        _closeTimer.stop();
    }

    // The host island closed → a docked card's popup would stay orphaned, so drop it. A
    // detached card is its own window and survives.
    Connections {
        target: BarState
        function onPanelStatesByMonitorChanged() {
            if (!BarState.isOpenFor("left", root.panelMonitorName) && !root.dialogDetached && !root.dialogPinned)
                root.closeDialogNow();
        }
    }

    // Tab switched away inside the island → same orphan-popup problem
    // for docked cards; detached cards survive.
    Connections {
        target: root.hostPanel
        function onSelectedWidgetChanged() {
            if (root.hostPanel && root.hostPanel.selectedWidget !== "BooruViewer" && !root.dialogDetached)
                root.closeDialogNow();
        }
    }

    // Open the overlay at the clicked card: capture its viewport center (+ scroll offset +
    // height), then set the image. Re-clicking re-anchors without unmount churn.
    function openDialog(img, card) {
        if (!img)
            return;
        try {
            const h = (card && card.height) || 100;
            const p = card ? card.mapToItem(grid, 0, 0) : null;
            root.dialogAnchorCenterVy = p ? p.y + h / 2 : grid.height / 2;
            root.dialogAnchorContentY = grid.contentY;
            root.dialogAnchorH = h;
        } catch (e) {
            root.dialogAnchorCenterVy = grid.height / 2;
            root.dialogAnchorContentY = grid.contentY;
            root.dialogAnchorH = 100;
        }
        if (root.dialogImage !== img) {
            _closeTimer.stop();
            // A detached card stays floating: the new post swaps into it
            // in place (independent-window semantics) keeping position/size.
            root.dialogImage = img;
            root.fetchOriginal(img);
        }
        root.detailSlide = 1;
        root.refreshDialogTop(-1);
    }

    // Live viewport center of the anchor card (shifts with scrolling).
    function anchorCardCenter() {
        return root.dialogAnchorCenterVy + (root.dialogAnchorContentY - grid.contentY);
    }

    function adoptDialogHeight(dh) {
        if (dh > 0)
            root.dialogH = dh;
    }

    // Per-tick follow: recompute the target Y from the scroll, dismiss when the card leaves the
    // viewport. Only dialogTop is written — a local repaint, no compositor round-trip.
    function refreshDialogTop(dh) {
        root.adoptDialogHeight(dh);
        if (root.dialogImage === null || root.dialogDetached)
            return;
        const c = root.anchorCardCenter();
        if (c < -root.dialogAnchorH / 2 || c > grid.height + root.dialogAnchorH / 2) {
            root.requestClose();
            return;
        }
        const h = root.dialogH || 560;
        const maxTop = Math.max(0, grid.height - h);
        root.dialogTop = Math.max(0, Math.min(maxTop, c - h / 2));
    }

    // Leaving the popup for anywhere but the island hides it (the island's
    // own leave path handles island->desktop; this covers popup->desktop).
    function hidePanel() {
        const h = root.hostPanel;
        if (h && typeof h.requestAutoHide === "function")
            h.requestAutoHide();
    }

    onPopupHoveredChanged: {
        if (!root.popupHovered)
            root.hidePanel();
    }

    // Island resize with the popup open moves the edge the static anchor came from: re-push
    // once the configure lands (one round-trip on a rare action, never per frame).
    onWidthChanged: {
        try {
            if (root.dialogImage !== null && detailPopup.visible && typeof detailPopup.anchor.updateAnchor === "function")
                detailPopup.anchor.updateAnchor();
        } catch (e) {
        }
    }

    // --------- helpers for image dialog (shared via BooruActions) ---------
    function getIconPath(img, which) {
        return BooruUtils.getIconPath(root.booruPath, img, which);
    }

    function apiOf(img) {
        return BooruActions.apiOf(img);
    }

    function isInArray(arr, img) {
        return BooruActions.isInArray(arr, img);
    }

    function isBookmarked(img) {
        return BooruActions.isBookmarked(img);
    }

    function isPinned(img) {
        return BooruActions.isPinned(img);
    }

    function isCurrentWaifu(img) {
        return BooruActions.isCurrentWaifu(img);
    }

    function isVideo(img) {
        return BooruActions.isVideo(img);
    }

    // Ugoira (zip) with a transcoded sample video (booru.py "sample"):
    // the zip itself is undecodable, the sample plays instead.
    function hasSampleVideo(img) {
        return BooruUtils.hasSampleVideo(img);
    }

    function isDownloaded(img) {
        return !!img && !!root.downloadedIds[BooruUtils.cacheKey(img)];
    }

    function imageFileUrl(img) {
        return BooruUtils.imageFileUrl(root.booruPath, root.downloadedIds, img);
    }

    // Dialog source: downloaded full file, else the cached original, else the cached preview
    // while fetchOriginal() runs, else "" (spinner).
    function dialogSource(img) {
        return BooruUtils.dialogSource(root.booruPath, root.downloadedIds, root.fullIds, root.previewIds, img);
    }

    // Downloads the full file into <api>/images/ with Referer+UA (Qt gets 403 without them),
    // then downloadedIds flips and Pin auto-enables. Ugoira takes its transcoded sample.
    function fetchOriginal(img) {
        if (!img || !img.url || !img.api || !img.api.value)
            return;
        // Local files (custom waifu uploads) need no download — the
        // dialog plays the path directly (see dialogSource).
        if (!/^https?:\/\//.test(img.url))
            return;
        const sampleVideo = root.hasSampleVideo(img) ? img.sample : "";
        if (!sampleVideo && BooruActions.isZip(img))
            return;
        if (root.isDownloaded(img) || root.fullIds[BooruUtils.cacheKey(img)])
            return;

        const dir = `${root.booruPath}/${img.api.value}/images`;
        const ext = sampleVideo ? BooruUtils.sampleExt(img) : img.extension;
        const filePath = `${dir}/${img.id}.${ext}`;
        // Legacy promotion is stills-only: a transcoded sample (webm/mp4)
        // must never be overwritten by a legacy .zip of the same id.
        const legacyPath = sampleVideo ? "" : `${root.booruPath}/${img.api.value}/originals/${img.id}.${img.extension}`;
        const srcUrl = sampleVideo || img.url;
        const markDone = function () {
            const key = BooruUtils.cacheKey(img);
            const ids = Object.assign({}, root.downloadedIds);
            ids[key] = true;
            root.downloadedIds = ids;
            const full = Object.assign({}, root.fullIds);
            full[key] = true;
            root.fullIds = full;
            root.dialogVersion++;
        };
        const downloadMissing = function () {
            const dl = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
            dl.command = ["bash", "-c", `mkdir -p ${JSON.stringify(dir)} && curl -sSfL --max-time 60 -H ${Settings.shQuote("User-Agent: " + Settings.userAgent("booru"))} -H ${Settings.shQuote("Referer: " + img.api.url)} -H "Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8" -o ${JSON.stringify(filePath)} ${JSON.stringify(srcUrl)} && test -s ${JSON.stringify(filePath)}`];
            dl.exited.connect(function (code) {
                if (code === 0)
                    markDone();
                dl.destroy();
            });
            dl.running = true;
        };
        const checkProc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        checkProc.command = ["bash", "-c", "test -s " + JSON.stringify(filePath) + " && echo images || " + (legacyPath !== "" ? "(test -s " + JSON.stringify(legacyPath) + " && echo legacy || echo no)" : "echo no")];
        checkProc.stdout.onStreamFinished.connect(function () {
            const res = checkProc.stdout.text.trim();
            checkProc.destroy();
            if (res === "images") {
                markDone();
            } else if (res === "legacy") {
                const cp = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
                cp.command = ["bash", "-c", `mkdir -p \"${dir}\" && cp -- ${JSON.stringify(legacyPath)} ${JSON.stringify(filePath)} && test -s ${JSON.stringify(filePath)}`];
                cp.exited.connect(function (code) {
                    if (code === 0)
                        markDone();
                    else
                        downloadMissing();
                    cp.destroy();
                });
                cp.running = true;
            } else {
                downloadMissing();
            }
        });
        checkProc.running = true;
    }

    function openInBrowser(img) {
        return BooruActions.openInBrowser(img);
    }

    function openInViewer(img) {
        return BooruActions.openInViewer(img);
    }

    // Shared bookmark service (booru.py toggle-bookmark). Refreshes the
    // local Bookmarks tab once the shared Settings update lands.
    function toggleBookmark(img) {
        const wasMarked = root.isBookmarked(img);
        BooruActions.toggleBookmark(img, function () {
            if (root.selectedTab === "Bookmarks")
                root.loadBookmarks();
        });
        return !wasMarked; // optimistic; corrected on response
    }

    function onBookmarkToggled(exitOk, stdoutText) {
        // Legacy IPC entry point: route through the shared handler, then
        // refresh the local tab like toggleBookmark() does.
        BooruActions._onBookmarkToggled(exitOk, stdoutText, function () {
            if (root.selectedTab === "Bookmarks")
                root.loadBookmarks();
        });
    }

    // Pin needs the auto-downloaded full file (fastfetch converts it), which the dialog
    // fetches on open — so the button auto-enables rather than needing a manual step.
    function togglePinned(img) {
        if (!img)
            return false;
        if (!root.isDownloaded(img) && !BooruActions.isVideo(img) && !BooruActions.isZip(img)) {
            // Auto-download is still in flight — kick it and tell the user.
            root.fetchOriginal(img);
            Notifications.notify({
                "summary": "Downloading full image",
                "body": "Pin will be available once it lands"
            });
            return false;
        }
        const wasPinned = root.isPinned(img);
        const res = BooruActions.togglePinned(img, function () {
            if (root.selectedTab === "Pins")
                root.loadPins();
        });
        // BooruActions already notified + synced; mirror the local tab refresh.
        if (res !== wasPinned && root.selectedTab === "Pins")
            root.loadPins();
        return res;
    }

    function setAsWaifu(img) {
        return BooruActions.setAsWaifu(img);
    }

    // Copy the downloaded full image into ~/.config/wallpapers/custom
    // (thumbnail included) so the Wallpaper switcher can apply it.
    function saveAsWallpaper(img) {
        return BooruActions.saveAsWallpaper(img);
    }

    // Dialog tag hold ("Hold: search"): ADD the tag to the current search instead of
    // replacing it (deduped, no-op when already present).
    function openTags(tag) {
        if (!tag)
            return;
        const cur = root.currentTags.slice();
        if (!cur.includes(tag))
            cur.push(tag);
        root.currentTags = cur;
        Settings.booru.tags = cur;
        Settings.updateSetting("booru.tags", cur);
        root.page = 1;
        Settings.booru.page = 1;
        Settings.updateSetting("booru.page", 1);
        // A dialog host has no grid: persist the tags for the main viewer, but never fetch
        // here (tag-hold from the waifu dialog must stay network-silent).
        if (!root.dialogOnly && !root.dialogPinned && root.selectedTab !== "Bookmarks" && root.selectedTab !== "Pins")
            root.fetchImages();
    }

    function copyTag(tag) {
        return BooruActions.copyTag(tag);
    }

    // Manual copy (QML JS has no object spread): preserve the item's own stored api so
    // cross-API bookmarks and pins resolve to the right preview dir — never the current tab.
    function clonify(img) {
        return BooruUtils.clonify(img, root.currentApiObj);
    }

    function ensureRatingTagFirst() {
        // Find existing rating tag, remove it, re-add at front (or default -rating:explicit)
        let tags = root.currentTags.slice();
        const ratingTag = tags.find(t => {
            return t.match(/[-]rating:explicit|rating:explicit/);
        });
        tags = tags.filter(t => {
            return !t.match(/[-]rating:explicit|rating:explicit/);
        });
        tags.unshift(ratingTag ?? "-rating:explicit");
        root.currentTags = tags;
        Settings.booru.tags = tags;
        Settings.updateSetting("booru.tags", tags);
    }

    function formatCacheSize(bytes) {
        const b = Math.max(0, parseInt(bytes) || 0);
        if (b < 1024)
            return "0kb";
        if (b < 1024 * 1024)
            return Math.round(b / 1024) + "kb";
        return (Math.round((b / (1024 * 1024)) * 10) / 10) + "mb";
    }

    function calculateCacheSize() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const base = root.booruPath + "/" + apiValue;
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        // Sum previews + images + originals (cleanCache clears all three).
        proc.command = ["bash", "-c", "du -sb " + JSON.stringify(base + "/previews") + " " + JSON.stringify(base + "/images") + " " + JSON.stringify(base + "/originals") + " 2>/dev/null | awk '{s+=$1} END {print s+0}'"];
        proc.stdout.onStreamFinished.connect(function () {
            root.cacheSize = root.formatCacheSize(proc.stdout.text.trim());
            proc.destroy();
        });
        proc.running = true;
    }

    function cleanCache() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const base = root.booruPath + "/" + apiValue;
        // Never quote the trailing /* — rm looked for a literal "*" and deleted nothing. Drop
        // whole dirs then recreate; run du only after rm finishes so the label updates.
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        proc.command = ["bash", "-c", "rm -rf " + JSON.stringify(base + "/previews") + " " + JSON.stringify(base + "/images") + " " + JSON.stringify(base + "/originals") + " && mkdir -p " + JSON.stringify(base + "/previews") + " " + JSON.stringify(base + "/images") + " " + JSON.stringify(base + "/originals") + " && du -sb " + JSON.stringify(base + "/previews") + " " + JSON.stringify(base + "/images") + " " + JSON.stringify(base + "/originals") + " 2>/dev/null | awk '{s+=$1} END {print s+0}'"];
        proc.stdout.onStreamFinished.connect(function () {
            root.cacheSize = root.formatCacheSize(proc.stdout.text.trim());
            // Drop only this API's in-memory cache flags (other sites stay warm).
            root.previewIds = BooruUtils.purgeApiKeys(root.previewIds, apiValue);
            root.downloadedIds = BooruUtils.purgeApiKeys(root.downloadedIds, apiValue);
            root.fullIds = BooruUtils.purgeApiKeys(root.fullIds, apiValue);
            root.resetReveal();
            proc.destroy();
            // Re-fetch previews for the current page if we still have results.
            if (root.images && root.images.length > 0)
                root.downloadPreviews(root.images);
        });
        proc.running = true;
    }

    function fetchImages() {
        root.progressStatus = "loading";
        root._fetchSeq = root._fetchSeq + 1;
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const apiObj = root.booruApis.find(a => {
            return a.value === apiValue;
        }) || root.booruApis[0];
        const tagsStr = root.currentTags.join(",");
        const currentPage = Math.max(1, root.page);
        const startIndex = root.limit > 0 ? (currentPage - 1) * root.limit : 0;
        // Build command
        let cmd = ["python", root.booruScript, "--api", apiValue, "--tags", tagsStr, "--limit", String(root.limit), "--page", String(currentPage)];
        // Add API credentials when available: Settings.apiKey unwraps either shape and falls
        // back to the shipped public defaults.
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
        const mySeq = root._fetchSeq;
        // Read streams on process exit, NOT on stdout.onStreamFinished: stderr may not have
        // flushed yet, which hid the script's real error envelope.
        proc.exited.connect(function (exitCode, exitStatus) {
            // Drop stale responses: a newer fetch (newer tag set) supersedes
            // this one, so its results must not touch the grid.
            if (mySeq !== root._fetchSeq) {
                proc.destroy();
                return;
            }
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
                } catch (e) {}
                Notifications.notify({
                    "summary": "Booru error",
                    "body": msg
                });
                proc.destroy();
                return;
            }
            // Surface the script's error envelope
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
                return;
            }
            if (!Array.isArray(parsed)) {
                root.progressStatus = "error";
                // Notify per-tab error (bookmarks/pins/images)
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
                return;
            }
            try {
                const data = parsed;
                root.images = data.map(img => {
                    return ({
                            "id": img.id || 0,
                            "width": img.width || 0,
                            "height": img.height || 0,
                            "api": apiObj,
                            "tags": img.tags || [],
                            "extension": img.extension,
                            "url": img.url,
                            "preview": img.preview,
                            "sample": img.sample || null
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

    function isRevealed(img) {
        if (!img)
            return false;
        // Dependency marker: bump along with the ids map above.
        void root.revealVersion;
        return !!root.revealedIds[BooruUtils.cacheKey(img)];
    }

    function resetReveal() {
        root.revealedIds = ({});
        root._revealQueue = [];
        root._revealIdx = 0;
    }

    // Anything cached but neither revealed nor queued joins the FIFO; the timer drains one
    // per tick so cards fade in one at a time in grid order.
    function queueAvailableForReveal() {
        const imgs = root.images || [];
        let q = root._revealQueue.slice();
        const revealed = root.revealedIds;
        let added = false;
        for (const img of imgs) {
            if (!img)
                continue;
            const key = BooruUtils.cacheKey(img);
            if (!key || revealed[key] || q.includes(key))
                continue;
            if (root.previewIds[key] || root.downloadedIds[key]) {
                q.push(key);
                added = true;
            }
        }
        if (added) {
            root._revealQueue = q;
            _revealTimer.start();
        }
    }

    // Grid source: the full file if downloaded, else the cached preview, else blank until
    // downloadPreviews() caches it — no remote fallback (Qt TLS segfaults on cdn.donmai.us).
    function gridSource(img) {
        return BooruUtils.gridSource(root.booruPath, root.downloadedIds, root.previewIds, img);
    }

    // Bounded preview downloads (max 4 curls): one batch disk check then a worker pump of
    // managed Processes, so a page turn drops the stale queue via _dlSeq.
    function downloadPreviews(imgList) {
        root._dlSeq++;
        const mySeq = root._dlSeq;
        const MAX_DL = 4;
        const tasks = [];
        (imgList || []).forEach(img => {
            if (!img || !img.preview || !img.api || !img.api.value)
                return;
            const previewDir = `${root.booruPath}/${img.api.value}/previews`;
            // Same path gridSource/getIconPath use (preview still ext, not
            // the post's mp4/webm extension).
            const previewPath = BooruUtils.getIconPath(root.booruPath, img, "previews");
            tasks.push({
                "key": BooruUtils.cacheKey(img),
                "dir": previewDir,
                "path": previewPath,
                "url": img.preview,
                "referer": img.api.url || ""
            });
        });
        if (tasks.length === 0)
            return;

        // One batch check of what is already on disk. Attach stdout in the constructor —
        // setting running=true first races and drops output.
        const checkProc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        checkProc.command = ["bash", "-c", tasks.map(t => {
            return "test -s " + JSON.stringify(t.path) + " && echo " + JSON.stringify(t.key);
        }).join("; ") + "; true"];
        checkProc.stdout.onStreamFinished.connect(function () {
            const current = (mySeq === root._dlSeq);
            const have = {};
            checkProc.stdout.text.trim().split(/\s+/).forEach(key => {
                if (key)
                    have[key] = true;
            });
            checkProc.destroy();
            if (Object.keys(have).length > 0) {
                const ids = Object.assign({}, root.previewIds);
                for (const key in have)
                    ids[key] = true;
                root.previewIds = ids;
            }
            if (current)
                pump(tasks.filter(t => {
                    return !have[t.key];
                }));
        });
        checkProc.running = true;

        function pump(missing) {
            let next = 0;
            let active = 0;
            function pumpMore() {
                // Superseded (new search/page): stop scheduling stale
                // tasks; in-flight workers finish and warm the disk cache.
                if (mySeq !== root._dlSeq)
                    return;
                while (active < MAX_DL && next < missing.length) {
                    const t = missing[next++];
                    active++;
                    // Write to .part then mv atomically so checkProc never marks a truncated
                    // target and Image never opens a half-written preview.
                    const part = t.path + ".part";
                    const dl = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
                    dl.command = ["bash", "-c", `mkdir -p ${JSON.stringify(t.dir)} && curl -sSf --max-time 30 -H ${Settings.shQuote("User-Agent: " + Settings.userAgent("booru"))} -H ${Settings.shQuote("Referer: " + t.referer)} -H "Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8" -o ${JSON.stringify(t.path)} ${JSON.stringify(t.url)} && test -s ${JSON.stringify(t.path)}`];
                    dl.exited.connect(function (code) {
                        active--;
                        // Mark even when superseded: the file is warm on disk and the reveal
                        // queue only admits keys in the current result set.
                        if (code === 0) {
                            const ids = Object.assign({}, root.previewIds);
                            if (!ids[t.key]) {
                                ids[t.key] = true;
                                root.previewIds = ids;
                            }
                        }
                        dl.destroy();
                        pumpMore();
                    });
                    dl.running = true;
                }
            }
            pumpMore();
        }
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
        proc.stdout.onStreamFinished.connect(function () {
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

    // Page buttons: "1 ..." past page 3, then a ~(width/100+2) window; the current page
    // shows a refresh glyph, the rest their number.
    function buildPageButtons() {
        return BooruUtils.buildPageButtons(root.widgetWidth, root.page, Icons.refresh);
    }

    // Local tabs (paginate local list with (page-1)*limit offset)
    function pagedSlice(list) {
        return BooruUtils.pagedSlice(list, root.limit, root.page);
    }

    function loadBookmarks() {
        const bookmarks = Settings.booru.bookmarks || [];
        root.images = root.pagedSlice(bookmarks).map(b => {
            return root.clonify(b);
        });
        root.downloadPreviews(root.images);
        root.progressStatus = "success";
    }

    function loadPins() {
        const pins = Settings.booru.pins || [];
        root.images = root.pagedSlice(pins).map(p => {
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
        // Page buttons always fetchImages() — same-page click refreshes.
        if (p < 1)
            return;

        if (p !== root.page) {
            root.pageDirection = p > root.page ? "next" : "prev";
            root.page = p;
            Settings.booru.page = p;
            Settings.updateSetting("booru.page", p);
        }
        if (!root.loadLocalTab())
            root.fetchImages();
    }

    function boot() {
        if (root._booted)
            return;

        if (root.dialogOnly)
            return;

        if (!Settings.ready)
            return;

        root._booted = true;
        _bootTimer.stop();
        ensureRatingTagFirst();
        const savedTab = Settings.booru.selectedTab || Settings.booru.api.name;
        root.selectedTab = savedTab;
        root.calculateCacheSize();
        if (!root.loadLocalTab())
            root.fetchImages();
    }

    onDialogImageChanged: {
        if (root.dialogImage !== null) {
            _closeTimer.stop();
            root.detailSlide = 1;
            root.fetchOriginal(root.dialogImage);
            // Direct sets (not via openDialog) have no anchor yet —
            // center the dialog until a real anchor arrives.
            if (root.dialogAnchorH <= 0) {
                root.dialogAnchorCenterVy = grid.height / 2;
                root.dialogAnchorContentY = grid.contentY;
                root.dialogAnchorH = 100;
            }
            Qt.callLater(() => root.refreshDialogTop(-1));
        }
    }
    // On new images slide the page in from the travel direction and scroll to top; the
    // anchor card is invalidated, so the dialog drops at once.
    onImagesChanged: {
        // A detached card is its own window: new grid results must not
        // pull it away. Docked cards drop at once (anchor invalidated).
        if (!root.dialogDetached)
            root.requestClose();
        grid.resetScroll();
        // New result set: restart the staggered pop-in from scratch, then
        // reveal anything already cached (bookmarks/pins revisits).
        root.resetReveal();
        root.queueAvailableForReveal();
        if (root._firstImages) {
            root._firstImages = false;
            return;
        }
        grid.slideFrom(root.pageDirection === "next" ? 60 : -60);
    }
    onPreviewIdsChanged: root.queueAvailableForReveal()
    onDownloadedIdsChanged: root.queueAvailableForReveal()
    Component.onCompleted: {
        if (root.dialogOnly)
            return;
        if (Settings.ready)
            root.boot();
        else
            _bootTimer.start();
    }

    // Follow external Settings.booru changes (file reload, bookmark script) without refetching
    // here — tab switches fetch at their call sites; guards stop feedback with our own writes.
    Connections {
        target: Settings
        function onBooruChanged() {
            const b = Settings.booru || {};
            if (b.selectedTab && b.selectedTab !== root.selectedTab)
                root.selectedTab = b.selectedTab;
            if (b.page && b.page !== root.page)
                root.page = b.page;
            if (b.limit && b.limit !== root.limit)
                root.limit = b.limit;
            if (b.columns && b.columns !== root.columns)
                root.columns = b.columns;
            if (Array.isArray(b.tags) && JSON.stringify(b.tags) !== JSON.stringify(root.currentTags))
                root.currentTags = b.tags.slice();
        }
    }

    Timer {
        id: _closeTimer

        interval: 190
        repeat: false
        onTriggered: {
            // Slide-out finished: drop the content (hides the popup) and
            // reset to docked so the next open starts at its anchor card.
            root.dialogDetached = false;
            root.floatSized = false;
            root.dialogImage = null;
        }
    }

    Timer {
        id: _revealTimer

        interval: 45
        repeat: true
        onTriggered: {
            // Drain one card per tick (sequential pop-in). An index pointer instead of
            // slice()-per-tick: the queue only grows here, so nothing is un-drained.
            const q = root._revealQueue || [];
            if (root._revealIdx >= q.length) {
                _revealTimer.stop();
                return;
            }
            const key = String(q[root._revealIdx]);
            root._revealIdx = root._revealIdx + 1;
            // Skip keys that vanished from the current result set.
            const stillThere = (root.images || []).some(img => img && BooruUtils.cacheKey(img) === key);
            if (!stillThere)
                return;
            root.revealedIds[key] = true;
            root.revealVersion++;
            if (root._revealIdx >= q.length)
                _revealTimer.stop();
        }
    }

    Timer {
        id: _bootTimer

        interval: 200
        repeat: true
        onTriggered: root.boot()
    }

    // ColumnLayout (NOT Column): the ScrollView needs Layout.fillHeight to claim space — in a
    // plain Column it is ignored and the grid collapses to zero height.
    ColumnLayout {
        // The grid always claims the full widget width: the detail is a floating popup, so
        // opening it never resizes or relayouts grid, navigation or settings.
        anchors.fill: parent
        spacing: Theme.spacing

        // Image masonry grid (Flickable: ScrollView hides contentY, and
        // scrolls to top after every page transition)
        Booru.BooruGrid {
            id: grid

            viewer: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Tabs, page buttons and prev/reveal/next live in BooruNavigation (BooruToolbar was
        // merged into it). Bookmark toggling lives in BooruActions (booru.py toggle-bookmark).

        // Bottom bar: navigation + revealable settings
        Column {
            Layout.fillWidth: true
            width: parent.width
            spacing: Theme.spacing

            Booru.BooruNavigation {
                viewer: root
            }
            Booru.BooruSettingsPanel {
                viewer: root
            }

        }

    }

    // Floating detail popup: a STATIC surface docked to the island's right edge with the card
    // gliding inside it — moving the window cost a configure round-trip per tick (stutter).
    PopupWindow {
        id: detailPopup
        anchor.item: root
        anchor.rect.x: Math.round(root.width - 4)
        anchor.rect.y: 0
        anchor.rect.width: 1
        anchor.rect.height: 1
        // Defaults (edges Top|Left, gravity Bottom|Right) already put the top-left corner at
        // the rect, expanding down-right. 232px was too narrow for the 2-col action grids.
        implicitWidth: 288
        implicitHeight: Math.max(48, Math.round(root.height))
        // Gated on the host being shown — dialogImage outlives island close and left an orphan
        // popup. Hidden while detached and for pinned hosts (the card is embedded).
        visible: root.dialogImage !== null && !root.dialogDetached && !root.dialogPinned && BarState.isOpenFor("left", root.panelMonitorName) && (!root.hostPanel || root.hostPanel.selectedWidget === "BooruViewer")
        color: "transparent"
        // Clickthrough everywhere except the card: the surface is viewer-tall, so otherwise it
        // would eat clicks meant for windows behind. The Region tracks the card by binding.
        mask: Region {
            x: popupDialog.x
            y: popupDialog.y
            width: popupDialog.width
            height: popupDialog.height
        }

        Booru.BooruDialog {
            id: popupDialog
            viewer: root
            videoActive: detailPopup.visible
            width: parent.width
            // Glide track: viewer and popup coords line up vertically, kept real-valued for
            // subpixel motion; close decisions use the unanimated math so timing never drifts.
            y: grid.y + root.dialogTop
            height: Math.min(implicitHeight, detailPopup.height)
            Behavior on y {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // Detached card window: a real top-level OS window (floating is the compositor's job via a
    // windowrule on this title), same card and state, ending only on an explicit close.
    FloatingWindow {
        id: detailFloat
        title: root.dialogImage ? `Booru #${root.dialogImage.id}` : "Booru"
        visible: root.dialogImage !== null && root.dialogDetached
        implicitWidth: 340
        implicitHeight: 480
        minimumSize: Qt.size(240, 200)
        color: "transparent"

        // A WM-side close flips visible without touching our state, and the true-valued binding
        // never re-pushes, so later opens no-op on a dead surface — resync to closed.
        onVisibleChanged: {
            if (!visible && root.dialogDetached && root.dialogImage !== null) {
                _closeTimer.stop();
                root.dialogDetached = false;
                root.floatSized = false;
                // Pinned hosts: dialogImage is an external binding (Settings.waifu), so nulling
                // it would snap the binding and blank the widget; detailSlide must stay too.
                if (!root.dialogPinned) {
                    root.detailSlide = 0;
                    root.dialogImage = null;
                }
            }
        }

        Booru.BooruDialog {
            anchors.fill: parent
            viewer: root
            videoActive: detailFloat.visible
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
                root.gotoPage(root.page - 1);
            }
            event.accepted = true;
        }
        Keys.onRightPressed: {
            if (root.keyEnabled && root.progressStatus !== "loading") {
                root.gotoPage(root.page + 1);
            }
            event.accepted = true;
        }
    }

    // Overlay entrance: slide/fade only, never layout widths.
    Behavior on detailSlide {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    _limitDebounce: Timer {
        interval: 300
        repeat: false
        onTriggered: root.fetchImages()
    }
}
