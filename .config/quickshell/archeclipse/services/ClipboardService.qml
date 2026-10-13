pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ClipboardService — clipboard history, QML-native (replaces
// ~/.config/hypr/scripts/clipboard-monitor.sh + its `wl-paste --watch`
// hook in hypr config/exec.lua).
//
// A persistent `wl-paste --watch qs … ipc call clipboard event` Process
// (spawned here at boot; stale watchers culled first) pings onEvent()
// per copy. Events drain through a FIFO queue — never coalesced, every
// copy is recorded. Each capture probes types in the old priority
// (image/png → image/jpeg → image/webp → text/uri-list → text/plain)
// and prepends {id, timestamp, type, content, mimeType} newest-first to
// ~/.cache/quickshell/launcher/clipboard-history.json, which Launcher's
// `cb` search watches live. Images land in
// ~/.cache/quickshell/launcher/clipboard-images/ (the old /tmp paths
// went stale on every reboot). No jq dependency.
QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg: home + "/.config/quickshell/archeclipse"
    readonly property string historyPath: home + "/.cache/quickshell/launcher/clipboard-history.json"
    readonly property string imageDir: home + "/.cache/quickshell/launcher/clipboard-images"

    // Live history for Launcher's `cb` search (reactive binding — see
    // note there). Adopted from every confirmed load/rename, never
    // written from elsewhere.
    property var history: []

    // FIFO of pending captures; _busy guards the single capture pipeline.
    property int _pending: 0
    property bool _busy: false
    property bool _started: false

    function start() {
        if (root._started)
            return;
        root._started = true;
        // Self-heal history file only from a confirmed load — writing
        // here unconditionally would clobber valid data (FileView text()
        // is async; see _finish). changed covers legacy/invalid shapes.
        // Adopt into history either way so `cb` binds warm data at boot.
        root._loadHistory((list, changed) => {
            root.history = list;
            if (changed)
                root._writeHistory(list);
        });
        Quickshell.execDetached(["mkdir", "-p", root.imageDir]);
        root._killProc.running = true;
    }

    // Per-capture working state.
    property int _capStep: -1
    property int _capTs: 0
    property string _capDate: ""
    property string _capOut: ""
    readonly property var _imageMimes: ["image/png", "image/jpeg", "image/webp"]
    readonly property var _imageExts: ["png", "jpeg", "webp"]

    // Event entry: wl-paste --watch pings `qs … ipc call clipboard event`.
    function onEvent() {
        root._pending++;
        root._pump();
    }

    function _pump() {
        if (root._busy || root._pending === 0 || root._cap.running || root._settle.running)
            return;
        root._pending--;
        root._busy = true;
        root._capTs = Math.floor(Date.now() / 1000);
        root._capDate = Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss");
        // Settle delay: `wl-paste --watch` fires on the ownership
        // announcement, but the new MIME data often isn't offered yet —
        // probing immediately reads empty/stale content (one copy behind,
        // verified live 2026-10-13). 400ms lets the offer land.
        root._settle.restart();
    }
    // Per-job settle before probing (each queued event still probes in
    // turn — rapid copies are all recorded, never coalesced away).
    property Timer _settle: Timer {
        interval: 400
        repeat: false
        onTriggered: {
            root._capStep = 0;
            root._runStep();
        }
    }

    function _candidateFor(step) {
        return root.imageDir + "/clipboard_image_" + root._capDate + "." + root._imageExts[step];
    }

    function _runStep() {
        if (root._capStep < 3) {
            // Image probe: binary-safe via shell redirect (StdioCollector
            // is text-only); exit code tells availability, as before.
            const mime = root._imageMimes[root._capStep];
            root._cap.command = ["sh", "-c", 'wl-paste --type "$0" > "$1" 2>/dev/null', mime, root._candidateFor(root._capStep)];
        } else if (root._capStep === 3) {
            root._cap.command = ["wl-paste", "--no-newline", "--type", "text/uri-list"];
        } else {
            root._cap.command = ["wl-paste", "--no-newline", "--type", "text/plain"];
        }
        root._capOut = "";
        root._cap.running = true;
    }

    function _finish(type, content, mime) {
        if (type === "") {
            root._busy = false;
            root._pump();
            return;
        }
        // Async load: FileView delivers text() via onLoaded, NOT
        // synchronously after creation — a sync text() here returns ""
        // and the write below would wipe a valid history (seen live:
        // 49 entries lost on boot, 2026-10-13). Never write from a
        // read that didn't confirm delivery.
        root._loadHistory((list) => {
            list.unshift({
                id: root._capTs,
                timestamp: root._capTs,
                type: type,
                content: content,
                mimeType: mime
            });
            root._writeHistory(list);
            root.history = list;
            root._busy = false;
            root._pump();
        });
    }

    // Async history load (one FileView per read — a reused FileView fires
    // loaded only on its first load; declarative onLoaded/onLoadFailed in
    // the creation string since the loaded *signal* is shadowed by the
    // loaded *bool property* for imperative connect()). Callback gets
    // (list, changed); missing file -> ([], true) so callers initialize.
    property int _histSeq: 0
    property var _histCbs: ({})
    property var _histReaders: ({})
    function _loadHistory(cb) {
        root._histSeq++;
        const seq = root._histSeq;
        root._histCbs[seq] = cb;
        const esc = root.historyPath.split("\\").join("\\\\").split('"').join('\\"');
        try {
            root._histReaders[seq] = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + esc + '"; watchChanges: false; printErrors: false;'
                + ' onLoaded: root._historySettled(' + seq + ', true, text());'
                + ' onLoadFailed: root._historySettled(' + seq + ', false, "") }', root);
        } catch (e) {
            root._historySettled(seq, false, "");
        }
    }
    function _historySettled(seq, ok, text) {
        const cb = root._histCbs[seq];
        delete root._histCbs[seq];
        const fv = root._histReaders[seq];
        delete root._histReaders[seq];
        if (fv)
            fv.destroy();
        if (!cb)
            return;
        if (!ok) {
            cb([], true);
            return;
        }
        let v = [];
        let changed = false;
        try {
            const t = String(text || "");
            v = t === "" ? [] : JSON.parse(t);
        } catch (e) {
            v = [];
            changed = true;
        }
        // Legacy {"entries": [...]} shape -> bare array.
        if (v !== null && typeof v === "object" && !Array.isArray(v) && Array.isArray(v.entries)) {
            v = v.entries;
            changed = true;
        }
        if (!Array.isArray(v)) {
            v = [];
            changed = true;
        }
        cb(v, changed);
    }

    // Direct in-place write (JsonListStore.save pattern verbatim): the
    // tmp+rename variant was tried and reverted 2026-10-13 — replacing
    // the inode freezes Quickshell's file watching/caching (Launcher's
    // `cb` index stuck at a boot snapshot; service-side loads served
    // stale snapshots), while direct writes always grew the file
    // correctly. Sole-writer serialization via _busy makes torn reads
    // impossible; any divergence self-heals on the next capture load.
    function _writeHistory(list) {
        let o = null;
        try {
            o = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + root.historyPath + '" }', root);
            o.setText(JSON.stringify(list, null, 2));
        } catch (e) {
            console.warn("[ClipboardService] history write failed:", e);
        }
        if (o)
            o.destroy();
    }

    // Capture pipeline: one reused Process, step routed on exit.
    property Process _cap: Process {
        stdout: StdioCollector {
            onStreamFinished: root._capOut = text
        }
        onExited: (exitCode, exitStatus) => {
            if (root._capStep < 0)
                return;
            if (root._capStep < 3) {
                // Image step: exit 0 means the type was offered.
                if (exitCode === 0) {
                    const step = root._capStep;
                    root._capStep = -1;
                    root._finish("image", root._candidateFor(step), root._imageMimes[step]);
                    return;
                }
                // Miss: drop the empty candidate so failures leave no litter.
                Quickshell.execDetached(["rm", "-f", root._candidateFor(root._capStep)]);
                root._capStep++;
                root._runStep();
                return;
            }
            if (root._capStep === 3) {
                // `[[ -n … ]]` semantics: any output, even whitespace, counts.
                if (exitCode === 0 && root._capOut !== "") {
                    let p = root._capOut;
                    if (p.indexOf("file://") === 0)
                        p = p.slice(7);
                    root._capStep = -1;
                    root._finish("uri-list", p, "text/uri-list");
                    return;
                }
                root._capStep = 4;
                root._runStep();
                return;
            }
            // Plain-text fallback (also the nothing-offered exit: no entry).
            if (exitCode === 0 && root._capOut !== "") {
                root._capStep = -1;
                root._finish("text", root._capOut, "text/plain");
                return;
            }
            root._capStep = -1;
            root._finish("", "", "");
        }
    }

    // Boot: cull stale watchers first (a reloaded shell orphans the old
    // `wl-paste --watch`), then start our own. Kill and start stay
    // separate Processes: a combined `pkill …; wl-paste …` cmdline
    // contains its own match and SIGTERMs itself (hypr exec.lua lesson).
    property Process _killProc: Process {
        command: ["sh", "-c", "pkill -f '[w]l-paste --watch' 2>/dev/null; true"]
        onExited: {
            if (!root._watcher.running)
                root._watcher.running = true;
        }
    }
    property Process _watcher: Process {
        command: ["wl-paste", "--watch", "qs", "-p", root.cfg, "ipc", "call", "clipboard", "event"]
        onExited: (exitCode, exitStatus) => {
            console.warn("[ClipboardService] watcher exited code=" + exitCode + " — retrying in 10s");
            if (!root._watchRetry.running)
                root._watchRetry.start();
        }
    }
    property Timer _watchRetry: Timer {
        interval: 10000
        repeat: false
        onTriggered: {
            if (!root._watcher.running)
                root._watcher.running = true;
        }
    }

    Component.onCompleted: {
        // Boot is driven by shell.qml (ClipboardService.start()) — lazy
        // singletons never instantiate on their own.
    }
}
