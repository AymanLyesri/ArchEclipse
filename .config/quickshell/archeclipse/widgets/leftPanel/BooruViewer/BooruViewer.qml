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
    // Ordered page stack: one grid block per page, so an append keeps every loaded page mounted.
    property var loadedPages: []
    // Flat projection for the remaining consumers (dialog predicates, cache cleanup).
    readonly property var images: {
        const out = [];
        for (const pg of root.loadedPages) {
            for (const im of (pg.images || []))
                out.push(im);
        }
        return out;
    }
    property bool _firstImages: true
    // Stack token: a response may only touch the stack that started it — a reset bumps the
    // generation and a settings change alters the signature.
    property string _stackKey: ""
    property int _stackGen: 0
    property bool endAbove: false
    property bool endBelow: false
    property int _pendingScrollPage: 0
    // One request per direction at a time: the loading placeholder is only ~44px tall, so an
    // ungated edge check queues page after page while it is still in flight.
    property bool loadingAbove: false
    property bool loadingBelow: false
    // Preview pool: one deduped queue (max 4 curls). Only a full reset cancels, so an append
    // never drops the previous page's downloads.
    property var _dlQueue: []
    property int _dlActive: 0
    property var _dlKeys: ({})
    property int _dlGen: 0
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
            root.downloadCancel();
            proc.destroy();
            // Re-fetch previews for the loaded pages (the files are gone).
            if (root.images.length > 0)
                root.downloadPreviews(root.images);
        });
        proc.running = true;
    }

    // --- page stack -----------------------------------------------------------
    function stackKey() {
        return (Settings.booru.api ? Settings.booru.api.value : "danbooru") + "|" + root.currentTags.join(",") + "|" + root.limit;
    }

    function stackToken() {
        return root._stackKey + "#" + root._stackGen;
    }

    function pageEntry(pageNo) {
        for (const pg of root.loadedPages) {
            if (pg.page === pageNo)
                return pg;
        }
        return null;
    }

    function hasPage(pageNo) {
        return root.pageEntry(pageNo) !== null;
    }

    function pageLoading(pageNo) {
        const e = root.pageEntry(pageNo);
        return !!e && e.loading;
    }

    function minLoadedPage() {
        return root.loadedPages.length ? root.loadedPages[0].page : 0;
    }

    function maxLoadedPage() {
        return root.loadedPages.length ? root.loadedPages[root.loadedPages.length - 1].page : 0;
    }

    function persistPage(pageNo) {
        if (Settings.booru.page === pageNo)
            return;
        Settings.booru.page = pageNo;
        Settings.updateSetting("booru.page", pageNo);
    }

    // Drop the whole stack: scroll offset, dividers and page numbers belong to one search.
    function resetStack(pageNo) {
        const p = Math.max(1, Math.round(Number(pageNo) || 1));
        root._stackKey = root.stackKey();
        root._stackGen = root._stackGen + 1;
        root._pendingScrollPage = 0;
        root.endAbove = false;
        root.endBelow = false;
        root.loadingAbove = false;
        root.loadingBelow = false;
        root.downloadCancel();
        root.loadedPages = [];
        root.page = p;
        root.persistPage(p);
        root.loadPage(p, "replace");
    }

    // New search identity (tags / api / limit): always restarts at page 1.
    function refetchFromFirstPage() {
        root.resetStack(1);
    }

    function fetchImages() {
        root.refetchFromFirstPage();
    }

    function loadPage(pageNo, side) {
        if (root.loadLocalPage(pageNo, side))
            return;
        root.fetchApiPage(pageNo, side);
    }

    // Local tabs: pages are instant slices of the saved arrays (no network, no loading state).
    function localList() {
        return root.selectedTab === "Pins" ? (Settings.booru.pins || []) : (Settings.booru.bookmarks || []);
    }

    function localSnapshot(list, pageNo) {
        if (!(root.limit > 0))
            return pageNo === 1 ? list.map(x => root.clonify(x)) : [];
        return BooruUtils.pagedSlice(list, root.limit, pageNo).map(x => root.clonify(x));
    }

    function loadLocalPage(pageNo, side, list) {
        const isLocal = root.selectedTab === "Bookmarks" || root.selectedTab === "Pins";
        if (!isLocal && !list)
            return false;
        const imgs = root.localSnapshot(list || root.localList(), pageNo);
        root.applyPage(pageNo, imgs, side || "replace", !(root.limit > 0) || imgs.length < root.limit);
        return true;
    }

    // Single source for the local slices (bookmark toggle refresh, IPC and page turns alike).
    function loadBookmarks(pageNo, side) {
        return root.loadLocalPage(pageNo || root.page, side, Settings.booru.bookmarks || []);
    }

    function loadPins(pageNo, side) {
        return root.loadLocalPage(pageNo || root.page, side, Settings.booru.pins || []);
    }

    // The one mutation point for the stack: replace resets, append/prepend only add a block.
    function applyPage(pageNo, imgs, side, exhausted) {
        const entry = {
            "page": pageNo,
            "images": imgs || [],
            "loading": false,
            "error": ""
        };
        root.loadingAbove = false;
        root.loadingBelow = false;
        if (side === "replace") {
            root.resetReveal();
            root.page = pageNo;
            root.persistPage(pageNo);
            root.loadedPages = [entry];
            root.endAbove = false;
            root.endBelow = exhausted || entry.images.length === 0;
            root.progressStatus = "success";
            // A docked card is anchored to a card of the dropped stack; a detached float is its
            // own window and stays.
            if (root.dialogImage !== null && !root.dialogDetached)
                root.requestClose();
            grid.scrollToTop();
            if (!root._firstImages)
                grid.slideFrom(root.pageDirection === "next" ? 60 : -60);
            root._firstImages = false;
            root.queueRevealFor(entry.images);
            root.downloadPreviews(entry.images);
            return;
        }
        const isAppend = side === "append";
        const list = root.loadedPages.slice();
        const idx = list.findIndex(pg => pg.page === pageNo);
        if (entry.images.length === 0) {
            // Empty answer: drop the edge placeholder and stop that direction for good.
            const cap = isAppend ? null : grid.captureViewport();
            if (idx >= 0)
                list.splice(idx, 1);
            root.loadedPages = list;
            if (isAppend)
                root.endBelow = true;
            else
                root.endAbove = true;
            root._pendingScrollPage = 0;
            if (!isAppend)
                Qt.callLater(() => grid.restoreViewport(cap));
            return;
        }
        // Prepend inserts above the viewport, so the anchor has to be captured first.
        const cap = isAppend ? null : grid.captureViewport();
        if (idx >= 0)
            list[idx] = entry;
        else
            list.push(entry);
        list.sort((a, b) => a.page - b.page);
        if (!isAppend && root.dialogImage !== null && !root.dialogDetached)
            root.requestClose();
        root.loadedPages = list;
        if (exhausted) {
            if (isAppend)
                root.endBelow = true;
            else
                root.endAbove = true;
        }
        root.queueRevealFor(entry.images);
        root.downloadPreviews(entry.images);
        if (root._pendingScrollPage === pageNo) {
            root._pendingScrollPage = 0;
            Qt.callLater(() => grid.scrollToPage(pageNo));
        } else if (!isAppend) {
            Qt.callLater(() => grid.restoreViewport(cap));
        }
        root.trimStack(pageNo);
    }

    // Memory guard: AppMasonry instantiates every card, so only 8 page blocks stay mounted.
    // The victim is the block farthest from the anchor, never it or a neighbour.
    function trimStack(anchorPage) {
        const MAX_PAGES = 8;
        if (root.loadedPages.length <= MAX_PAGES)
            return;
        const cap = grid.captureViewport();
        const list = root.loadedPages.slice();
        while (list.length > MAX_PAGES) {
            let victim = -1;
            let far = -1;
            for (let i = 0; i < list.length; i++) {
                const dist = Math.abs(list[i].page - anchorPage);
                if (dist <= 1 || list[i].loading)
                    continue;
                if (dist > far) {
                    far = dist;
                    victim = i;
                }
            }
            if (victim < 0)
                break;
            list.splice(victim, 1);
        }
        if (list.length === root.loadedPages.length)
            return;
        root.loadedPages = list;
        Qt.callLater(() => grid.restoreViewport(cap));
    }

    function beginPage(pageNo, side) {
        const cap = side === "prepend" ? grid.captureViewport() : null;
        const list = root.loadedPages.slice();
        const idx = list.findIndex(pg => pg.page === pageNo);
        const entry = {
            "page": pageNo,
            "images": [],
            "loading": true,
            "error": ""
        };
        if (idx >= 0)
            list[idx] = entry;
        else
            list.push(entry);
        list.sort((a, b) => a.page - b.page);
        root.loadedPages = list;
        if (cap)
            Qt.callLater(() => grid.restoreViewport(cap));
    }

    function failPage(pageNo, side, msg) {
        const detail = String(msg || "Unknown booru error").slice(0, 200);
        root.lastFetchError = detail;
        root.loadingAbove = false;
        root.loadingBelow = false;
        if (side === "replace") {
            root.progressStatus = "error";
            root.loadedPages = [];
            Notifications.notify({
                "summary": root.selectedTab === "Bookmarks" ? "Error loading bookmarks" : root.selectedTab === "Pins" ? "Error loading pins" : "Error fetching images",
                "body": detail
            });
            return;
        }
        // Edge failure: loaded pages stay mounted and the block offers a retry.
        const list = root.loadedPages.slice();
        const idx = list.findIndex(pg => pg.page === pageNo);
        if (idx < 0)
            return;
        list[idx] = {
            "page": pageNo,
            "images": list[idx].images || [],
            "loading": false,
            "error": detail
        };
        root.loadedPages = list;
    }

    function fetchApiPage(pageNo, side) {
        // Edge requests are single-flight per side (a retry of the same side waits its turn).
        if (side === "append" ? root.loadingBelow : (side === "prepend" ? root.loadingAbove : false))
            return;
        const token = root.stackToken();
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const apiObj = root.booruApis.find(a => {
            return a.value === apiValue;
        }) || root.booruApis[0];
        let cmd = ["python", root.booruScript, "--api", apiValue, "--tags", root.currentTags.join(","), "--limit", String(root.limit), "--page", String(pageNo)];
        // Credentials: Settings.apiKey unwraps either shape and falls back to the shipped
        // public defaults.
        const apiUser = Settings.apiKey(apiValue, "user");
        const apiPass = Settings.apiKey(apiValue, "key");
        if (apiUser !== "" && apiPass !== "")
            cmd.push("--api-user", apiUser, "--api-key", apiPass);
        root.lastFetchCmd = JSON.stringify(cmd.map((a, i) => {
            return (a === "--api-key" || a === "--api-user") ? a : (cmd[i - 1] === "--api-key" || cmd[i - 1] === "--api-user" ? "***" : a);
        }));
        root.lastFetchError = "";
        // Only a replace drives the nav pill; an edge shows its own block state.
        if (side === "replace") {
            root.progressStatus = "loading";
        } else {
            if (side === "append")
                root.loadingBelow = true;
            else
                root.loadingAbove = true;
            root.beginPage(pageNo, side);
        }
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + ' }', root);
        // Collectors must be attached before running (never after), and
        // inline `stderr:` is rejected by the QML parser — assign here.
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        proc.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        proc.running = true;
        // Read streams on process exit, NOT on stdout.onStreamFinished: stderr may not have
        // flushed yet, which hid the script's real error envelope.
        proc.exited.connect(function (exitCode, exitStatus) {
            // A reset or a settings change since the request supersedes it.
            if (token !== root.stackToken()) {
                proc.destroy();
                return;
            }
            const text = proc.stdout.text;
            const errText = proc.stderr.text;
            let parsed = null;
            try {
                parsed = text && text.trim() ? JSON.parse(text) : null;
            } catch (e) {
                parsed = null;
            }
            let msg = "";
            if ((!text || !text.trim()) && errText && errText.trim()) {
                msg = errText.trim().slice(0, 300);
                try {
                    const ej = JSON.parse(errText.trim());
                    if (ej && ej.message)
                        msg = String(ej.message);
                } catch (e) {}
            } else if (parsed && typeof parsed === "object" && !Array.isArray(parsed) && parsed.error === true) {
                msg = (parsed.message && String(parsed.message).trim()) || "Unknown booru error";
            } else if (!Array.isArray(parsed)) {
                msg = text && text.trim() ? text.trim().slice(0, 200) : "Failed to fetch images";
            }
            if (msg !== "") {
                root.lastFetchError = "stdout[" + (text ? text.trim().slice(0, 200) : "<empty>") + "] stderr[" + (errText ? errText.slice(0, 200) : "<empty>") + "]";
                root.failPage(pageNo, side, msg);
                proc.destroy();
                return;
            }
            try {
                const data = parsed.map(img => {
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
                root.applyPage(pageNo, data, side, data.length === 0);
            } catch (e) {
                root.failPage(pageNo, side, String(e));
            }
            proc.destroy();
        });
    }

    function retryPage(pageNo) {
        if (!root.hasPage(pageNo))
            return;
        root._pendingScrollPage = pageNo;
        root.fetchApiPage(pageNo, pageNo === root.minLoadedPage() ? "prepend" : "append");
    }

    // Grid edge request: one page in that direction, never below 1, never twice.
    function loadEdgePage(dir) {
        if (root.loadedPages.length === 0)
            return;
        if (dir > 0 ? root.loadingBelow : root.loadingAbove)
            return;
        const pageNo = dir > 0 ? root.maxLoadedPage() + 1 : root.minLoadedPage() - 1;
        if (pageNo < 1 || root.hasPage(pageNo))
            return;
        if (dir > 0 ? root.endBelow : root.endAbove)
            return;
        root.loadPage(pageNo, dir > 0 ? "append" : "prepend");
    }

    // Scroll-spy owns the page number while the grid scrolls; persistence is debounced so a
    // fast flick writes once.
    function handlePageVisible(pageNo) {
        if (pageNo < 1 || pageNo === root.page)
            return;
        root.page = pageNo;
        _pagePersistTimer.restart();
    }

    function gotoPage(p) {
        const target = Math.round(Number(p));
        if (!(target >= 1))
            return;
        const entry = root.pageEntry(target);
        if (entry) {
            if (entry.loading) {
                root._pendingScrollPage = target;
                return;
            }
            if (entry.error !== "") {
                root.retryPage(target);
                return;
            }
            // Mounted page: navigation is a scroll, not a fetch.
            root.page = target;
            root.persistPage(target);
            grid.scrollToPage(target);
            return;
        }
        const min = root.minLoadedPage();
        const max = root.maxLoadedPage();
        if (min > 0 && (target === min - 1 || target === max + 1)) {
            root._pendingScrollPage = target;
            root.pageDirection = target > max ? "next" : "prev";
            root.loadPage(target, target > max ? "append" : "prepend");
            return;
        }
        // Jump: clear the stack and load only that page as a fresh set.
        root.pageDirection = target > root.page ? "next" : "prev";
        root.resetStack(target);
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
    function queueRevealFor(imgs) {
        let q = root._revealQueue.slice();
        const revealed = root.revealedIds;
        let added = false;
        for (const img of (imgs || [])) {
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

    function queueAvailableForReveal() {
        root.queueRevealFor(root.images);
    }

    // Grid source: the full file if downloaded, else the cached preview, else blank until
    // downloadPreviews() caches it — no remote fallback (Qt TLS segfaults on cdn.donmai.us).
    function gridSource(img) {
        return BooruUtils.gridSource(root.booruPath, root.downloadedIds, root.previewIds, img);
    }

    // Preview pool: one deduped queue, max 4 curls in flight. An append joins the same pool, so
    // earlier pages keep downloading; only a full stack reset cancels.
    function downloadPreviews(imgList) {
        const tasks = [];
        for (const img of (imgList || [])) {
            if (!img || !img.preview || !img.api || !img.api.value)
                continue;
            const key = BooruUtils.cacheKey(img);
            if (!key || root._dlKeys[key] || root.previewIds[key])
                continue;
            root._dlKeys[key] = true;
            tasks.push({
                "key": key,
                "dir": `${root.booruPath}/${img.api.value}/previews`,
                "path": BooruUtils.getIconPath(root.booruPath, img, "previews"),
                "url": img.preview,
                "referer": img.api.url || ""
            });
        }
        if (tasks.length === 0)
            return;
        const gen = root._dlGen;
        // One disk probe per call: cached previews turn previewIds warm instead of re-downloading.
        const checkProc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        checkProc.command = ["bash", "-c", tasks.map(t => {
            return "test -s " + JSON.stringify(t.path) + " && echo " + JSON.stringify(t.key);
        }).join("; ") + "; true"];
        checkProc.stdout.onStreamFinished.connect(function () {
            const have = {};
            (checkProc.stdout.text || "").trim().split(/\s+/).forEach(key => {
                if (key)
                    have[key] = true;
            });
            checkProc.destroy();
            if (gen !== root._dlGen)
                return;
            if (Object.keys(have).length > 0) {
                const ids = Object.assign({}, root.previewIds);
                for (const key in have)
                    ids[key] = true;
                root.previewIds = ids;
            }
            root._dlQueue = root._dlQueue.concat(tasks.filter(t => {
                return !have[t.key];
            }));
            root.pumpDownloads();
        });
        checkProc.running = true;
    }

    function downloadCancel() {
        root._dlGen = root._dlGen + 1;
        root._dlQueue = [];
        root._dlKeys = ({});
    }

    function pumpDownloads() {
        const MAX_DL = 4;
        while (root._dlActive < MAX_DL && root._dlQueue.length > 0) {
            const t = root._dlQueue.shift();
            root._dlActive = root._dlActive + 1;
            const dl = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
            dl.command = ["bash", "-c", `mkdir -p ${JSON.stringify(t.dir)} && curl -sSf --max-time 30 -H ${Settings.shQuote("User-Agent: " + Settings.userAgent("booru"))} -H ${Settings.shQuote("Referer: " + t.referer)} -H "Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8" -o ${JSON.stringify(t.path)} ${JSON.stringify(t.url)} && test -s ${JSON.stringify(t.path)}`];
            dl.exited.connect(function (code) {
                root._dlActive = Math.max(0, root._dlActive - 1);
                // Mark even when superseded: the file is warm on disk for the next visit.
                if (code === 0) {
                    const ids = Object.assign({}, root.previewIds);
                    if (!ids[t.key]) {
                        ids[t.key] = true;
                        root.previewIds = ids;
                    }
                } else {
                    // Release the key so a later call can retry a transient failure.
                    delete root._dlKeys[t.key];
                }
                dl.destroy();
                root.pumpDownloads();
            });
            dl.running = true;
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

    // Initial load, branched to bookmarks/pins/API from the restored tab. Deferred until
    // Settings.ready — booting on defaults fetched with the wrong limit and persisted them.
    function boot() {
        if (root._booted || root.dialogOnly || !Settings.ready)
            return;
        root._booted = true;
        _bootTimer.stop();
        root.ensureRatingTagFirst();
        root.selectedTab = Settings.booru.selectedTab || Settings.booru.api.name;
        root.calculateCacheSize();
        // The persisted page restores as a single-block stack (jump semantics).
        root.resetStack(root.page);
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
            // Only an outside change (file reload, another tab) reaches here with a different
            // value: our own writes land after the property is already updated.
            let identity = false;
            if (b.selectedTab && b.selectedTab !== root.selectedTab) {
                root.selectedTab = b.selectedTab;
                identity = true;
            }
            if (b.page && b.page !== root.page)
                root.page = b.page;
            if (b.limit && b.limit !== root.limit) {
                root.limit = b.limit;
                identity = true;
            }
            if (b.columns && b.columns !== root.columns)
                root.columns = b.columns;
            if (Array.isArray(b.tags) && JSON.stringify(b.tags) !== JSON.stringify(root.currentTags)) {
                root.currentTags = b.tags.slice();
                identity = true;
            }
            if (identity && root._booted && !root.dialogOnly && !root.dialogPinned)
                root.refetchFromFirstPage();
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
        id: _pagePersistTimer

        interval: 300
        repeat: false
        onTriggered: root.persistPage(root.page)
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
            onNeedPageBelow: root.loadEdgePage(1)
            onNeedPageAbove: root.loadEdgePage(-1)
            onPageBecameVisible: pageNo => root.handlePageVisible(pageNo)
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
        onTriggered: root.refetchFromFirstPage()
    }
}
