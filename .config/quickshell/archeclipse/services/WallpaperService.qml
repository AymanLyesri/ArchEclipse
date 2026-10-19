pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import Qt.labs.folderlistmodel

// WallpaperService — shared wallpaper data fetched once at quickshell
// boot so opening the switcher never pays the first-open cost.
//
// Owns the heavy/shared state that used to live per-body in
// WallpaperPanelBody: the category -> [paths] map (one QML-native
// FolderListModel scan, not one per monitor per open), the video
// first-frame thumb manifest, and the decoded-aspect cache. Bodies
// (one per monitor Bar) bind read-only and delegate helpers here.
//
// Per-body UI state stays in the body: targetType, selectedWorkspace,
// wallhaven search/results, progress, currentWallpapers (cheap
// --current config read, monitor-specific).
QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // First-frame JPEG thumbnails for video wallpapers live here (QML-native
    // since 2026-10-13, replacing scripts/gen-video-thumbs.sh): deterministic
    // thumbPathFor() + mtime probe + sequential ffmpeg queue below.
    readonly property string thumbCacheDir: home + "/.cache/quickshell/wallpaper-thumbs"

    // category -> [paths]; reassigned, never mutated (masonry bindings).
    property var wallpapers: ({})
    property string _lastWallpapersJson: ""
    // video path -> thumb path manifest (merged incrementally).
    property var thumbMap: ({})
    // decoded-aspect cache (path -> w/h); batched adopts via _pendingAspect.
    property var localAspect: ({})
    property var _pendingAspect: ({})
    property bool _thumbPending: false
    property bool _started: false

    function isVideoFile(file) {
        return /\.(mp4|webm|mkv|mov)$/i.test(file || "");
    }

    function localAspectOf(path) {
        const r = root.localAspect[path] || 0;
        return r > 0 ? r : 16 / 9;
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

    function thumbFor(path) {
        if (path === undefined || !root.isVideoFile(path))
            return "";
        return root.thumbMap[path] || "";
    }

    function start() {
        if (root._started)
            return;
        root._started = true;
        root.fetchWallpapers();
    }

    function refresh() {
        root.fetchWallpapers();
    }

    function fetchWallpapers() {
        // QML-native directory scan (replaces get-wallpapers.sh default
        // mode): depth-first walk of wallpaperFolder through a single
        // FolderListModel, one directory per Ready step. Restartable: a
        // refresh mid-scan resets the stack/result and rebuilds from root.
        root._scanResult = {};
        root._scanStack = [""];
        root._scanSeen = true;
        root._scanActive = true;
        root._scanRetries = 0;
        root.fetchProc.running = true;
        root._scanNext();
    }

    // fetchProc is a compat flag object (not a Process): bodies bind
    // `fetchProc.running` for captureReady. Same pattern as thumbProc.
    property QtObject fetchProc: QtObject {
        property bool running: false
    }
    property var _scanResult: ({})
    property var _scanStack: []
    property string _scanCurrent: ""
    property bool _scanSeen: true
    property bool _scanActive: false
    property int _scanRetries: 0
    readonly property string wallpaperFolder: home + "/.config/wallpapers"
    // Same extension set as the old script's find -iname list.
    readonly property var _scanExts: ["jpg", "jpeg", "png", "webp", "bmp", "gif", "svg", "mp4", "webm", "mkv", "mov"]

    function _isWallpaperFile(name) {
        const m = /\.([^.]+)$/.exec(name || "");
        return m !== null && root._scanExts.indexOf(m[1].toLowerCase()) !== -1;
    }

    // Sort key mirroring the old `find ... | sort -z` (en_US.UTF-8):
    // glibc collation ignores punctuation/case on its first pass, so
    // `_foo` sorts with the f's, not before alphanumerics (JS code-unit
    // order would). Raw name breaks ties. Verified byte-identical
    // against live script output for all shipped categories.
    function _scanSortKey(name) {
        return name.replace(/[^A-Za-z0-9]/g, "").toLowerCase();
    }
    function _scanLess(a, b) {
        const ka = root._scanSortKey(a), kb = root._scanSortKey(b);
        if (ka !== kb)
            return ka < kb ? -1 : 1;
        if (a !== b)
            return a < b ? -1 : 1;
        return 0;
    }

    property FolderListModel scanModel: FolderListModel {
        showFiles: true
        showDirs: true
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        onStatusChanged: {
            if (status === FolderListModel.Ready && root._scanActive && !root._scanSeen)
                root._processScanDir();
        }
    }

    // Fallback when Ready never arrives (e.g. a dir vanishing mid-scan):
    // skip silently like the old script's empty find. While Loading, wait;
    // give up after ~10s so a wedged model can't stall boot adoption.
    property Timer _scanKick: Timer {
        interval: 500
        onTriggered: {
            if (!root._scanActive || root._scanSeen)
                return;
            if (root.scanModel.status === FolderListModel.Loading) {
                if (root._scanRetries < 20) {
                    root._scanRetries++;
                    root._scanKick.restart();
                } else {
                    root._scanNext();
                }
                return;
            }
            if (root.scanModel.status === FolderListModel.Ready)
                root._processScanDir();
            else
                root._scanNext();
        }
    }

    function _scanNext() {
        if (!root._scanActive)
            return;
        if (root._scanStack.length === 0) {
            root._finishScan();
            return;
        }
        root._scanCurrent = root._scanStack.pop();
        root._scanSeen = false;
        root._scanRetries = 0;
        root.scanModel.folder = "file://" + root.wallpaperFolder + (root._scanCurrent !== "" ? "/" + root._scanCurrent : "");
        root._scanKick.restart();
    }

    function _processScanDir() {
        if (!root._scanActive || root._scanSeen)
            return;
        root._scanSeen = true;
        root._scanKick.stop();
        const files = [];
        const dirs = [];
        for (let i = 0; i < root.scanModel.count; i++) {
            const name = root.scanModel.get(i, "fileName");
            if (name === undefined || name === "")
                continue;
            if (root.scanModel.get(i, "fileIsDir"))
                dirs.push(name);
            else if (root._isWallpaperFile(name))
                files.push(name);
        }
        // Explicit locale-collation sort matching the old
        // `find ... | sort -z` within a directory (see _scanLess), never
        // depending on the model's own sorting.
        files.sort(root._scanLess);
        dirs.sort(root._scanLess);
        if (files.length > 0) {
            const base = root.wallpaperFolder + (root._scanCurrent !== "" ? "/" + root._scanCurrent : "");
            root._scanResult[root._scanCurrent] = files.map(f => base + "/" + f);
        }
        // Push reversed so the smallest subdir pops first: pre-order DFS
        // equals the old global `find | sort` directory order, which the
        // category combo + capture tooling observe via Object.keys.
        for (let i = dirs.length - 1; i >= 0; i--)
            root._scanStack.push(root._scanCurrent !== "" ? root._scanCurrent + "/" + dirs[i] : dirs[i]);
        root._scanNext();
    }

    function _finishScan() {
        root._scanActive = false;
        root._scanKick.stop();
        root.fetchProc.running = false;
        // Skip no-change adoptions: every reassign rebuilds the
        // masonry + re-decodes all tiles (visible flicker). Canonical
        // JSON.stringify (insertion-ordered DFS keys, sorted paths) is
        // the comparator.
        const text = JSON.stringify(root._scanResult);
        if (text === root._lastWallpapersJson)
            return;
        root._lastWallpapersJson = text;
        root.wallpapers = JSON.parse(text);
        root.runThumbGen();
    }

    property Timer aspectFlush: Timer {
        interval: 250
        onTriggered: {
            if (Object.keys(root._pendingAspect).length === 0)
                return;
            root.localAspect = Object.assign({}, root.localAspect, root._pendingAspect);
            root._pendingAspect = {};
        }
    }

    // Background thumb run over every known local video (fresh ones skip
    // on mtime via the probe in _pumpThumbs, so re-runs are cheap).
    // Single-flight: a fetch storm while a run is active re-runs once on
    // drain. thumbProc is a compat flag object (not a Process): bodies bind
    // `thumbProc.running` for captureReady.
    property QtObject thumbProc: QtObject {
        property bool running: false
    }
    property var _thumbQueue: []
    property var _thumbResults: ({})

    // Deterministic thumb name from the source path so QML derives it
    // without hashing: sanitized path + ".jpg". Mirrors the old script's
    // sed 's/[^A-Za-z0-9._-]/_/g' byte-wise for ASCII paths (all shipped
    // folders are ASCII; QML UTF-16 vs sed bytes would disagree on
    // unicode — same caveat the script carried).
    function thumbPathFor(src) {
        return root.thumbCacheDir + "/" + String(src).replace(/[^A-Za-z0-9._-]/g, "_") + ".jpg";
    }

    // One-shot Process factory: stderr is discarded (the old script ran
    // ffmpeg with 2>/dev/null; without a collector the child inherits the
    // shell's stderr and spams the bar log per video).
    function _spawn(args) {
        const p = Qt.createQmlObject("import Quickshell.Io; Process {}", root);
        p.stderr = Qt.createQmlObject("import Quickshell.Io; StdioCollector {}", p);
        p.command = args;
        return p;
    }

    function runThumbGen() {
        if (root.thumbProc.running) {
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
        root._thumbQueue = vids.slice();
        root._thumbResults = {};
        root.thumbProc.running = true;
        const mk = root._spawn(["mkdir", "-p", root.thumbCacheDir]);
        mk.exited.connect(function () {
            mk.destroy();
            root._pumpThumbs();
        });
        mk.running = true;
    }

    // Sequential queue: mtime probe first (FileView can't stat, so one
    // `test out -nt src` per file), then ffmpeg + atomic mv on stale.
    // Failures (missing source, decode error) adopt nothing, keeping the
    // icon fallback — same as the old script's manifest omissions.
    function _pumpThumbs() {
        if (root._thumbQueue.length === 0) {
            if (Object.keys(root._thumbResults).length > 0)
                root.thumbMap = Object.assign({}, root.thumbMap, root._thumbResults);
            root._thumbResults = {};
            root.thumbProc.running = false;
            if (root._thumbPending) {
                root._thumbPending = false;
                root.runThumbGen();
            }
            return;
        }
        const src = root._thumbQueue[0];
        const out = root.thumbPathFor(src);
        const probe = root._spawn(["bash", "-c", 'test -f "$1" && test "$1" -nt "$2"', "--", out, src]);
        probe.exited.connect(function (code) {
            probe.destroy();
            if (code === 0) {
                root._thumbResults[src] = out;
                root._thumbQueue.shift();
                root._pumpThumbs();
            } else {
                root._runFfmpegThumb(src, out);
            }
        });
        probe.running = true;
    }

    function _runFfmpegThumb(src, out) {
        // Fixed tmp suffix is safe: the queue is strictly sequential, so
        // no two ffmpeg runs share an `out`. Atomic mv publish, rm on fail.
        const tmp = out.slice(0, -4) + ".tmp.qs.jpg";
        // Read from the beginning: a fixed 1s seek skipped sub-second clips.
        const ff = root._spawn(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-vframes", "1", "-vf", "scale=320:-1", tmp]);
        ff.exited.connect(function (code) {
            ff.destroy();
            if (code === 0) {
                const mv = root._spawn(["mv", "-f", tmp, out]);
                mv.exited.connect(function (mvCode) {
                    mv.destroy();
                    if (mvCode === 0)
                        root._thumbResults[src] = out;
                    root._thumbQueue.shift();
                    root._pumpThumbs();
                });
                mv.running = true;
            } else {
                const rm = root._spawn(["rm", "-f", tmp]);
                rm.exited.connect(function () {
                    rm.destroy();
                    root._thumbQueue.shift();
                    root._pumpThumbs();
                });
                rm.running = true;
            }
        });
        ff.running = true;
    }

    Component.onCompleted: root.start()
}
