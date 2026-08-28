import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import Quickshell.Io

Item {
    id: root

    property string className: ""

    // Script timer entries
    property var entries: []

    // UI state
    property bool showAddForm: false
    property var editingEntry: null

    // Storage path
    readonly property string storagePath: Quickshell.env("HOME") + "/.config/ags/cache/scripts/timers.json"

    // Load entries on startup
    Component.onCompleted: {
        loadEntries()
    }

    function loadEntries() {
        const fv = Qt.createQmlObject(
            'import Quickshell.Io; FileView { path: "' + root.storagePath + '" }',
            root
        )
        const text = fv.text()
        if (text !== "" && text.trim().startsWith("[")) {
            try {
                root.entries = JSON.parse(text)
            } catch (e) {
                console.error("Failed to parse script timers:", e)
                root.entries = []
            }
        }
        fv.destroy()
    }

    function saveEntries() {
        const fv = Qt.createQmlObject(
            'import Quickshell.Io; FileView { path: "' + root.storagePath + '" }',
            root
        )
        fv.setText(JSON.stringify(root.entries, null, 2))
        fv.destroy()
    }

    function addEntry(entry) {
        root.entries.push(entry)
        saveEntries()
        root.showAddForm = false
    }

    function updateEntry(id, updatedEntry) {
        const idx = root.entries.findIndex((e) => e.id === id)
        if (idx >= 0) {
            root.entries[idx] = updatedEntry
            saveEntries()
        }
        root.showAddForm = false
        root.editingEntry = null
    }

    function deleteEntry(id) {
        root.entries = root.entries.filter((e) => e.id !== id)
        saveEntries()
    }

    function runScript(entry) {
        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["bash", "-c", "' + entry.command.replace(/"/g, '\\"') + '"] }',
            root
        )
        proc.running = true
        proc.destroy()
    }

    // Form component
    Component {
        id: scriptFormComponent
        Item {
            id: form
            property var entry: root.editingEntry
            property bool isEdit: !!root.editingEntry

            property string name: root.editingEntry?.name ?? ""
            property string command: root.editingEntry?.command ?? ""
            property string schedule: root.editingEntry?.schedule ?? "daily"
            property string time: root.editingEntry?.time ?? "00:00"

            Column {
                anchors.fill: parent
                spacing: 8

                Column { spacing: 4
                    Text { text: "Name"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    TextInput {
                        text: form.name
                        onTextChanged: form.name = text
                        placeholderText: "Timer name"
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                        padding: 8
                    }
                }

                Column { spacing: 4
                    Text { text: "Command"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    TextInput {
                        text: form.command
                        onTextChanged: form.command = text
                        placeholderText: "bash command to run"
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                        padding: 8
                    }
                }

                Column { spacing: 4
                    Text { text: "Schedule"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    Row { spacing: 8
                        CheckBox { text: "Daily"; checked: form.schedule === "daily"; onToggled: { if (checked) form.schedule = "daily" } }
                        CheckBox { text: "Once"; checked: form.schedule === "once"; onToggled: { if (checked) form.schedule = "once" } }
                        CheckBox { text: "Interval"; checked: form.schedule === "interval"; onToggled: { if (checked) form.schedule = "interval" } }
                    }
                }

                Column { spacing: 4
                    Text { text: "Time (HH:MM)"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    TextInput {
                        text: form.time
                        onTextChanged: form.time = text
                        placeholderText: "00:00"
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                        padding: 8
                    }
                }

                Row { spacing: 8
                    Button {
                        text: form.isEdit ? "✓ Update" : "+ Add Timer"
                        onClicked: {
                            const newEntry = {
                                id: form.isEdit ? form.entry.id : Date.now().toString(),
                                name: form.name,
                                command: form.command,
                                schedule: form.schedule,
                                time: form.time
                            }
                            if (form.isEdit) root.updateEntry(form.entry.id, newEntry)
                            else root.addEntry(newEntry)
                        }
                    }
                    Button { text: "✕ Cancel"; onClicked: { root.showAddForm = false; root.editingEntry = null } }
                }
            }
        }
    }

    // Entry item component
    Component {
        id: scriptEntryComponent
        Item {
            id: entryItem
            property var entry: modelData
            property bool hovered: false

            Column {
                width: parent.width
                spacing: 6

                // Header
                Row {
                    spacing: 8
                    Column {
                        Text { text: root.entry.name; font.family: "JetBrainsMono NFP"; font.pixelSize: 13; font.bold: true; color: qs.theme.Theme.foreground }
                        Text { text: root.entry.schedule + " at " + root.entry.time; font.family: "JetBrainsMono NFP"; font.pixelSize: 10; color: qs.theme.Theme.color8 }
                    }
                    Item { Layout.fillWidth: true }
                    Row {
                        visible: entryItem.hovered
                        spacing: 4
                        Button { text: "▶"; onClicked: root.runScript(root.entry); font.pixelSize: 12 }
                        Button { text: "✏"; onClicked: { root.editingEntry = root.entry; root.showAddForm = true }; font.pixelSize: 12 }
                        Button { text: "✕"; onClicked: root.deleteEntry(root.entry.id); font.pixelSize: 12 }
                    }
                }

                // Command preview
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 6
                    color: qs.theme.Theme.color0
                    border.color: qs.theme.Theme.color8
                    border.width: 1

                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: root.entry.command
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 10
                        color: qs.theme.Theme.color8
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: entryItem.hovered = true
                onExited: entryItem.hovered = false
            }
        }
    }

    // Main layout
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Header
        Row {
            spacing: 10
            Text { text: "Script Timer"; font.family: "JetBrainsMono NFP"; font.pixelSize: 16; font.bold: true; color: qs.theme.Theme.foreground }
            Item { Layout.fillWidth: true }
            Button {
                text: root.showAddForm ? "✕" : "+"
                onClicked: { root.editingEntry = null; root.showAddForm = !root.showAddForm }
            }
        }

        // Add/Edit form
        Loader {
            visible: root.showAddForm
            sourceComponent: scriptFormComponent
            height: 250
        }

        // Entries list
        Column {
            spacing: 8
            Repeater {
                model: root.entries
                delegate: Loader { sourceComponent: scriptEntryComponent }
            }
        }
    }
}