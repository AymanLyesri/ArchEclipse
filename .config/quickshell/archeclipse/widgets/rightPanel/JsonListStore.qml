import QtQuick

// Shared JSON-list load/save (FileView create/read/destroy dance).
// Preserves the exact semantics both widgets used: non-empty trimmed text
// starting with "[" is JSON.parsed, anything else yields null; writes use
// JSON.stringify with 2-space indent. Only the file path varies.
QtObject {
    id: root
    property string filePath: ""
    function load() {
        try {
            const o = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + root.filePath + '" }', root);
            const t = o.text();
            let v = null;
            if (t !== "" && t.trim().startsWith("[")) {
                v = JSON.parse(t);
            }
            o.destroy();
            return v;
        } catch (e) {
            console.warn("[JsonListStore] Failed to load " + root.filePath + ":", e);
            return null;
        }
    }
    function save(list) {
        try {
            const o = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + root.filePath + '" }', root);
            o.setText(JSON.stringify(list, null, 2));
            o.destroy();
        } catch (e) {
            console.warn("[JsonListStore] Failed to save " + root.filePath + ":", e);
        }
    }
}
