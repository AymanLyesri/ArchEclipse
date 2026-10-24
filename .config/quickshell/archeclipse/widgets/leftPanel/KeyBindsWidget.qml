import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared

// Key Binds widget — reads the Hyprland Lua keybinds, groups them by
// category, and renders each binding as an array of key chips joined by "+".
// Loads keybinds natively (bind.lua + custom/*.lua parsed in JS via FileView;
// output object matches the old scripts/get-keybinds.sh JSON),
// groups by category, renders each binding as an array of key chips
// joined by "+".
Item {
    id: root
    property int widgetWidth: parent.width

    // keybinds shape (was get-keybinds.sh): { category: [{ description, keys: [] }] }
    property var keybinds: ({})
    property bool loading: true

    // Replayable staggered reveal (same reason as CustomScriptsWidget:
    // StackLayout builds tabs once, hidden). A counter steps 0→totalBinds
    // each time the tab becomes visible; rows key off their flat position
    // (category offset + row index) so the cascade runs across categories.
    property int revealCount: 0
    property var flatOffsets: []
    property int totalBinds: 0
    Timer {
        id: revealTimer
        interval: 25
        repeat: true
        onTriggered: {
            if (root.revealCount >= root.totalBinds)
                revealTimer.stop();
            else
                root.revealCount++;
        }
    }
    function recomputeOffsets() {
        const cats = Object.keys(root.keybinds).sort();
        const offs = [];
        let n = 0;
        for (const c of cats) {
            offs.push(n);
            n += ((root.keybinds[c] || []).length);
        }
        root.flatOffsets = offs;
        root.totalBinds = n;
    }
    function catBase(i) {
        const o = root.flatOffsets;
        return (o && o[i] !== undefined) ? o[i] : 0;
    }
    function playReveal() {
        root.revealCount = 0;
        revealTimer.restart();
    }
    onVisibleChanged: {
        if (visible && !root.loading)
            root.playReveal();
    }
    onKeybindsChanged: {
        root.recomputeOffsets();
        if (visible)
            root.playReveal();
    }

    // ---- load keybinds natively: parse bind.lua + custom/*.lua in JS ----
    // (QML-native port of scripts/get-keybinds.sh; output object is
    // JSON.parse-identical to the script so UI bindings don't change)
    property string bindFilePath: Quickshell.env("HOME") + "/.config/hypr/config/bind.lua"
    property string customDirPath: Quickshell.env("HOME") + "/.config/hypr/config/custom"
    property var _customTexts: []
    property int _customPending: 0
    property string _mainText: ""
    property bool _mainDone: false
    property bool _finished: false

    function _extractBindExpr(line) {
        let s = line.replace(/^\s+/, "");
        if (s.startsWith("hl.bind("))
            s = s.slice("hl.bind(".length);
        const i = s.indexOf(",");
        if (i === -1)
            return "";
        return s.slice(0, i);
    }
    function _squeeze(s) {
        return s.replace(/\s+/g, " ").trim();
    }
    function _normalizeCombo(expr, main) {
        expr = expr.split("mainMod").join(main).split('"').join("").replace(/\.\./g, " ");
        expr = expr.replace(/\++/g, " + ");
        return root._squeeze(expr);
    }
    function _extractKeys(combo) {
        return combo.split("+").map(p => p.trim()).filter(p => p !== "");
    }
    function _openCategory(out, state, name) {
        if (!Object.prototype.hasOwnProperty.call(out.map, name)) {
            out.map[name] = [];
            out.order.push(name);
        }
        state.open = name;
        state.firstItem = true;
    }
    function _splitLines(text) {
        const lines = text.split("\n");
        if (lines.length && lines[lines.length - 1] === "")
            lines.pop();
        return lines;
    }
    function _parseMain(text, out, state) {
        const reMainMod = /^\s*local\s+mainMod\s*=\s*"(.+)"/;
        const reDesc = /^\s*---\s*(.+)$/;
        const reCat = /^\s*--\s+(.+)$/;
        const reBind = /^\s*hl\.bind/;
        const reDigits = /^[0-9]+$/;
        for (const line of root._splitLines(text)) {
            let m;
            if ((m = line.match(reMainMod))) {
                state.mainMod = m[1];
                continue;
            }
            if ((m = line.match(reDesc))) {
                state.comment = m[1];
                continue;
            } else if ((m = line.match(reCat))) {
                if (state.open !== null)
                    state.open = null;
                let cat = m[1];
                if (reDigits.test(cat))
                    cat = cat + " ";
                state.pending = cat;
                state.firstItem = true;
                state.comment = "";
                continue;
            }
            if (reBind.test(line)) {
                if (state.pending !== null) {
                    root._openCategory(out, state, state.pending);
                    state.pending = null;
                } else if (state.open === null) {
                    root._openCategory(out, state, "Default Keybinds");
                }
                const keys = root._extractKeys(root._normalizeCombo(root._extractBindExpr(line), state.mainMod));
                out.map[state.open].push({ description: state.comment !== "" ? state.comment : "Unknown Keybind", keys: keys });
                state.firstItem = false;
            }
        }
        if (state.open !== null)
            state.open = null;
    }
    function _parseCustom(text, out, state) {
        const reMainMod = /^\s*local\s+mainMod\s*=\s*"(.+)"/;
        const reDesc = /^\s*---\s*(.+)$/;
        const reCat = /^\s*--\s+(.+)$/;
        const reBind = /^\s*hl\.bind/;
        const reDigits = /^[0-9]+$/;
        let localMain = state.mainMod;
        let comment = "";
        let explicitCat = false;
        for (const line of root._splitLines(text)) {
            let m;
            if ((m = line.match(reMainMod))) {
                localMain = m[1];
                continue;
            }
            if ((m = line.match(reDesc))) {
                comment = m[1];
                continue;
            } else if ((m = line.match(reCat))) {
                let cat = m[1];
                if (reDigits.test(cat))
                    cat = cat + " ";
                explicitCat = true;
                if (cat !== state.lastCat) {
                    if (state.open !== null)
                        state.open = null;
                    root._openCategory(out, state, cat);
                    state.lastCat = cat;
                    comment = "";
                }
                continue;
            }
            if (reBind.test(line)) {
                if (!explicitCat && state.lastCat !== "Custom Keybinds") {
                    if (state.open !== null)
                        state.open = null;
                    root._openCategory(out, state, "Custom Keybinds");
                    state.lastCat = "Custom Keybinds";
                }
                if (state.open !== null) {
                    const keys = root._extractKeys(root._normalizeCombo(root._extractBindExpr(line), localMain));
                    out.map[state.open].push({ description: comment !== "" ? comment : "Unknown Keybind", keys: keys });
                    state.firstItem = false;
                }
            }
        }
    }
    function _buildKeybinds(mainText, customTexts) {
        const out = { order: [], map: {} };
        const state = { mainMod: "SUPER", comment: "", pending: null, open: null, firstItem: true, lastCat: "" };
        root._parseMain(mainText, out, state);
        for (const t of customTexts)
            root._parseCustom(t, out, state);
        if (state.open !== null)
            state.open = null;
        const result = {};
        for (const k of out.order)
            result[k] = out.map[k];
        return result;
    }
    function _onMainText(t) {
        if (root._finished || root._mainDone)
            return;
        root._mainDone = true;
        root._mainText = t;
        listProc.running = true;
    }
    function _onCustomList(text) {
        if (root._finished)
            return;
        const q = [];
        for (const raw of text.split("\n")) {
            const name = raw.endsWith("\r") ? raw.slice(0, -1) : raw;
            if (name === "" || !name.endsWith(".lua"))
                continue;
            if (name === "monitors.lua" || name === "monitors.conf")
                continue;
            q.push(root.customDirPath + "/" + name);
        }
        q.sort();
        if (q.length === 0) {
            root._customTexts = [];
            root._finish();
            return;
        }
        root._customTexts = new Array(q.length);
        root._customPending = q.length;
        root._readers = new Array(q.length);
        for (let i = 0; i < q.length; i++)
            root._spawnReader(q[i], i);
    }
    function _finish() {
        if (root._finished)
            return;
        root._finished = true;
        try {
            root.keybinds = root._buildKeybinds(root._mainText, root._customTexts);
        } catch (e) {
            console.warn("[KeyBindsWidget] Failed to parse keybinds:", e);
        }
        root.loading = false;
    }

    FileView {
        id: mainFile
        path: root.bindFilePath
        watchChanges: false
        printErrors: false
        onLoaded: root._onMainText(mainFile.text())
        onLoadFailed: root._onMainText("")
    }
    Process {
        id: listProc
        command: ["ls", "-1A", root.customDirPath]
        stdout: StdioCollector {
            onStreamFinished: root._onCustomList(text)
        }
    }
    // Per-file parallel readers: one FileView per custom file, path baked
    // in at creation with declarative onLoaded/onLoadFailed handlers.
    // (A reused FileView emits loaded only on its first load, and the
    // loaded *signal* is shadowed by the loaded *bool property*, so
    // imperative loaded.connect() throws — probed 2026-10-13.)
    property var _readers: []
    function _spawnReader(filePath, idx) {
        const esc = filePath.split("\\").join("\\\\").split('"').join('\\"');
        const src = 'import Quickshell.Io; FileView { path: "' + esc + '"; watchChanges: false; printErrors: false;'
            + ' onLoaded: root._settleCustom(' + idx + ', text());'
            + ' onLoadFailed: root._settleCustom(' + idx + ', "") }';
        let fv = null;
        try {
            fv = Qt.createQmlObject(src, root);
        } catch (e) {
            root._readers[idx] = true; // sentinel: counted, nothing to destroy
            root._settleCustom(idx, "");
            return;
        }
        root._readers[idx] = fv;
    }
    function _settleCustom(idx, txt) {
        if (root._finished || !root._readers[idx])
            return;
        const fv = root._readers[idx];
        root._readers[idx] = null;
        root._customTexts[idx] = txt;
        root._customPending--;
        if (fv && typeof fv.destroy === "function")
            fv.destroy();
        if (root._customPending <= 0)
            root._finish();
    }
    // Watchdog: a wedged read must not leave the widget spinning forever.
    Timer {
        id: watchdog
        interval: 8000
        running: root.loading
        repeat: false
        onTriggered: root._finish()
    }

    // sorted category names
    property var categories: Object.keys(root.keybinds).sort()

    // ---- UI: one Settings-style card per category, divider lines between ----
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        Label {
            text: "Key Binds"
            font.pixelSize: Theme.fontSize + 4
            font.bold: true
            color: Theme.fg
            Layout.fillWidth: true
        }

        // Loading indicator (centered manually: parent is a layout,
        // which ignores anchors on children)
        AppProgress {
            Layout.alignment: Qt.AlignHCenter
            status: root.loading ? "loading" : "idle"
            variant: "spinner"
        }

        SmoothFlickable {
            id: keyScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.loading
            contentWidth: width
            contentHeight: keyCol.height
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: keyCol
                width: keyScroll.width
                spacing: Theme.spacing
                // No edge padding: the panel owns the content inset (the
                // island's Theme.pad), right-panel parity.

                Repeater {
                    model: root.categories
                    delegate: Column {
                        id: catSec
                        required property string modelData
                        required property int index
                        property string category: modelData
                        // Flat base of this category's rows in the reveal
                        // order (inner rows add their own index to it).
                        property int rowBase: root.catBase(index)
                        width: parent.width
                        spacing: Theme.spacing
                        // The whole group (divider + card) fades in just
                        // before its first row.
                        opacity: root.revealCount > rowBase ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Divider line between categories (first one has none)
                        Rectangle {
                            visible: catSec.index > 0
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }

                        // Category card (Settings-section style)
                        Rectangle {
                            width: parent.width
                            implicitHeight: cardBody.implicitHeight + 20
                            radius: Theme.radius
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1

                            Column {
                                id: cardBody
                                anchors.fill: parent
                                anchors.margins: Theme.pad
                                spacing: Theme.spacing

                                Label {
                                    text: catSec.category
                                    font.pixelSize: Theme.fontSize + 2
                                    font.bold: true
                                    color: Theme.accent
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: parent.width
                                }

                                // binds within this category
                                Repeater {
                                    model: root.keybinds[catSec.category] || []
                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: parent.width
                                        height: 28
                                        color: "transparent"
                                        // Flat position (category base + row) vs the
                                        // reveal counter; +1 so rows trail the header.
                                        opacity: (catSec.rowBase + index + 1) <= root.revealCount ? 1 : 0
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 220
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        // NOTE: RowLayout — the description stretches,
                                        // chips keep implicit size (verticalCenter
                                        // anchors are ignored inside positioners).
                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: Theme.spacing
                                            Label {
                                                text: modelData.description
                                                font.pixelSize: Theme.fontSize
                                                color: Theme.fg
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                                Layout.fillWidth: true
                                            }

                                            // key chips joined by "+" (shared AppKeybind widget)
                                            AppKeybind {
                                                keys: modelData.keys || []
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
