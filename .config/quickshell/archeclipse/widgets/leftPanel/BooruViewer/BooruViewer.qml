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
    // File already written by the script — no persist needed.

    id: root

    property int widgetWidth: parent.width
    property string className: ""
    readonly property string booruPath: `${Quickshell.env("HOME")}/.cache/quickshell/booru`
    readonly property string booruScript: `${Quickshell.env("HOME")}/.config/quickshell/archeclipse/scripts/booru.py`
    // --- state (per-instance, not singleton) ---
    property var images: []
    // fetched image objects
    property bool _firstImages: true
    // Monotonic fetch sequence: rapid tag add/removes fire overlapping
    // fetches and a stale (older tag set) response must not overwrite the
    // grid after a newer one landed.
    property int _fetchSeq: 0
    // Download generation: a new downloadPreviews() call supersedes the
    // previous queue (page turn / new search) — leftover tasks are
    // dropped instead of spending bandwidth on a stale grid.
    property int _dlSeq: 0
    // Masonry: distribute to the shortest column by
    // aspect ratio (NOT row-by-row Flow). NOTE: must live on root — a
    // property declared among ColumnLayout children belongs to the layout.
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
    // Image-dialog state — the currently open image dialog.
    // The detail is a root-level overlay (bottom of this file): opening it
    // resizes nothing, so no frozen grid widths or revealer flags exist.
    property var dialogImage: null
    // Floating-dialog anchor: viewport Y of the clicked card's center at
    // open time (+ contentY then + card height). Scroll deltas shift the
    // card's live position; dialogTop re-clamps to follow it until the
    // card leaves the viewport → auto-close. dialogH is the last measured
    // dialog content height used for centering/clamping.
    property real dialogAnchorCenterVy: 0
    property real dialogAnchorContentY: 0
    property real dialogAnchorH: 100
    property real dialogTop: 0
    property real dialogH: 560
    // Detached dialog: dragging the header grip (or the resize cell)
    // moves the card into a normal FloatingWindow — a top-level OS
    // window. Float behavior itself is the compositor's job (Hyprland
    // float rule, e.g. on this window's title). It stays open across
    // island close / tab switch / new results until explicitly closed;
    // clicking another post swaps the content in place. Closing fully
    // resets to docked.
    property bool dialogDetached: false
    // Whether the float window was aspect-fit for the current dialog
    // session (keeps the user's resize across post swaps; reset on close).
    property bool floatSized: false
    // Hover handoff with the floating popup (separate window surface):
    // the island keeps itself open while this is true (see LeftIsland
    // requestAutoHide) and re-arms its hide when it clears.
    property bool popupHovered: false
    // Back-reference injected by LeftIsland (booruView.hostPanel = island).
    property var hostPanel: null
    // Monitor screen for float-window size clamps. Reactive binding (not
    // a one-shot onLoaded assign): the nested booru Loader can finish
    // before the island's own screen prop arrives from the bar, which
    // left this permanently null and the float surface never visible.
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
    // Overlay entrance driver (0 = parked, 1 = in). Slide/opacity only —
    // the grid, toolbar, navigation and settings never relayout, so this
    // cannot feed back into the layout the way a width animation did.
    property real detailSlide: 0
    // Downloaded set: populated automatically by fetchOriginal() when the
    // full file lands in <api>/images/ (no manual download step).
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
    // Local preview-file ids verified present on disk. Grid prefers these
    // (the downloaded local preview via getPreviewPath()).
    property var previewIds: ({})
    // Cards allowed to fade in. previewIds flips the moment a file lands
    // on disk (Image starts decoding ASAP); revealedIds is drained one
    // id per _revealTimer tick so cards pop in sequentially instead of
    // bursting all at once.
    property var revealedIds: ({})
    property var _revealQueue: []
    // Local full-image ids verified present on disk (dialog cache).
    // Remote danbooru URLs 403 inside Qt, so the dialog can only show
    // full files downloaded with Referer headers by fetchOriginal().
    property var fullIds: ({})
    // Initial fetch on load (branches to bookmarks/pins/API
    // from the restored tab — saved Bookmarks/Pins must not fetch the API).
    // Deferred until Settings.ready: booting on defaults would fetch with
    // limit 100 / the wrong tab and persist the defaults over the file.
    property bool _booted: false
    // Dialog-host mode (e.g. waifu's private host): the instance only ever
    // serves floating dialogs, so the grid boot fetch (network + preview
    // downloads + tag persistence) is skipped entirely.
    property bool dialogOnly: false

    // Slide-out, then unmount: the overlay glides/fades away first and
    // only then (_closeTimer) is the content dropped.
    function requestClose() {
        if (root.dialogImage === null)
            return;

        root.detailSlide = 0;
        _closeTimer.restart();
    }

    // Immediate teardown: the detail PopupWindow is a separate surface
    // whose visibility is driven only by dialogImage, so it outlives the
    // viewer (island close / tab switch keeps this instance alive in the
    // cached Loader). Drop the content at once — no slide-out, the host
    // is already gone.
    function closeDialogNow() {
        if (root.dialogImage === null)
            return;

        _closeTimer.stop();
        root.detailSlide = 0;
        // Reset to docked so the next open starts at its anchor card.
        root.dialogDetached = false;
        root.floatSized = false;
        root.dialogImage = null;
    }

    // Detach into the FloatingWindow below and aspect-fit it for the
    // post (bounded by the screen). Runs once per dialog session — the
    // user's own resize after that is left alone across post swaps.
    function detachDialog() {
        if (root.dialogDetached || root.dialogImage === null)
            return;
        root.dialogDetached = true;
        if (!root.floatSized) {
            const sw = root.screenW(), sh = root.screenH(), a = root.dialogAspect();
            let w = Math.min(380, sw - 40);
            let h = w / a;
            if (h > sh - 40) {
                h = sh - 40;
                w = h * a;
            }
            detailFloat.width = Math.max(240, Math.min(sw, w));
            detailFloat.height = Math.max(200, Math.min(sh, h));
            root.floatSized = true;
        }
    }

    // System move for the float window (called on first drag motion so
    // the window is mapped when the compositor checks the gesture).
    function moveFloat() {
        try {
            if (typeof detailFloat.startSystemMove === "function")
                detailFloat.startSystemMove();
        } catch (e) {}
    }

    // Corner resize on the float window, aspect-locked to the post:
    // SE drag drives width, height follows the ratio inside the
    // requested rect, clamped to minimums and the screen. Client-set
    // size (honored once floated via the Hyprland rule); detaches first
    // when starting from the docked card.
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
        detailFloat.width = Math.max(240, Math.min(reqW, reqH * a));
        detailFloat.height = Math.max(200, Math.min(reqH, detailFloat.width / a));
    }

    // Viewer hidden directly (e.g. Loader deactivated) → drop a docked
    // dialog. A detached card is its own window and stays open.
    onVisibleChanged: {
        if (!root.visible && !root.dialogDetached)
            root.closeDialogNow();
    }

    Component.onDestruction: {
        _closeTimer.stop();
    }

    // Island closed (BarState leaves "left") → a docked card's popup
    // surface would stay on screen orphaned, so drop it. A detached
    // card is its own window and stays open until explicitly closed.
    Connections {
        target: BarState
        function onStateChanged() {
            if (BarState.state !== "left" && !root.dialogDetached)
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

    // Open the overlay at the clicked card: capture the card's viewport
    // center (+ scroll offset + height), then set the image. Re-clicking
    // the same image just re-anchors (no unmount churn).
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

    // Per-tick follow: recompute the card's target Y from the live scroll
    // offset and dismiss once the anchor leaves the viewport. This writes
    // only dialogTop — a local binding that moves content inside the
    // static popup surface (vsync repaint). It never touches the anchor,
    // so zero compositor round-trips happen here (that was the stutter).
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

    // Island +/- resize with the popup open moves the edge the static
    // anchor was computed from: re-push once the configure lands (a
    // single round-trip on a rare user action — never per-frame).
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

    function isInfoTagged(img) {
        return root.isPinned(img) || root.isBookmarked(img) || root.isCurrentWaifu(img);
    }

    function isVideo(img) {
        return BooruActions.isVideo(img);
    }

    function isDownloaded(img) {
        return !!img && !!root.downloadedIds[String(img.id)];
    }

    function imageFileUrl(img) {
        return BooruUtils.imageFileUrl(root.booruPath, root.downloadedIds, img);
    }

    // Dialog source: downloaded full file, else cached original, else the
    // cached preview still while fetchOriginal() downloads the full file,
    // else "" (dialog shows a spinner).
    function dialogSource(img) {
        return BooruUtils.dialogSource(root.booruPath, root.downloadedIds, root.fullIds, root.previewIds, img);
    }

    // Dialog auto-downloads the full file into <api>/images/ with the same
    // Referer+UA headers as downloadPreviews (Qt gets 403 without them).
    // When it lands, downloadedIds flips and the Pin button auto-enables.
    // Skips zip (dialog shows a placeholder) and anything already on disk.
    // Legacy <api>/originals/ files are promoted into <api>/images/.
    function fetchOriginal(img) {
        if (!img || !img.url || !img.api || !img.api.value)
            return;
        // Local files (custom waifu uploads) need no download — the
        // dialog plays the path directly (see dialogSource).
        if (!/^https?:\/\//.test(img.url))
            return;
        if (BooruActions.isZip(img))
            return;
        if (root.isDownloaded(img) || root.fullIds[String(img.id)])
            return;

        const dir = `${root.booruPath}/${img.api.value}/images`;
        const filePath = `${dir}/${img.id}.${img.extension}`;
        const legacyPath = `${root.booruPath}/${img.api.value}/originals/${img.id}.${img.extension}`;
        const markDone = function () {
            const ids = Object.assign({}, root.downloadedIds);
            ids[String(img.id)] = true;
            root.downloadedIds = ids;
            const full = Object.assign({}, root.fullIds);
            full[String(img.id)] = true;
            root.fullIds = full;
            root.dialogVersion++;
        };
        const downloadMissing = function () {
            const dl = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
            dl.command = ["bash", "-c", `mkdir -p \"${dir}\" && curl -sSfL --max-time 60 -H "User-Agent: QuickshellBooru/1.0 (ArchLinux; Hyprland)" -H "Referer: ${img.api.url}" -H "Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8" -o \"${filePath}\" \"${img.url}\" && test -s \"${filePath}\"`];
            dl.exited.connect(function (code) {
                if (code === 0)
                    markDone();
                dl.destroy();
            });
            dl.running = true;
        };
        const checkProc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        checkProc.command = ["bash", "-c", "test -s " + JSON.stringify(filePath) + " && echo images || (test -s " + JSON.stringify(legacyPath) + " && echo legacy || echo no)"];
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

    // Shared pin service. Pinning still requires the auto-downloaded full
    // file (the fastfetch sync converts <booruPath>/<api>/images/<id>.<ext>),
    // but fetchOriginal() now fetches it on dialog open, so the button
    // auto-enables when downloadedIds flips instead of needing a manual step.
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

    // Legacy entry point kept for IPC callers: the dialog auto-downloads now.
    function downloadImage(img) {
        root.fetchOriginal(img);
    }

    function setAsWaifu(img) {
        return BooruActions.setAsWaifu(img);
    }

    // Copy the downloaded full image into ~/.config/wallpapers/custom
    // (thumbnail included) so the Wallpaper switcher can apply it.
    function saveAsWallpaper(img) {
        return BooruActions.saveAsWallpaper(img);
    }

    // Dialog tag hold ("Hold: search"): ADD the tag to the current search
    // instead of replacing it (current + new, deduped).
    // No-op when the tag is already in the search.
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
        if (root.selectedTab !== "Bookmarks" && root.selectedTab !== "Pins")
            root.fetchImages();
    }

    function copyTag(tag) {
        return BooruActions.copyTag(tag);
    }

    function formatTagForDisplay(tag) {
        return tag;
    }

    // Manual property copy (QML JS has no object-spread `{...obj}`):
    // preserve the
    // item's own stored api so cross-API bookmarks/pins resolve to the right
    // preview dir and idSearchUrl — never overwrite with the current tab.
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

    function calculateCacheSize() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        proc.command = ["bash", "-c", "du -sb " + JSON.stringify(root.booruPath + '/' + apiValue + '/previews') + " 2>/dev/null | cut -f1"];
        proc.stdout.onStreamFinished.connect(function () {
            const bytes = parseInt(proc.stdout.text.trim()) || 0;
            root.cacheSize = Math.round(bytes / (1024 * 1024)) + "mb";
            proc.destroy();
        });
        proc.running = true;
    }

    function cleanCache() {
        const apiValue = Settings.booru.api ? Settings.booru.api.value : "danbooru";
        Quickshell.execDetached(["bash", "-c", `rm -rf '${root.booruPath}/${apiValue}/previews/*' '${root.booruPath}/${apiValue}/images/*' '${root.booruPath}/${apiValue}/originals/*'`]);
        root.calculateCacheSize();
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
        // Add API credentials if available (credentials.user.value /
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
        const mySeq = root._fetchSeq;
        // NOTE: read streams on process exit, NOT on stdout.onStreamFinished:
        // stderr may not have flushed when stdout closes, which hid the
        // script's real error envelope (empty stderr reads).
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

    function isRevealed(img) {
        return !!img && !!root.revealedIds[String(img.id)];
    }

    function resetReveal() {
        root.revealedIds = ({});
        root._revealQueue = [];
    }

    // Scan images in order; anything cached/downloaded but neither
    // revealed nor queued joins the FIFO. The timer drains one per tick
    // so cards fade in one at a time in grid order.
    function queueAvailableForReveal() {
        const imgs = root.images || [];
        let q = root._revealQueue.slice();
        const revealed = root.revealedIds;
        let added = false;
        for (const img of imgs) {
            if (!img)
                continue;
            const key = String(img.id);
            if (revealed[key] || q.includes(key))
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

    // Grid source: full image file if downloaded, else cached preview file,
    // else blank until downloadPreviews() caches it (no remote fallback —
    // Qt TLS segfaults on cdn.donmai.us and gets 403 anyway).
    function gridSource(img) {
        return BooruUtils.gridSource(root.booruPath, root.downloadedIds, root.previewIds, img);
    }

    // Bounded-concurrency preview downloads (max 4 parallel curls).
    // Was: one check-Process per image + one detached curl per missing
    // file (up to `limit` parallel curls) + a 700ms polling timer.
    // Now: a single batch existence check, then a worker pump that keeps
    // at most MAX_DL downloads in flight. Each worker is a managed
    // Process (not execDetached), so completion directly flips that one
    // card to file:// — no polling, and a page turn drops the stale
    // queue via _dlSeq instead of downloading images nobody sees.
    function downloadPreviews(imgList) {
        root._dlSeq++;
        const mySeq = root._dlSeq;
        const MAX_DL = 4;
        const tasks = [];
        (imgList || []).forEach(img => {
            if (!img || !img.preview || !img.api || !img.api.value)
                return;
            const previewDir = `${root.booruPath}/${img.api.value}/previews`;
            tasks.push({
                "id": String(img.id),
                "dir": previewDir,
                "path": `${previewDir}/${img.id}.${img.extension}`,
                "url": img.preview,
                "referer": img.api.url || ""
            });
        });
        if (tasks.length === 0)
            return;

        // One batch check for everything already on disk (warm cache /
        // revisits flip instantly with zero network). NOTE: the stdout
        // collector must be attached in the constructor — setting
        // running=true before assigning stdout races and drops output.
        const checkProc = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        checkProc.command = ["bash", "-c", tasks.map(t => {
            return "test -s " + JSON.stringify(t.path) + " && echo " + t.id;
        }).join("; ") + "; true"];
        checkProc.stdout.onStreamFinished.connect(function () {
            const current = (mySeq === root._dlSeq);
            const have = {};
            checkProc.stdout.text.trim().split(/\s+/).forEach(id => {
                if (id)
                    have[id] = true;
            });
            checkProc.destroy();
            if (Object.keys(have).length > 0) {
                const ids = Object.assign({}, root.previewIds);
                for (const id in have)
                    ids[id] = true;
                root.previewIds = ids;
            }
            if (current)
                pump(tasks.filter(t => {
                    return !have[t.id];
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
                    // curl -f fails on HTTP errors and --max-time caps a
                    // hung connection so a stuck worker can't wedge the
                    // queue; trailing test -s only reports real files.
                    const dl = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
                    dl.command = ["bash", "-c", `mkdir -p ${JSON.stringify(t.dir)} && curl -sSf --max-time 30 -H "User-Agent: QuickshellBooru/1.0 (ArchLinux; Hyprland)" -H "Referer: ${t.referer}" -H "Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8" -o ${JSON.stringify(t.path)} ${JSON.stringify(t.url)} && test -s ${JSON.stringify(t.path)}`];
                    dl.exited.connect(function (code) {
                        active--;
                        // Mark even when superseded: the file is warm on
                        // disk now, and the reveal queue only admits ids
                        // in the current result set, so this is harmless.
                        if (code === 0) {
                            const ids = Object.assign({}, root.previewIds);
                            if (!ids[t.id]) {
                                ids[t.id] = true;
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

    // Build page-number buttons:
    // show "1 ..." if page > 3, then a window of ~(width/100+2) pages;
    // current page labelled with refresh glyph, others with the number.
    function buildPageButtons() {
        return BooruUtils.buildPageButtons(root.widgetWidth, root.page);
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
    // On new images: slide new page in from the travel direction,
    // scroll to top; first render appears without transition.
    // New results invalidate the anchor card → drop the dialog at once
    // (the scroll reset below would auto-close it a frame later anyway).
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

    // Follow external Settings.booru changes (file reload, bookmark script
    // response): keep viewer state in sync without refetching here — tab
    // switches already load/fetch at their call sites. Guards prevent
    // feedback loops with our own writes.
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
            // Drain one card per tick: the sequential pop-in.
            const q = root._revealQueue || [];
            if (q.length === 0) {
                _revealTimer.stop();
                return;
            }
            const key = q[0];
            root._revealQueue = q.slice(1);
            // Skip ids that vanished from the current result set.
            const stillThere = (root.images || []).some(img => img && String(img.id) === String(key));
            if (!stillThere)
                return;
            const ids = Object.assign({}, root.revealedIds);
            ids[String(key)] = true;
            root.revealedIds = ids;
            if (root._revealQueue.length === 0)
                _revealTimer.stop();
        }
    }

    Timer {
        id: _bootTimer

        interval: 200
        repeat: true
        onTriggered: root.boot()
    }

    // ColumnLayout (NOT Column): the ScrollView needs Layout.fillHeight to
    // claim remaining space — in a plain Column fillHeight is ignored and
    // the grid collapses to zero height (images "not displayed").
    ColumnLayout {
        // Grid claims the full widget width at all times: the detail is a
        // floating popup (below), so opening it never resizes or relayouts
        // the grid, navigation or settings panels.
        anchors.fill: parent
        spacing: 10

        // Image masonry grid (Flickable: ScrollView hides contentY, and
        // scrolls to top after every page transition)
        Booru.BooruGrid {
            id: grid

            viewer: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Tabs + page buttons + prev/reveal/next live in BooruNavigation
        // (BooruToolbar was merged into it).
        // NOTE: bookmark toggling lives in the shared BooruActions service
        // (booru.py toggle-bookmark); no local Process component needed.

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

    // Floating detail popup: separate window surface docked to the island's
    // right edge, spanning the full viewer height. The surface itself is
    // STATIC — positioned once at show time, never repositioned — and the
    // card glides inside it (y binding + Behavior below). That is the
    // whole smoothness audit: moving the window costs an xdg-popup
    // configure round-trip per tick (the old stutter); moving content
    // inside a static surface is a local vsync repaint. Overlaps the
    // overlaps the island edge by 4px for an attached look (popups render above).
    PopupWindow {
        id: detailPopup
        anchor.item: root
        anchor.rect.x: Math.round(root.width - 4)
        anchor.rect.y: 0
        anchor.rect.width: 1
        anchor.rect.height: 1
        // Defaults (edges Top|Left, gravity Bottom|Right) already mean:
        // top-left corner at the rect, expanding down-right. No overrides.
        // Wider than the old 232px: the overhauled dialog uses 2-col
        // action grids + meta/tag pills that need the breathing room.
        width: 288
        height: Math.max(48, Math.round(root.height))
        // Gated on the host being actually shown: dialogImage alone
        // outlives island close / tab switch (cached Loader), which left
        // an orphan popup on screen. closeDialogNow() clears the image
        // right after; this guard covers the debounce gap. Hidden while
        // detached — the card lives in the FloatingWindow below instead.
        visible: root.dialogImage !== null && !root.dialogDetached && BarState.state === "left" && (!root.hostPanel || root.hostPanel.selectedWidget === "BooruViewer")
        color: "transparent"
        // Clickthrough everywhere except the card: the surface is
        // viewer-tall, so without this the transparent strip would eat
        // clicks meant for windows behind it. Region tracks the gliding
        // card via plain bindings (piggybacked surface commits, no
        // reposition handshake).
        mask: Region {
            x: popupDialog.x
            y: popupDialog.y
            width: popupDialog.width
            height: popupDialog.height
        }

        Booru.BooruDialog {
            id: popupDialog
            viewer: root
            width: parent.width
            // Glide track: viewer coords == popup coords vertically (the
            // anchor pins popup-top to viewer-top), kept real-valued for
            // subpixel motion. The Behavior trails fast flicks into a
            // glide; close decisions use the unanimated math, so timing
            // never drifts.
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

    // Detached card window: a normal top-level OS window. Float behavior
    // is the compositor's job — add a Hyprland rule on this title, e.g.
    // `windowrule = float, match:title ^(Booru)`. Same card component as
    // the docked popup, bound to the same viewer state; content fills the
    // window. Independent lifetime: island close / tab switch / new
    // results never touch it — only explicit close does.
    FloatingWindow {
        id: detailFloat
        title: root.dialogImage ? `Booru #${root.dialogImage.id}` : "Booru"
        visible: root.dialogImage !== null && root.dialogDetached
        width: 340
        height: 480
        minimumSize: Qt.size(240, 200)
        color: "transparent"

        // If the window dies behind our back (WM close button / keybind
        // kill), quickshell flips visible without touching our state, and
        // the true-valued binding above never re-pushes — every later
        // open would no-op onto a dead surface. Resync to closed so the
        // next open starts clean. Programmatic closes set detached=false
        // first, so they never trip this guard.
        onVisibleChanged: {
            if (!visible && root.dialogDetached && root.dialogImage !== null) {
                _closeTimer.stop();
                root.detailSlide = 0;
                root.dialogDetached = false;
                root.floatSized = false;
                root.dialogImage = null;
            }
        }

        Booru.BooruDialog {
            anchors.fill: parent
            viewer: root
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
