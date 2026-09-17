import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets.shared

// WallpaperPanelBody — pick a wallpaper per workspace, or set the sddm
// background, browse a category, add a new wallpaper, or delete one.
//
// Lives in its own widgets/wallpaperPanel folder (same pattern as
// widgets/controlPanel/ControlPanelBody) and is hosted by WallpaperIsland
// in the main bar pill. Hosts size this Item (implicit 960x360) and call
// refresh() when it becomes visible.
//
// Previews render the original files directly via AppImage (Qt Quick
// Image, asynchronous + sourceSize-constrained) — no thumbnail files.
Item {
    id: root

    // Island owner passes the bar's monitor; falls back to focused.
    property string monitorName: ""
    readonly property string effectiveMonitor: root.monitorName || Registry.monitorName

    implicitWidth: 960
    // True-height island: the results area is settings-sized (rows × tile
    // height), so the body reports its content height and WallpaperIsland
    // grows to fit instead of clipping a fixed 360.
    implicitHeight: mainCol.implicitHeight + 24

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperScript: home + "/.config/quickshell/archeclipse/scripts/get-wallpapers.sh"
    readonly property string setScript: home + "/.config/hypr/wallpaper-daemon/set-wallpaper.sh"
    readonly property string reloadScript: home + "/.config/hypr/wallpaper-daemon/reload.sh"

    function isVideoFile(file) {
        return /\.(mp4|webm|mkv|mov)$/i.test(file);
    }

    // ---------------------------------------------------------------- state

    readonly property var targetTypes: ["workspace", "sddm"]
    property string targetType: "workspace"
    property int selectedWorkspaceId: 1

    // Phased progress (text label in the action bar, no spinner):
    // idle | searching | downloading | setting | deleting | adding
    // | reloading | loading (generic fallback) | success | error.
    // Each flow sets its phase; success/error auto-reset to idle after 1.5s.
    property string progressStatus: "idle"
    readonly property string progressText: {
        switch (root.progressStatus) {
        case "searching": return "Searching…";
        case "downloading": return "Downloading…";
        case "setting": return "Setting…";
        case "deleting": return "Deleting…";
        case "adding": return "Adding…";
        case "reloading": return "Reloading…";
        case "loading": return "Working…";
        case "success": return "Done";
        case "error": return "Failed";
        default: return "";
        }
    }
    readonly property string progressColor: {
        if (root.progressStatus === "success")
            return Theme.fg;
        if (root.progressStatus === "error")
            return Theme.color1;
        if (root.progressStatus === "idle")
            return Theme.fgDim;
        return Theme.accent;
    }
    function setProgress(status) {
        progressStatus = status;
        if (status === "success" || status === "error")
            progressResetTimer.restart();
    }
    Timer {
        id: progressResetTimer
        interval: 1500
        onTriggered: root.progressStatus = "idle"
    }

    property var wallpapers: ({})               // category -> [paths]
    property string _lastWallpapersJson: ""
    readonly property var categories: Object.keys(wallpapers)
    // Single source of truth: Settings.wallpaperCategory. This binding is NEVER
    // assigned locally, so it can't desync like a mirrored var: every
    // writer goes through Settings.updateSetting (immediate persist) and
    // every reader — grid, combobox — follows the binding.
    readonly property string selectedCategory: Settings.wallpaperCategory
    // Self-heal a saved category that no longer exists (dir deleted).
    // Gated on ready + non-empty categories so a fast fetch can't clobber
    // the saved value before Settings.reload() has adopted the file.
    function validateCategory() {
        if (!Settings.ready || root.categories.length === 0)
            return;
        if (!root.categories.includes(Settings.wallpaperCategory))
            Settings.updateSetting("wallpaperSwitcher.category", root.categories[0]);
    }
    // ComboBox sets currentIndex internally on user pick and resets it
    // to 0 on model replacement, which breaks/clobbers any currentIndex
    // binding — re-sync imperatively, deferred past the ComboBox's own
    // model-reset handling (it runs after our change handlers).
    function syncCategoryCombo() {
        Qt.callLater(() => {
            const i = root.categories.indexOf(root.selectedCategory);
            if (categoryCombo.currentIndex !== i)
                categoryCombo.currentIndex = i;
        });
    }
    Connections {
        target: Settings
        function onWallpaperCategoryChanged() {
            root.validateCategory();
            root.syncCategoryCombo();
        }
    }
    onCategoriesChanged: {
        root.validateCategory();
        root.syncCategoryCombo();
    }
    readonly property var selectedWallpapers: wallpapers[selectedCategory] ?? []
    // Capture must wait for data/thumbnail generation and masonry aspect updates;
    // CaptureIpc separately checks instantiated tiles (including opacity-zero ones).
    readonly property bool captureReady: !fetchProc.running && !thumbProc.running && !_thumbPending
        && !whLoading && Object.keys(_pendingAspect).length === 0
        && (progressStatus === "idle" || progressStatus === "success")
        && (isWallhaven ? whResults.length > 0 : selectedWallpapers.length > 0)
    // Exposed for Ipc wallpaperDiag ("strip" query) and tests.
    readonly property alias wallStrip: wallScroll
    // Test hook for the "stripdeep" diag: lets automation walk the local
    // masonry geometry (rows, cellX/cellW, inWindow) without a mouse.
    readonly property alias localMasonry: localMasonry

    // ------------------------------------------------- provider abstraction
    // Generic provider schema: "local" reuses the folder categories above
    // (default/* + custom, no special-casing); "wallhaven" queries the
    // wallhaven.cc API and downloads full-res files into wallhaven/
    // (save + apply), after which the local apply/delete/theme pipeline
    // takes over unchanged. Each provider declares its params; the panel
    // renders them below (category combo vs. the Wallhaven filter form).
    readonly property var providerTypes: ["local", "wallhaven"]
    readonly property string provider: Settings.wallpaperProvider
    readonly property var wh: Settings.wallpaperWallhaven
    readonly property string whApiKey: Settings.apiKey("wallhaven", "key")
    readonly property bool isWallhaven: root.provider === "wallhaven"

    // Shared masonry view (both providers, persisted): exact results-area
    // height from rows × tile height (+ row gaps + scrollbar room). Tile
    // widths come from aspect ratios, never from the viewport.
    readonly property real resultsH: Math.max(1, Settings.wallpaperMasonryRows) * Settings.wallpaperTileSize + (Math.max(1, Settings.wallpaperMasonryRows) - 1) * 6 + 12
    function setMasonryRows(n) {
        Settings.updateSetting("wallpaperSwitcher.masonryRows", Math.min(4, Math.max(1, n)));
    }
    // Decoded-aspect cache for local files (path -> w/h). Reassigned, never
    // mutated, so the masonry recomputes exactly like selectedWallpapers
    // does on fetch. Unknown paths fall back to 16:9 until their thumb
    // decodes and reports in (brief reshuffle on first open, then stable).
    property var localAspect: ({})
    function localAspectOf(path) {
        const r = root.localAspect[path] || 0;
        return r > 0 ? r : 16 / 9;
    }
    // Batched aspect reports: thumbs decode in a storm on open (100+
    // files), and every cache reassign recomputes the masonry + rebuilds
    // Repeaters. Collect here, adopt once 250ms after the last report.
    property var _pendingAspect: ({})
    Timer {
        id: aspectFlush
        interval: 250
        onTriggered: {
            if (Object.keys(root._pendingAspect).length === 0)
                return;
            root.localAspect = Object.assign({}, root.localAspect, root._pendingAspect);
            root._pendingAspect = {};
        }
    }
    function noteLocalAspect(path, ratio) {
        if (!isFinite(ratio) || ratio <= 0)
            return;
        const cur = root.localAspect[path] || root._pendingAspect[path] || 0;
        if (Math.abs(cur - ratio) < 0.01)
            return;
        root._pendingAspect[path] = ratio;
        aspectFlush.restart();
    }
    // Wallhaven aspects are known up-front from the resolution string.
    function whAspect(item) {
        const m = String((item && item.resolution) || "").split("x");
        const w = parseFloat(m[0]), h = parseFloat(m[1]);
        return (w > 0 && h > 0) ? w / h : 16 / 9;
    }

    readonly property string wallhavenScript: home + "/.config/quickshell/archeclipse/scripts/wallhaven.py"
    readonly property string wallhavenDir: home + "/.config/wallpapers/wallhaven"

    // First-frame thumbnails for video tiles (offline, zero decoders):
    // gen-video-thumbs.sh extracts one 320px frame per video into the
    // cache dir and prints a {srcPath: thumbPath} manifest on stdout.
    // thumbMap adopts it when the run finishes; until then (or when a
    // video has no thumb) tiles keep the icon + filename fallback below.
    // Thumb names are deterministic (sanitized path + ".jpg", ASCII only)
    // but QML reads them ONLY via the manifest — never derive locally.
    readonly property string thumbScript: home + "/.config/quickshell/archeclipse/scripts/gen-video-thumbs.sh"
    property var thumbMap: ({})
    function thumbFor(path) {
        if (path === undefined || !root.isVideoFile(path))
            return "";
        return root.thumbMap[path] || "";
    }

    // Wallhaven filter option models (static; index-synced like categoryCombo).
    // atleast/ratios use "Any" as the display label for the empty (omit) value.
    readonly property var whSortingItems: ["date_added", "relevance", "random", "views", "favorites", "toplist"]
    readonly property var whOrderItems: ["desc", "asc"]
    readonly property var whTopRangeItems: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]
    readonly property var whAtleastItems: ["Any", "1920x1080", "2560x1440", "3840x2160"]
    readonly property var whRatioItems: ["Any", "16x9", "16x10", "21x9", "9x16", "1x1", "4x3", "32x9"]
    function whMapped(v, items) {
        return (v === "" ? items[0] : v);
    }
    function whUnmap(v, items) {
        return (v === items[0] ? "" : v);
    }

    // Read-modify-write one Wallhaven filter through updateSetting (new
    // object identity, so the wh binding re-evaluates like selectedCategory).
    // Filter edits reset to page 1 and debounce past typing; page turns pass
    // immediate=true to search at once.
    function setWh(key, value, immediate) {
        const next = Object.assign({}, root.wh);
        next[key] = value;
        if (key !== "page")
            next.page = 1;
        Settings.updateSetting("wallpaperSwitcher.wallhaven", next);
        if (immediate)
            root.whSearch();
        else
            whDebounce.restart();
    }

    property var whResults: []
    property var whMeta: ({
            page: 1,
            per_page: 24,
            total: 0,
            last_page: 1,
            seed: ""
        })
    property bool whLoading: false
    property int _whSeq: 0
    property string _whErr: ""
    property string _whDownloadedPath: ""
    property string _pendingWhApply: "" // "apply" | "" (save only)
    Timer {
        id: whDebounce
        interval: 400
        onTriggered: root.whSearch()
    }
    // Key added/removed while browsing: a removed key must drop an NSFW
    // purity the guest API would 401 on; either way re-run the search.
    onWhApiKeyChanged: {
        if (!root.isWallhaven)
            return;
        if (root.whApiKey === "" && root.wh.purity.charAt(2) === "1")
            root.setWh("purity", "100");
        else
            root.whSearch();
    }
    onProviderChanged: {
        // NOTE: read root.provider (the property that just changed), NOT
        // root.isWallhaven: dependent bindings re-evaluate AFTER change
        // handlers run, so isWallhaven still holds the OLD value here.
        // The handler passes force=true (after checking root.provider,
        // always fresh in its own handler) so whSearch's own guard —
        // which reads the same stale binding — doesn't bail.
        if (root.provider === "wallhaven")
            root.whSearch(true);
    }

    property var currentWallpapers: []           // path per workspace index, this monitor

    Component.onCompleted: {
        fetchWallpapers();
        fetchCurrentWallpapers();
        const ws = Hyprland.focusedWorkspace;
        if (ws)
            root.selectedWorkspaceId = ws.id;
        if (root.isWallhaven)
            root.whSearch();
    }

    // Hosts call this when the body becomes visible.
    function refresh() {
        fetchWallpapers();
        fetchCurrentWallpapers();
        if (root.isWallhaven)
            root.whSearch();
    }

    // Re-fetch when the bar delivers the real monitor name (onLoaded
    // fires after our Component.onCompleted, so the first fetch may have
    // used the Registry fallback which can resolve to the wrong monitor).
    onMonitorNameChanged: {
        if (root.monitorName !== "")
            fetchCurrentWallpapers();
    }

    // Keep the selected workspace synced to whatever's focused when the
    // switcher opens.
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            const ws = Hyprland.focusedWorkspace;
            if (ws)
                root.selectedWorkspaceId = ws.id;
        }
    }

    function notifyError(context, err) {
        setProgress("error");
        console.warn("[WallpaperSwitcher]", context, err);
        Notifications.notify({
            summary: "Error",
            body: String(err)
        }); // adjust to your notify service
    }

    // ---------------------------------------------------------- data fetch

    Process {
        id: fetchProc
        command: ["bash", root.wallpaperScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Skip no-change adoptions: every reassign rebuilds the
                    // masonry + re-decodes all tiles (visible flicker), so a
                    // refresh that returns identical JSON must be a no-op.
                    if (text === root._lastWallpapersJson)
                        return;
                    root._lastWallpapersJson = text;
                    root.wallpapers = JSON.parse(text);
                    root.runThumbGen();
                } catch (e) {
                    root.notifyError("fetching wallpapers", e);
                }
            }
        }
    }
    function fetchWallpapers() {
        fetchProc.running = true;
    }

    // Background thumb run over every known local video (fresh ones skip
    // on mtime inside the script, so re-runs are cheap). Single-flight:
    // a fetch storm while a run is active re-runs once on exit.
    property bool _thumbPending: false
    Process {
        id: thumbProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = JSON.parse(text);
                    // Incremental runs only cover missing videos — merge so
                    // earlier entries survive (same reassign-not-mutate rule
                    // as localAspect, so bindings re-evaluate).
                    if (m && typeof m === "object")
                        root.thumbMap = Object.assign({}, root.thumbMap, m);
                } catch (e) {
                    console.warn("[WallpaperSwitcher] thumb manifest parse failed", e);
                }
            }
        }
        onExited: {
            if (root._thumbPending) {
                root._thumbPending = false;
                root.runThumbGen();
            }
        }
    }
    function runThumbGen() {
        if (thumbProc.running) {
            root._thumbPending = true;
            return;
        }
        const vids = [];
        const cats = root.wallpapers || {};
        for (const k in cats) {
            const list = cats[k] || [];
            for (let i = 0; i < list.length; i++)
                if (root.isVideoFile(list[i]) && !root.thumbMap[list[i]])
                    vids.push(list[i]);
        }
        if (vids.length === 0)
            return;
        thumbProc.command = ["bash", root.thumbScript].concat(vids);
        thumbProc.running = true;
    }

    Process {
        id: fetchCurrentProc
        command: ["bash", root.wallpaperScript, "--current", root.effectiveMonitor]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.currentWallpapers = JSON.parse(text).map(String);
                } catch (e) {
                    root.notifyError("fetching current wallpapers", e);
                }
            }
        }
    }
    function fetchCurrentWallpapers() {
        fetchCurrentProc.running = true;
    }

    // ------------------------------------------------- wallhaven provider

    function whSearch(force) {
        // NOTE: never gate on root.isWallhaven alone here: this is called
        // from onProviderChanged, where dependent bindings haven't
        // re-evaluated yet and isWallhaven still holds the OLD value
        // (local->wallhaven bailed forever with empty results). The
        // handler passes force=true after checking root.provider itself,
        // which is always fresh inside its own change handler.
        if (!force && !root.isWallhaven)
            return;
        root._whSeq++;
        const seq = root._whSeq;
        root.whLoading = true;
        setProgress("searching");
        const w = root.wh;
        const cmd = ["python3", root.wallhavenScript, "--search", "--categories", w.categories, "--purity", w.purity, "--sorting", w.sorting, "--order", w.order, "--page", String(w.page)];
        if (w.q !== "")
            cmd.push("--q", w.q);
        if (w.sorting === "toplist" && w.topRange !== "")
            cmd.push("--top-range", w.topRange);
        if (w.atleast !== "")
            cmd.push("--atleast", w.atleast);
        if (w.ratios !== "")
            cmd.push("--ratios", w.ratios);
        // Random paging repeats without the seed the API returned.
        if (w.sorting === "random" && root.whMeta.seed !== "")
            cmd.push("--seed", root.whMeta.seed);
        if (root.whApiKey !== "")
            cmd.push("--api-key", root.whApiKey);
        whSearchProc._seq = seq;
        whSearchProc.command = cmd;
        whSearchProc.running = true;
    }

    Process {
        id: whSearchProc
        property int _seq: 0
        stdout: StdioCollector {
            onStreamFinished: {
                // Stale guard: rapid filter edits fire overlapping searches.
                if (whSearchProc._seq !== root._whSeq)
                    return;
                root.whLoading = false;
                try {
                    const payload = JSON.parse(text);
                    root.whResults = payload.data || [];
                    const m = payload.meta || {};
                    root.whMeta = {
                        page: m.page ?? root.wh.page,
                        per_page: m.per_page ?? (payload.data || []).length,
                        total: m.total ?? 0,
                        last_page: m.last_page ?? root.wh.page,
                        seed: m.seed ?? ""
                    };
                    root.progressStatus = "idle";
                } catch (e) {
                    root.notifyError("searching wallhaven", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._whErr = text;
            }
        }
        onExited: code => {
            if (whSearchProc._seq !== root._whSeq)
                return;
            root.whLoading = false;
            if (code !== 0) {
                let msg = "search failed (exit " + code + ")";
                try {
                    msg = JSON.parse(root._whErr).message || msg;
                } catch (e) {}
                root.notifyError("searching wallhaven", msg);
            }
        }
    }

    // Save + apply flow: download the full-res file into wallhaven/ (it
    // becomes a permanent local category), then reuse applyWallpaper so
    // theme regen / workspace badges / delete all behave identically.
    // Right-click saves without applying.
    function whSaveApply(item, apply) {
        if (!item || whDownloadProc.running)
            return;
        const base = ((item.full !== "" ? item.full : item.id).split("/").pop().split("?")[0]) || (item.id + ".jpg");
        const dest = root.wallhavenDir + "/" + base;
        setProgress("downloading");
        root._pendingWhApply = apply ? "apply" : "";
        root._whDownloadedPath = "";
        const cmd = ["python3", root.wallhavenScript, "--download", item.id, "--dest", dest];
        if (item.full !== "")
            cmd.push("--full-url", item.full);
        if (root.whApiKey !== "")
            cmd.push("--api-key", root.whApiKey);
        whDownloadProc.command = cmd;
        whDownloadProc.running = true;
    }

    Process {
        id: whDownloadProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._whDownloadedPath = JSON.parse(text).path || "";
                } catch (e) {
                    root._whDownloadedPath = "";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._whErr = text;
            }
        }
        onExited: code => {
            const doApply = root._pendingWhApply === "apply";
            const path = root._whDownloadedPath;
            root._pendingWhApply = "";
            if (code === 0 && path !== "") {
                // The wallhaven/ dir shows up as a local category; the
                // apply path below owns progress from here (theme regen).
                root.fetchWallpapers();
                if (doApply) {
                    root.applyWallpaper(path);
                } else {
                    Notifications.notify({
                        summary: "Success",
                        body: "Wallpaper saved to wallhaven."
                    });
                    root.setProgress("success");
                }
            } else {
                let msg = "download failed (exit " + code + ")";
                try {
                    msg = JSON.parse(root._whErr).message || msg;
                } catch (e) {}
                root.notifyError("saving wallhaven wallpaper", msg);
            }
        }
    }

    // ----------------------------------------------------------- set/apply

    Process {
        id: setProc
        onExited: code => {
            if (code === 0) {
                root.fetchCurrentWallpapers();
                // Share the global theme: regenerate pywal/cwal colors from
                // the new wallpaper (wal-theme.sh honors autocolor=false
                // itself; _pendingThemeRegen is only set when workspace
                // target + Settings.dynamicThemeColors).
                if (root._pendingThemeRegen !== "")
                    root.regenTheme(root._pendingThemeRegen);
                else
                    root.setProgress("success");
            } else {
                root._pendingThemeRegen = "";
                root.setProgress("error");
            }
        }
    }

    function commandFor(target, path) {
        switch (target) {
        case "sddm":
            return ["pkexec", "bash", "-c", `sed -i "s|^background=.*|background=${path}|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf`];
        default:
            // workspace
            return [root.setScript, String(root.selectedWorkspaceId), root.effectiveMonitor, path];
        }
    }

    function applyWallpaper(path) {
        setProgress("setting");
        root._pendingThemeRegen = (root.targetType === "workspace" && Settings.dynamicThemeColors) ? path : "";
        setProc.command = commandFor(root.targetType, path);
        setProc.running = true;
    }

    // ---- global theme sharing (wal-theme.sh -> cwal colors.scss -> Theme) ----
    property string _pendingThemeRegen: ""
    readonly property string walThemeScript: home + "/.config/hypr/theme/scripts/wal-theme.sh"
    Process {
        id: themeProc
        onExited: code => {
            // Variant may have auto-switched (autovariant) — re-read it so
            // the ControlPanel toggle and GlobalTheme state stay correct.
            GlobalTheme.refresh();
            if (code === 0)
                root.setProgress("success");
            else
                root.notifyError("updating theme colors", "wal-theme.sh failed");
        }
    }
    function regenTheme(path) {
        root._pendingThemeRegen = "";
        themeProc.command = ["bash", root.walThemeScript, path];
        themeProc.running = true;
    }

    function setRandomWallpaper() {
        const list = root.selectedWallpapers;
        if (list.length === 0)
            return;
        applyWallpaper(list[Math.floor(Math.random() * list.length)]);
    }

    // -------------------------------------------------------------- delete

    Process {
        id: deleteProc
        onExited: code => {
            root.fetchWallpapers();
            if (code === 0) {
                Notifications.notify({
                    summary: "Success",
                    body: "Wallpaper deleted successfully!"
                });
                root.setProgress("success");
            } else {
                root.setProgress("error");
            }
        }
    }
    function deleteWallpaper(path) {
        setProgress("deleting");
        deleteProc.command = ["bash", "-c", `rm -f ${JSON.stringify(path)}`];
        deleteProc.running = true;
    }

    // ----------------------------------------------------------- daemon reload

    Process {
        id: reloadProc
        onExited: code => {
            if (code === 0)
                root.fetchWallpapers();
            root.setProgress(code === 0 ? "success" : "error");
        }
    }
    function reloadDaemon() {
        setProgress("reloading");
        reloadProc.command = ["bash", "-c", root.reloadScript];
        reloadProc.running = true;
    }

    // --------------------------------------------------------- add wallpaper

    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--title=Select Wallpaper", "--file-filter=Images (png, jpg, webp, gif, mp4) | *.png *.jpg *.jpeg *.webp *.gif *.mp4"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0)
                    root.importWallpaper(path);
                else
                    root.progressStatus = "idle";
            }
        }
        onExited: code => {
            // zenity exits 1 on Cancel — that's not a real error.
            if (code !== 0 && code !== 1)
                root.setProgress("error");
        }
    }
    function pickWallpaper() {
        pickProc.running = true;
    }

    Process {
        id: importProc
        onExited: code => {
            if (code === 0) {
                Notifications.notify({
                    summary: "Success",
                    body: "Wallpaper added successfully!"
                });
                root.fetchWallpapers();
                root.setProgress("success");
            } else {
                root.notifyError("adding wallpaper", "copy step failed");
            }
        }
    }
    function importWallpaper(sourcePath) {
        setProgress("adding");
        const targetDir = root.home + "/.config/wallpapers/custom";
        const basename = sourcePath.split("/").pop();
        const targetPath = targetDir + "/" + basename;

        importProc.command = ["bash", "-c", `mkdir -p ${JSON.stringify(targetDir)} && ` + `cp -- ${JSON.stringify(sourcePath)} ${JSON.stringify(targetPath)}`];
        importProc.running = true;
    }

    // cached file sizes for tooltip (path -> bytes), one stat per path.
    // Path passed as argv (no shell quoting) so names with quotes still work.
    property var fileSizes: ({})
    function getFileSize(path) {
        if (root.fileSizes[path] !== undefined)
            return root.fileSizes[path];
        const p = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        p.command = ["stat", "-c", "%s", path];
        p.running = true;
        p.stdout.onStreamFinished.connect(function () {
            const sz = parseInt(p.stdout.text.trim()) || 0;
            const fs = root.fileSizes;
            fs[path] = sz;
            root.fileSizes = fs;
            p.destroy();
        });
        return 0;
    }
    function formatBytes(bytes) {
        if (bytes === 0)
            return "N/A";
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        let b = bytes;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            i++;
        }
        return b.toFixed(i === 0 ? 0 : 1) + " " + units[i];
    }

    // ------------------------------------------------------------------ UI

    Rectangle {
        id: wallpaperSwitcher
        anchors.fill: parent
        color: "transparent"
        radius: Theme.radius

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // per-workspace current wallpaper strip
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Repeater {
                    model: root.currentWallpapers
                    delegate: Rectangle {
                        id: wsTile
                        required property string modelData
                        required property int index
                        readonly property bool isFocused: Hyprland.focusedWorkspace?.id === index + 1

                        width: 100
                        height: 66
                        radius: 6
                        color: modelData === "" ? "black" : "transparent"
                        border.width: isFocused ? 1 : 0
                        border.color: Theme.muted

                        AppImage {
                            visible: wsTile.modelData !== ""
                            anchors.fill: parent
                            anchors.margins: 2
                            // Native preview: original file, decoded near
                            // tile size (async + cached inside AppImage).
                            // Videos play live below (wsVideo) — empty
                            // source here keeps just the badges.
                            source: (wsTile.modelData === "" || root.isVideoFile(wsTile.modelData)) ? "" : "file://" + wsTile.modelData
                            sourceWidth: wsTile.width
                            badges: [(wsTile.index + 1).toString()]
                        }
                        // Live animated preview for workspace videos: ALWAYS
                        // live (restored ac33749c behavior — the hover-only
                        // gate added in the masonry refactor left the decoder
                        // off, so video tiles showed the icon forever).
                        // Unlike the main strip (100+ videos), this strip
                        // holds one tile per workspace, so always-on decoders
                        // stay cheap. The icon below stays until the first
                        // frame lands, or permanently on decode failure.
                        readonly property bool wsPreviewing: wsTile.modelData !== "" && root.isVideoFile(wsTile.modelData)
                        AppVideo {
                            id: wsVideo
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: wsTile.wsPreviewing
                            source: wsTile.wsPreviewing ? wsTile.modelData : ""
                            active: wsTile.wsPreviewing
                            muted: true
                            fillMode: VideoOutput.PreserveAspectCrop
                            badges: [(wsTile.index + 1).toString()]
                            onErrorOccurred: message => {
                                console.warn("[WallpaperSwitcher] video preview failed for " + wsTile.modelData + ": " + message);
                            }
                        }
                        Text {
                            visible: wsTile.modelData !== "" && root.isVideoFile(wsTile.modelData) && (!wsVideo.ready || wsVideo._failed)
                            anchors.centerIn: parent
                            text: ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            color: Theme.fgDim
                        }
                        Text {
                            visible: wsTile.modelData === ""
                            anchors.centerIn: parent
                            text: "No Wallpaper"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                        }
                    }
                }
            }

            // action bar — wrapped so radius / bg / border apply as one pill
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: actionBar.implicitWidth + 24
                implicitHeight: actionBar.implicitHeight + 16
                radius: Theme.radius
                color: Theme.surface

                clip: true

                RowLayout {
                    id: actionBar
                    anchors.centerIn: parent
                    spacing: 10

                    // Provider switch: local folders vs. wallhaven.cc API.
                    AppSegmentedControl {
                        model: root.providerTypes
                        currentIndex: root.providerTypes.indexOf(root.provider)
                        onActivated: (i, v) => Settings.updateSetting("wallpaperSwitcher.provider", v)
                    }

                    AppSegmentedControl {
                        model: root.targetTypes
                        currentIndex: root.targetTypes.indexOf(root.targetType)
                        onActivated: (i, v) => root.targetType = v
                    }

                    // pywal palette swatches (color1..7)
                    Row {
                        spacing: 6
                        Repeater {
                            model: [Theme.color0, Theme.color1, Theme.color2, Theme.color3, Theme.color4, Theme.color8, Theme.fg]
                            delegate: Rectangle {
                                required property string modelData
                                width: 12
                                height: 12
                                radius: 6
                                color: modelData
                            }
                        }
                    }

                    AppComboBox {
                        id: categoryCombo
                        objectName: "categoryCombo"
                        visible: !root.isWallhaven
                        model: root.categories
                        currentIndex: root.categories.indexOf(root.selectedCategory)
                        onActivated: i => Settings.updateSetting("wallpaperSwitcher.category", root.categories[i])
                    }

                    AppButton {
                        text: "Random"
                        visible: !root.isWallhaven
                        onClicked: root.setRandomWallpaper()
                    }
                    AppButton {
                        text: "Reload"
                        onClicked: root.reloadDaemon()
                    }
                    AppButton {
                        text: "Add…"
                        onClicked: root.pickWallpaper()
                    }

                    // Shared masonry view (both providers, persisted).
                    AppButton {
                        text: "‹"
                        enabled: Settings.wallpaperMasonryRows > 1
                        onClicked: root.setMasonryRows(Settings.wallpaperMasonryRows - 1)
                    }
                    Text {
                        text: Settings.wallpaperMasonryRows + (Settings.wallpaperMasonryRows === 1 ? " row" : " rows")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                    AppButton {
                        text: "›"
                        enabled: Settings.wallpaperMasonryRows < 4
                        onClicked: root.setMasonryRows(Settings.wallpaperMasonryRows + 1)
                    }
                    AppSlider {
                        Layout.preferredWidth: 90
                        from: 80
                        to: 200
                        stepSize: 10
                        value: Settings.wallpaperTileSize
                        onValueChanged: {
                            // Same binding guard as the booru sliders: the
                            // settings write re-evaluates value to the same
                            // number, which must not write back in a loop.
                            const v = Math.round(value);
                            if (v === Settings.wallpaperTileSize)
                                return;
                            Settings.updateSetting("wallpaperSwitcher.tileSize", v);
                        }
                    }
                    Text {
                        text: Settings.wallpaperTileSize + "px"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }

                    Text {
                        // Phased progress text (replaces the spinner): fixed
                        // width so phase changes don't jitter the action bar.
                        width: 110
                        elide: Text.ElideRight
                        text: root.progressText
                        color: root.progressColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            // wallhaven provider: dynamic filter form. Each control writes one
            // wallpaperWallhaven field via setWh (debounced search); the form
            // is the provider's declared params rendered with shared controls,
            // so a future provider reuses this pattern with its own fields.
            Rectangle {
                visible: root.isWallhaven
                Layout.fillWidth: true
                implicitHeight: whFilterCol.implicitHeight + 16
                radius: Theme.radius
                color: Theme.surface
                clip: true

                ColumnLayout {
                    id: whFilterCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    // filters: one wrapping row (query, sort, categories,
                    // purity, size) so every provider filter lives together.
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        AppTextField {
                            id: whQuery
                            width: 220
                            placeholderText: "Search wallhaven.cc (tags, e.g. mountains lake)…"
                            text: root.wh.q
                            onTextChanged: {
                                if (text !== root.wh.q)
                                    root.setWh("q", text);
                            }
                        }
                        AppComboBox {
                            model: root.whSortingItems
                            currentIndex: Math.max(0, root.whSortingItems.indexOf(root.wh.sorting))
                            onActivated: i => root.setWh("sorting", root.whSortingItems[i])
                        }
                        AppComboBox {
                            model: root.whOrderItems
                            currentIndex: Math.max(0, root.whOrderItems.indexOf(root.wh.order))
                            onActivated: i => root.setWh("order", root.whOrderItems[i])
                        }
                        AppComboBox {
                            visible: root.wh.sorting === "toplist"
                            model: root.whTopRangeItems
                            currentIndex: Math.max(0, root.whTopRangeItems.indexOf(root.wh.topRange))
                            onActivated: i => root.setWh("topRange", root.whTopRangeItems[i])
                        }
                        Text {
                            text: "Categories:"
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            height: 28
                            verticalAlignment: Text.AlignVCenter
                        }
                        Repeater {
                            model: ["General", "Anime", "People"]
                            delegate: AppButton {
                                required property string modelData
                                required property int index
                                readonly property bool on: root.wh.categories.charAt(index) === "1"
                                text: modelData
                                height: 24
                                pixelSize: Theme.fontSize - 2
                                idleBg: on ? Theme.surfaceActive : Theme.bg
                                idleFg: on ? Theme.accent : Theme.fg
                                hoverFg: on ? Theme.accent : Theme.fg
                                outlined: true
                                outlineColor: on ? Theme.accent : Theme.border
                                onClicked: {
                                    const bits = root.wh.categories.split("");
                                    bits[index] = bits[index] === "1" ? "0" : "1";
                                    if (bits.join("") === "000") {
                                        Notifications.notify({
                                            summary: "Wallhaven",
                                            body: "At least one category must stay on."
                                        });
                                        return;
                                    }
                                    root.setWh("categories", bits.join(""));
                                }
                            }
                        }
                        Text {
                            text: "Purity:"
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            height: 28
                            verticalAlignment: Text.AlignVCenter
                        }
                        Repeater {
                            model: [
                                {
                                    label: "SFW",
                                    value: "100"
                                },
                                {
                                    label: "Sketchy",
                                    value: "110"
                                },
                                {
                                    label: "NSFW",
                                    value: "111"
                                }
                            ]
                            delegate: AppButton {
                                required property var modelData
                                readonly property bool on: root.wh.purity === modelData.value
                                readonly property bool needsKey: modelData.value === "111"
                                enabled: !needsKey || root.whApiKey !== ""
                                text: modelData.label
                                height: 24
                                pixelSize: Theme.fontSize - 2
                                idleBg: on ? Theme.surfaceActive : Theme.bg
                                idleFg: on ? Theme.accent : Theme.fg
                                hoverFg: on ? Theme.accent : Theme.fg
                                outlined: true
                                outlineColor: on ? Theme.accent : Theme.border
                                tooltipText: (needsKey && root.whApiKey === "") ? "Needs a Wallhaven API key (Settings → API Keys)" : ""
                                onClicked: root.setWh("purity", modelData.value)
                            }
                        }
                        AppComboBox {
                            model: root.whAtleastItems
                            currentIndex: Math.max(0, root.whAtleastItems.indexOf(root.whMapped(root.wh.atleast, root.whAtleastItems)))
                            onActivated: i => root.setWh("atleast", root.whUnmap(root.whAtleastItems[i], root.whAtleastItems))
                        }
                        AppComboBox {
                            model: root.whRatioItems
                            currentIndex: Math.max(0, root.whRatioItems.indexOf(root.whMapped(root.wh.ratios, root.whRatioItems)))
                            onActivated: i => root.setWh("ratios", root.whUnmap(root.whRatioItems[i], root.whRatioItems))
                        }
                    }

                    // result count + page nav
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            text: root.whLoading ? "Searching…" : root.whMeta.total + " results • page " + root.whMeta.page + "/" + root.whMeta.last_page
                        }
                        AppButton {
                            text: "‹"
                            enabled: root.wh.page > 1 && !root.whLoading
                            onClicked: root.setWh("page", Math.max(1, root.wh.page - 1), true)
                        }
                        AppButton {
                            text: "›"
                            enabled: root.wh.page < root.whMeta.last_page && !root.whLoading
                            onClicked: root.setWh("page", root.wh.page + 1, true)
                        }
                    }
                }
            }

            // all wallpapers in the selected category — horizontal strip
            SmoothFlickable {
                id: wallScroll
                objectName: "wallStrip"
                visible: !root.isWallhaven
                Layout.fillWidth: true
                Layout.preferredHeight: root.resultsH
                flickableDirection: Flickable.HorizontalFlick
                contentWidth: localMasonry.contentWidth
                contentHeight: height
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                AppMasonryRow {
                    id: localMasonry
                    width: wallScroll.width
                    height: implicitHeight
                    rows: Settings.wallpaperMasonryRows
                    spacing: 6
                    rowHeight: Settings.wallpaperTileSize
                    // Preserve the (now alphabetically sorted) file order
                    // left-to-right instead of shortest-row bin-packing,
                    // which shuffled tiles every time aspects refined.
                    balanceRows: false
                    model: root.selectedWallpapers
                    aspectRatio: function (path) {
                        return root.localAspectOf(path);
                    }
                    // Lazy window: only instantiate tiles near the viewport
                    // (fast open on 100+ folders, left-to-right materialize
                    // on scroll, decoders freed when scrolled away).
                    viewLeft: wallScroll.contentX - 700
                    viewRight: wallScroll.contentX + wallScroll.width + 700
                    buffer: 700
                    placeholder: Rectangle {
                        color: Theme.surface
                        radius: 6
                    }
                    delegate: Rectangle {
                        id: tile
                        // Plain (not required) modelData — the masonry pushes
                        // it via Loader onLoaded (same contract as AppMasonry).
                        property var modelData
                        // Masonry widths are always aspect-derived (the old
                        // hover-expand would fight the layout). Each thumb
                        // reports its decoded ratio back, refining the width.
                        width: localMasonry.widthFor(modelData)
                        height: localMasonry.rowHeight
                        // Fades in once the preview settles — image decoded
                        // (Error counts as settled so a missing file can't
                        // hide a tile forever) or video ready (first frame
                        // or decode failure, which falls back to the icon
                        // below). modelData arrives via Loader push just
                        // after creation, so every access below is guarded.
                        // Idle video tiles show the offline first-frame thumb (no
                        // decoder); "" until the background run maps it, in
                        // which case the icon fallback below holds the tile.
                        readonly property string tileThumb: root.thumbFor(tile.modelData)
                            readonly property bool thumbSettled: (tile.modelData !== undefined && root.isVideoFile(tile.modelData)) ? (tile.previewing ? tileVideo.ready : (tile.tileThumb === "" || tileImg.status === Image.Ready || tileImg.status === Image.Error)) : (tileImg.status === Image.Ready || tileImg.status === Image.Error)
                        // Workspace number badges: which workspace(s)
                        // currently use this wallpaper (top-right).
                        // Shared by the still preview and the live
                        // video below (only one is visible at a time).
                        readonly property var badgeIds: {
                            const ids = [];
                            const cur = root.currentWallpapers;
                            for (let i = 0; i < cur.length; i++) {
                                if (cur[i] !== "" && cur[i] === tile.modelData)
                                    ids.push(String(i + 1));
                            }
                            return ids;
                        }
                        opacity: tile.thumbSettled ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                        // Stagger timers and hover-expand are gone: widths
                        // are masonry-owned (see delegate header).
                        readonly property string fileName: tile.modelData === undefined ? "" : String(tile.modelData).split("/").pop()
                        radius: 6
                        color: tileMa.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.width: tileMa.containsMouse ? 2 : 0
                        border.color: Theme.muted

                        AppImage {
                            id: tileImg
                            anchors.fill: parent
                            anchors.margins: 3
                            // Native preview: original file decoded near
                            // tile size (asynchronous + cached; the
                            // strip's virtualized Repeater keeps the
                            // instance count bounded while scrolling).
                            // Videos show the offline first-frame thumb
                            // (empty until the background run maps it —
                            // the icon below holds the tile meanwhile).
                            source: (tile.modelData === undefined) ? "" : (root.isVideoFile(tile.modelData) ? (tile.tileThumb !== "" ? "file://" + tile.tileThumb : "") : "file://" + tile.modelData)
                            // Decode at a stable width: binding sourceWidth to
                            // the aspect-derived tile.width reloaded the image
                            // on every aspect refine (width change -> reload
                            // -> opacity dip -> fade = flicker). Tile height
                            // is the fixed rowHeight, so one size fits all.
                            sourceWidth: Math.max(1, Math.round(Settings.wallpaperTileSize * 2))
                            badges: tile.badgeIds
                            onStatusChanged: {
                                if (tileImg.status === Image.Ready && tileImg.implicitImageWidth > 0 && tileImg.implicitImageHeight > 0)
                                    root.noteLocalAspect(tile.modelData, tileImg.implicitImageWidth / tileImg.implicitImageHeight);
                            }
                        }
                            // Live video preview (MP4/WebM): shared AppVideo,
                            // muted + looping, cropped like the static tiles.
                            // Plays ON HOVER ONLY: a video folder opens ~25
                            // tiles in-window and each decoder eats a full
                            // file (103×15MB in grey/), so autoplaying all
                            // of them freezes the panel. Non-hovered tiles
                            // show the icon fallback below (same look as a
                            // failed decode); empty source = zero decoder work.
                            // No viewport gating (masonry positions are
                            // layout-driven, not x-derived).
                            readonly property bool previewing: tile.modelData !== undefined && root.isVideoFile(tile.modelData) && tileMa.containsMouse
                            AppVideo {
                                id: tileVideo
                                anchors.fill: parent
                                anchors.margins: 3
                                visible: tile.previewing
                                source: tile.previewing ? tile.modelData : ""
                                active: tile.previewing
                                muted: true
                                fillMode: VideoOutput.PreserveAspectCrop
                                badges: tile.badgeIds
                                onReadyChanged: {
                                    if (tileVideo.ready && tileVideo.videoRatio > 0)
                                        root.noteLocalAspect(tile.modelData, tileVideo.videoRatio);
                                }
                            onErrorOccurred: message => {
                                console.warn("[WallpaperSwitcher] video preview failed for " + tile.modelData + ": " + message);
                            }
                        }
                        Column {
                            // Idle fallback for videos: shown while no thumb
                            // is mapped yet (generator still running) or the
                            // thumb failed to load — same icon look as before.
                            // Hover swaps in the live preview above instead.
                            visible: tile.modelData !== undefined && root.isVideoFile(tile.modelData) && !tile.previewing && (tile.tileThumb === "" || tileImg.status === Image.Error)
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 24
                                color: Theme.fgDim
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.fileName
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                color: Theme.fgDim
                                elide: Text.ElideMiddle
                                width: Math.max(0, tile.width - 16)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Hidden while the strip moves: a visible tooltip
                        // window sits under the cursor and swallows wheel
                        // events, which kills the momentum glide.
                        AppTooltip {
                            visible: tileMa.containsMouse && !wallScroll.moving
                            delay: 400
                                text: `Click to set as ${root.targetType} wallpaper.\nRight-click to delete.\n${(tile.modelData !== undefined && root.isVideoFile(tile.modelData)) ? "Hover to preview.\n" : ""}${tile.fileName}\nSize: ${root.formatBytes(root.getFileSize(tile.modelData ?? ""))}`
                        }

                        MouseArea {
                            id: tileMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            // Tiles cover the strip: let wheel fall through
                            // to the strip's SmoothWheelHandler so the
                            // horizontal momentum glide actually receives it.
                            onWheel: wheel => wheel.accepted = false
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    root.deleteWallpaper(tile.modelData);
                                else
                                    root.applyWallpaper(tile.modelData);
                            }
                        }
                    }
                }
            }

            // wallhaven results — remote thumbs with the same tile chrome.
            // Click downloads the full-res file into wallhaven/ and applies
            // it; right-click saves without applying.
            SmoothFlickable {
                id: whScroll
                visible: root.isWallhaven
                Layout.fillWidth: true
                Layout.preferredHeight: root.resultsH
                flickableDirection: Flickable.HorizontalFlick
                contentWidth: whMasonry.contentWidth
                contentHeight: height
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                AppMasonryRow {
                    id: whMasonry
                    width: whScroll.width
                    height: implicitHeight
                    rows: Settings.wallpaperMasonryRows
                    spacing: 6
                    rowHeight: Settings.wallpaperTileSize
                    model: root.whResults
                    aspectRatio: function (item) {
                        return root.whAspect(item);
                    }
                    viewLeft: whScroll.contentX - 700
                    viewRight: whScroll.contentX + whScroll.width + 700
                    buffer: 700
                    placeholder: Rectangle {
                        color: Theme.surface
                        radius: 6
                    }
                    delegate: Rectangle {
                        id: whTile
                        // Plain (not required) modelData — pushed by the
                        // masonry via Loader (same contract as AppMasonry).
                        property var modelData
                        width: whMasonry.widthFor(modelData)
                        height: whMasonry.rowHeight
                        // Fades in once the remote thumb decodes (Error
                        // counts as settled so a dead URL can't hide a tile).
                        readonly property bool thumbSettled: whImg.status === Image.Ready || whImg.status === Image.Error
                        readonly property string res: whTile.modelData === undefined ? "" : (whTile.modelData.resolution || "")
                        opacity: whTile.thumbSettled ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                        radius: 6
                        color: whTileMa.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.width: whTileMa.containsMouse ? 2 : 0
                        border.color: Theme.muted

                        AppImage {
                            id: whImg
                            anchors.fill: parent
                            anchors.margins: 3
                            source: whTile.modelData === undefined ? "" : whTile.modelData.preview
                            sourceWidth: Math.max(1, Math.round(whTile.width))
                            badges: [whTile.res !== "" ? whTile.res : (whTile.modelData === undefined ? "" : whTile.modelData.purity)]
                        }

                        // Hidden while the strip moves (same wheel-glide
                        // reason as the local tiles above).
                        AppTooltip {
                            visible: whTileMa.containsMouse && !whScroll.moving
                            delay: 400
                            text: whTile.modelData === undefined ? "" : `${whTile.modelData.id} • ${whTile.res} • ${whTile.modelData.purity}/${whTile.modelData.category}\nClick: download + apply.\nRight-click: save only.`
                        }

                        MouseArea {
                            id: whTileMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onWheel: wheel => wheel.accepted = false
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    root.whSaveApply(whTile.modelData, false);
                                else
                                    root.whSaveApply(whTile.modelData, true);
                            }
                        }
                    }
                }

                // Empty state (contentWidth is 0, so this never scrolls away).
                Text {
                    visible: root.whResults.length === 0 && !root.whLoading
                    text: "No results — try a different query or filter."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    x: 12
                    y: (whScroll.height - height) / 2
                }
            }
        }
    }
}
