import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared

// Key Binds widget — parses bind.lua + custom/*.lua in JS via FileView and
// renders each binding as key chips joined by "+", grouped by category.
Item {
    id: root
    property int widgetWidth: parent.width

    // keybinds shape (was get-keybinds.sh): { category: [{ description, keys: [] }] }
    property var keybinds: ({})
    property bool loading: true

    // Replayable staggered reveal (StackLayout builds tabs hidden): a counter
    // steps 0→totalBinds; rows key off their flat category+row position.
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
    // QML port of scripts/get-keybinds.sh; the object shape is JSON.parse-identical.
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
    // One FileView per custom file: a reused one emits `loaded` once, and the
    // signal is shadowed by the loaded bool, so connect() throws (probed 2026-10-13).
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

    // Empty groups are dropped: comment-only custom files yield categories with
    // no binds, and the rail must not offer entries that lead nowhere.
    property var categories: Object.keys(root.keybinds).filter(c => (root.keybinds[c] || []).length > 0).sort()

    // Shared category navigation: the rail selects a category, scrolls it
    // to the middle of the viewport and applies the distance focus fade.
    CategoryNav {
        id: nav
        flickable: keyScroll
        content: keyCol
        categories: root.categories
    }

    // ---- UI: persistent category rail + one card per category ----
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

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing

            // Categories are user-defined strings (bind.lua comments), so
            // long names elide with a full-name tooltip.
            CategoryRail {
                Layout.preferredWidth: 104
                Layout.alignment: Qt.AlignTop
                visible: !root.loading && root.categories.length > 0
                model: root.categories
                currentIndex: nav.activeIndex
                onSelected: index => nav.select(index)
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
                    onPressedChanged: {
                        if (pressed)
                            nav.cancel();
                    }
                }

                Column {
                    id: keyCol
                    width: keyScroll.width
                    spacing: Theme.spacing

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
                            // Direct child of keyCol: CategoryNav finds the
                            // section for centering by this key.
                            property int categoryIndex: index
                            width: parent.width
                            spacing: Theme.spacing
                            // The divider fades with its card; one focus opacity for
                            // the whole group, never stacked per card.
                            opacity: (root.revealCount > rowBase ? 1 : 0) * nav.opacityFor(index)
                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }

                            CategorySection {
                                width: parent.width
                                title: catSec.category

                                Repeater {
                                    model: root.keybinds[catSec.category] || []
                                    // Two lines: category names are long and the
                                    // column is shared with the rail.
                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: parent.width
                                        height: bindBody.implicitHeight + 8
                                        color: "transparent"
                                        // Flat position vs the reveal counter; +1 so
                                        // rows trail their header.
                                        opacity: (catSec.rowBase + index + 1) <= root.revealCount ? 1 : 0
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 220
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Column {
                                            id: bindBody

                                            anchors.fill: parent
                                            anchors.topMargin: 4
                                            anchors.bottomMargin: 4
                                            spacing: 4

                                            Label {
                                                width: parent.width
                                                text: modelData.description
                                                font.pixelSize: Theme.fontSize
                                                color: Theme.fg
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            // key chips joined by "+" (shared AppKeybind widget)
                                            AppKeybind {
                                                keys: modelData.keys || []
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
