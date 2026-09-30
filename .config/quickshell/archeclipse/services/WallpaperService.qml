pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// WallpaperService — shared wallpaper data fetched once at quickshell
// boot so opening the switcher never pays the first-open cost.
//
// Owns the heavy/shared state that used to live per-body in
// WallpaperPanelBody: the category -> [paths] map (one
// get-wallpapers.sh run, not one per monitor per open), the video
// first-frame thumb manifest, and the decoded-aspect cache. Bodies
// (one per monitor Bar) bind read-only and delegate helpers here.
//
// Per-body UI state stays in the body: targetType, selectedWorkspace,
// wallhaven search/results, progress, currentWallpapers (cheap
// --current config read, monitor-specific).
QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperScript: home + "/.config/quickshell/archeclipse/scripts/get-wallpapers.sh"
    readonly property string thumbScript: home + "/.config/quickshell/archeclipse/scripts/gen-video-thumbs.sh"

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
        fetchProc.running = true;
    }

    property Process fetchProc: Process {
        command: ["bash", root.wallpaperScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Skip no-change adoptions: every reassign rebuilds the
                    // masonry + re-decodes all tiles (visible flicker).
                    if (text === root._lastWallpapersJson)
                        return;
                    root._lastWallpapersJson = text;
                    root.wallpapers = JSON.parse(text);
                    root.runThumbGen();
                } catch (e) {
                    console.warn("[WallpaperService] fetching wallpapers", e);
                }
            }
        }
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
    // on mtime inside the script, so re-runs are cheap). Single-flight:
    // a fetch storm while a run is active re-runs once on exit.
    property Process thumbProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = JSON.parse(text);
                    if (m && typeof m === "object")
                        root.thumbMap = Object.assign({}, root.thumbMap, m);
                } catch (e) {
                    console.warn("[WallpaperService] thumb manifest parse failed", e);
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

    Component.onCompleted: root.start()
}
