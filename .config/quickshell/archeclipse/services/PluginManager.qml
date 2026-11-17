pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// PluginManager: user plugins live as folders under the plugins dir, each with a
// plugin.json manifest ({name, entry}). The enabled list persists in Settings.
QtObject {
    id: root

    readonly property string pluginRoot: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/plugins"
    property var plugins: []
    property string lastError: ""
    property bool busy: false
    // True after the first directory scan reconciled the list (LeftIsland gates its
    // stale-tab reset on this so an early seed can't bounce the selection).
    property bool scanned: false

    function pluginDir(id) {
        return root.pluginRoot + "/" + String(id || "");
    }

    function entryUrl(entry) {
        if (!entry)
            return "";
        if (String(entry).startsWith("file://") || String(entry).startsWith("qrc:"))
            return String(entry);
        return "file://" + String(entry);
    }

    function refresh() {
        scanProc.command = root._scanCommand();
        scanProc.running = true;
    }

    function setEnabled(id, enabled) {
        const next = (Settings.userPlugins || []).map(p => {
            if (p.id === id)
                return Object.assign({}, p, { enabled: !!enabled });
            return p;
        });
        Settings.userPlugins = next;
        Settings.persist();
        root.refresh();
    }

    function renamePlugin(id, name) {
        const clean = String(name || "").trim();
        if (clean === "")
            return;
        const next = (Settings.userPlugins || []).map(p => {
            if (p.id === id)
                return Object.assign({}, p, { name: clean });
            return p;
        });
        Settings.userPlugins = next;
        Settings.persist();
        root.refresh();
    }

    function removePlugin(id) {
        rmProc.targetId = String(id || "");
        rmProc.command = ["bash", "-c", 'rm -rf "$1"', "--", root.pluginDir(id)];
        rmProc.running = true;
    }

    function installFromGit(url) {
        const clean = String(url || "").trim();
        if (clean === "") {
            root.lastError = "Empty repo URL";
            return;
        }
        root.busy = true;
        root.lastError = "";
        cloneProc.command = ["bash", "-c", 'set -e; mkdir -p "$1"; d="$1/$2"; rm -rf "$d"; git clone --depth 1 "$3" "$d"', "--", root.pluginRoot, root._idFromUrl(clean), clean];
        cloneProc.running = true;
    }

    function _idFromUrl(url) {
        let base = String(url).split("/").filter(s => s !== "").pop() || "plugin";
        base = base.replace(/\.git$/, "").toLowerCase().replace(/[^a-z0-9-_]+/g, "-").replace(/^-+|-+$/g, "");
        return base === "" ? "plugin" : base;
    }

    function _adoptDir(dirPath, source) {
        const raw = String(dirPath.split("/").pop() || "");
        const id = (raw.toLowerCase().replace(/[^a-z0-9-_]+/g, "-") || "plugin");
        adoptProc.adoptId = id;
        adoptProc.adoptSource = String(source || "");
        adoptProc.command = ["bash", "-c", 'set -e; src="$1"; dst="$2"; rm -rf "$dst"; mkdir -p "$(dirname "$dst")"; cp -r "$src" "$dst"', "--", dirPath, root.pluginRoot + "/" + id];
        adoptProc.running = true;
    }

    function installFromFolder(path) {
        const clean = String(path || "").trim();
        if (clean === "") {
            root.lastError = "Empty path";
            return;
        }
        root.busy = true;
        root.lastError = "";
        root._adoptDir(clean, "folder");
    }

    function installFromArchive(path) {
        const clean = String(path || "").trim();
        if (clean === "") {
            root.lastError = "Empty path";
            return;
        }
        root.busy = true;
        root.lastError = "";
        unzipProc.command = ["bash", "-c", 'set -e; tmp=$(mktemp -d); unzip -q "$1" -d "$tmp"; top=$(find "$tmp" -mindepth 1 -maxdepth 1 | head -n 1); echo "$top"', "--", clean];
        unzipProc.running = true;
    }

    function _registerInstalled(id, source) {
        const entry = {
            id: id,
            name: id,
            source: source,
            entry: root.pluginDir(id) + "/Main.qml",
            enabled: true
        };
        const rest = (Settings.userPlugins || []).filter(p => p.id !== id);
        rest.push(entry);
        Settings.userPlugins = rest;
        Settings.persist();
        root.refresh();
    }

    function _applyScan(text) {
        let found = [];
        try {
            found = JSON.parse(text || "[]");
        } catch (e) {
            root.lastError = "Scan parse failed";
            return;
        }
        const saved = Settings.userPlugins || [];
        const byId = {};
        for (const p of saved)
            byId[p.id] = p;
        const merged = [];
        for (const f of found) {
            const prev = byId[f.id] || {};
            merged.push({
                id: f.id,
                name: prev.name || f.name || f.id,
                source: prev.source || "folder",
                entry: root.pluginRoot + "/" + f.id + "/" + (f.entry || "Main.qml"),
                enabled: prev.enabled !== undefined ? !!prev.enabled : true
            });
        }
        root.plugins = merged;
        const next = merged.map(m => ({
            id: m.id,
            name: m.name,
            source: m.source,
            entry: m.entry,
            enabled: m.enabled
        }));
        if (JSON.stringify(next) !== JSON.stringify(saved)) {
            Settings.userPlugins = next;
            Settings.persist();
        }
        root.scanned = true;
    }

    // Scanner lists each plugin dir + its manifest entry (no QML import needed).
    function _scanCommand() {
        return ["bash", "-c", 'root="$1"; [ -d "$root" ] || { echo "[]"; exit 0; }; echo "["; first=1; for d in "$root"/*/; do [ -d "$d" ] || continue; id=$(basename "$d"); name="$id"; entry="Main.qml"; mf="$d/plugin.json"; if [ -f "$mf" ]; then n=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get(\'name\',\'\'))" "$mf" 2>/dev/null); e=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get(\'entry\',\'\'))" "$mf" 2>/dev/null); [ -n "$n" ] && name="$n"; [ -n "$e" ] && entry="$e"; fi; [ $first -eq 0 ] && echo ","; first=0; printf \'{"id":%s,"name":%s,"entry":%s}\' "$(python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$id")" "$(python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$name")" "$(python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$entry")"; done; echo "]"', "--", root.pluginRoot];
    }

    property Process scanProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root._applyScan(text)
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                root.lastError = "Scan failed";
        }
    }

    property Process cloneProc: Process {
        stdout: StdioCollector {
            id: cloneOut
        }
        stderr: StdioCollector {
            id: cloneErr
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0) {
                root.lastError = (cloneErr.text || "git clone failed").trim().slice(0, 300);
                return;
            }
            const cmds = cloneProc.command;
            const url = String(cmds[cmds.length - 1] || "");
            root._registerInstalled(root._idFromUrl(url), url);
        }
    }

    property Process rmProc: Process {
        property string targetId: ""
        onExited: code => {
            const id = rmProc.targetId;
            rmProc.targetId = "";
            if (code !== 0) {
                root.lastError = "Delete failed";
                return;
            }
            Settings.userPlugins = (Settings.userPlugins || []).filter(p => p.id !== id);
            Settings.persist();
            root.refresh();
        }
    }

    property Process adoptProc: Process {
        property string adoptId: ""
        property string adoptSource: ""
        onExited: code => {
            const id = adoptProc.adoptId;
            const src = adoptProc.adoptSource;
            adoptProc.adoptId = "";
            root.busy = false;
            if (code !== 0) {
                root.lastError = "Copy into plugins/ failed";
                return;
            }
            root._registerInstalled(id, src);
        }
    }

    property Process unzipProc: Process {
        stdout: StdioCollector {
            id: unzipOut
        }
        onExited: code => {
            if (code !== 0) {
                root.busy = false;
                root.lastError = "Unzip failed";
                return;
            }
            const top = (unzipOut.text || "").trim().split("\n").pop() || "";
            if (top === "") {
                root.busy = false;
                root.lastError = "Empty archive";
                return;
            }
            root._adoptDir(top, "archive");
        }
    }

    Component.onCompleted: {
        // Seed from the persisted list synchronously so tab order is right on the first
        // frame; the async directory scan below only reconciles what is really installed.
        root.plugins = (Settings.userPlugins || []).map(p => Object.assign({}, p));
        root.refresh();
    }
}
