import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared

// Key Binds widget — reads the Hyprland Lua keybinds, groups them by
// category, and renders each binding as an array of key chips joined by "+".
// Loads keybinds from scripts/get-keybinds.sh (JSON),
// groups by category, renders each binding as an array of key chips
// joined by "+".
Item {
    id: root
    property int widgetWidth: parent.width

    // keybinds shape from get-keybinds.sh: { category: [{ description, keys: [] }] }
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

    // ---- load keybinds from script (get-keybinds.sh -> JSON.parse) ----
    Process {
        id: loadProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/get-keybinds.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.keybinds = parsed;
                } catch (e) {
                    console.warn("[KeyBindsWidget] Failed to parse get-keybinds.sh JSON:", text.slice(0, 200));
                }
                root.loading = false;
            }
        }
    }

    // sorted category names
    property var categories: Object.keys(root.keybinds).sort()

    // ---- UI: vertical category list (no filter row) ----
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

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
                spacing: 10

                Repeater {
                    model: root.categories
                    delegate: Column {
                        required property string modelData
                        required property int index
                        property string category: modelData
                        // Flat base of this category's rows in the reveal
                        // order (inner rows add their own index to it).
                        property int rowBase: root.catBase(index)
                        width: parent.width
                        spacing: 5
                        // Header appears just before its first row.
                        opacity: root.revealCount > rowBase ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        Label {
                            text: category
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            color: Theme.fg
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width
                        }

                        // binds within this category
                        Repeater {
                            model: root.keybinds[category] || []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: parent.width
                                color: "transparent"
                                height: 28
                                // Flat position (category base + row) vs the
                                // reveal counter; +1 so rows trail the header.
                                opacity: (rowBase + index + 1) <= root.revealCount ? 1 : 0
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
                                    spacing: 10
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
