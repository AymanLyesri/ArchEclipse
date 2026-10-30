pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, QML-native: a persistent `wl-paste --watch` pings onEvent and
// every copy drains through a FIFO queue (never coalesced) into the launcher cache.
QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg: home + "/.config/quickshell/archeclipse"
    readonly property string historyPath: home + "/.cache/quickshell/launcher/clipboard-history.json"
    readonly property string imageDir: home + "/.cache/quickshell/launcher/clipboard-images"

    // Live history for Launcher's `cb` search; adopted only from a confirmed
    // load/rename, never written from anywhere else.
    property var history: []

    // FIFO of pending captures; _busy guards the single capture pipeline.
    property int _pending: 0
    property bool _busy: false
    property bool _started: false

    // Single owner of the wl-copy invocation/quoting so callers never rebuild it;
    // onDone(exitCode) is optional (Donations toasts on it, Launcher does not).
    function copy(text, onDone) {
        const p = Qt.createQmlObject("import Quickshell.Io; Process {}", root);
        p.command = ["sh", "-c", "printf %s \"$1\" | wl-copy", "--", String(text)];
        p.exited.connect(code => {
            p.destroy();
            if (onDone)
                onDone(code);
        });
        p.running = true;
    }

    function start() {
        if (root._started)
            return;
        root._started = true;
        // Heal only from a confirmed load: writing here unconditionally clobbers
        // valid data (text() is async); adopt anyway so `cb` binds warm at boot.
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
        // `wl-paste --watch` fires on the ownership announcement before the MIME data
        // is offered; probing instantly read one copy behind, so wait 400ms.
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
        // FileView delivers text() via onLoaded, never synchronously — a sync read
        // returned "" and wiped 49 valid entries on boot (2026-10-13).
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

    // One FileView per read: a reused one fires loaded only once, and imperative
    // connect("loaded") hits the bool property — declare onLoaded in the string.
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

    // Write in place: tmp+rename swaps the inode and freezes Quickshell's file
    // watching (`cb` stuck on a boot snapshot), so only direct writes are safe.
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

    // Cull stale watchers first (a reload orphans the old one); kill and start stay
    // separate Processes — a combined cmdline matches itself and SIGTERMs itself.
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
