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

    // Unified entrance fade (StackLayout builds tabs hidden): the whole page
    // fades in once, replacing the old per-row stagger.
    property real revealOpacity: 0
    property int totalBinds: 0
    Anim {
        id: revealFade
        target: root
        property: "revealOpacity"
        from: 0
        to: 1
        type: Anim.DefaultEffects
    }
    function recomputeOffsets() {
        let n = 0;
        for (const c of Object.keys(root.keybinds).sort())
            n += ((root.keybinds[c] || []).length);
        root.totalBinds = n;
    }
    function playReveal() {
        revealFade.restart();
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
        expr = expr.replace(/\bkeycode\.([A-Za-z_][A-Za-z0-9_]*)/g,
            (_, key) => key === "period" ? "." : key);
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
        const reKeyLabels = /^\s*--\s*@keybind-labels\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$/;
        const reDesc = /^\s*---\s*(.+)$/;
        const reCat = /^\s*--\s+(.+)$/;
        const reBind = /^\s*hl\.bind/;
        const reDigits = /^[0-9]+$/;
        for (const line of root._splitLines(text)) {
            let m;
            if ((m = line.match(reKeyLabels))) {
                // Bind loops use a Lua variable for the key; this comment supplies
                // the readable labels to expand in the KeyBinds widget.
                state.keyLabels = state.keyLabels || {};
                state.keyLabels[m[1]] = m[2].split(",").map(label => root._squeeze(label)).filter(label => label !== "");
                continue;
            }
            if ((m = line.match(reMainMod))) {
                state.mainMod = m[1];
                continue;
            }
            if ((m = line.match(reDesc))) {
                state.comment = m[1];
                continue;
            } else if ((m = line.match(reCat))) {
                state.keyLabels = {};
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
                const hintKey = keys.find(key => Object.prototype.hasOwnProperty.call(state.keyLabels || {}, key));
                const labels = hintKey ? state.keyLabels[hintKey] : null;
                const description = state.comment !== "" ? state.comment : "Unknown Keybind";
                if (labels && labels.length > 0) {
                    for (const label of labels) {
                        const displayKeys = keys.map(key => key === hintKey ? label : key);
                        const displayDescription = description.split("[" + hintKey + "]").join(label);
                        out.map[state.open].push({ description: displayDescription, keys: displayKeys });
                    }
                } else {
                    out.map[state.open].push({ description: description, keys: keys });
                }
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
        const state = { mainMod: "SUPER", comment: "", pending: null, open: null, firstItem: true, lastCat: "", keyLabels: {} };
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
        // Not `nav`: inside a Repeater delegate an unqualified `nav` resolves to the
        // component's own property, so the id must differ for those bindings.
        id: catNav
        flickable: keyScroll
        content: keyCol
        categories: root.categories
    }

    // ---- UI: persistent category rail + one card per category ----
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing
        opacity: root.revealOpacity

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
                nav: catNav
                model: root.categories
                currentIndex: catNav.activeIndex
                onSelected: index => catNav.select(index)
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
                            catNav.cancel();
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
                            // Direct child of keyCol: CategoryNav finds the
                            // section for centering by this key.
                            property int categoryIndex: index
                            width: parent.width
                            spacing: Theme.spacing
                            // The card owns the fade (hover + scroll anchor); see CategorySection.

                            CategorySection {
                                width: parent.width
                                nav: catNav
                                categoryIndex: catSec.categoryIndex
                                title: catSec.category

                                Repeater {
                                    model: root.keybinds[catSec.category] || []
                                    // Title and keys sit on one line: the description
                                    // elides (tooltip on truncation) to leave the chips room.
                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: parent.width
                                        height: bindBody.implicitHeight + 8
                                        color: "transparent"

                                        RowLayout {
                                            id: bindBody

                                            anchors.fill: parent
                                            anchors.topMargin: 4
                                            anchors.bottomMargin: 4
                                            spacing: Theme.spacing

                                            Label {
                                                id: descriptionLabel
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                text: modelData.description
                                                font.pixelSize: ((typeof Settings !== "undefined") && Settings.keybindsDescriptionFontSize) ? Settings.keybindsDescriptionFontSize : Theme.fontSize
                                                color: Theme.fg
                                                elide: Text.ElideRight
                                                maximumLineCount: 1


                                                HoverHandler {
                                                    id: descriptionHover
                                                }

                                                AppTooltip {
                                                    visible: descriptionHover.hovered && descriptionLabel.truncated
                                                    text: descriptionLabel.text
                                                }
                                            }

                                            // key chips joined by "+" (shared AppKeybind widget)
                                            AppKeybind {
                                                Layout.alignment: Qt.AlignVCenter
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
