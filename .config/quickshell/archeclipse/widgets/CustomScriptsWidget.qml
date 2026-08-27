import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Io

Item {
    id: root

    property string className: ""

    // Custom scripts
    property var scripts: []

    // UI state
    property bool showAddForm: false
    property var editingScript: null

    // Storage path
    readonly property string storagePath: Quickshell.env("HOME") + "/.config/ags/cache/scripts/custom.json"

    // Load on startup
    Component.onCompleted: {
        loadScripts()
    }

    function loadScripts() {
        const fv = Qt.createQmlObject(
            'import Quickshell.Io; FileView { path: "' + root.storagePath + '" }',
            root
        )
        const text = fv.text()
        if (text !== "" && text.trim().startsWith("[")) {
            try {
                root.scripts = JSON.parse(text)
            } catch (e) {
                console.error("Failed to parse custom scripts:", e)
                root.scripts = []
            }
        }
        fv.destroy()
    }

    function saveScripts() {
        const fv = Qt.createQmlObject(
            'import Quickshell.Io; FileView { path: "' + root.storagePath + '" }',
            root
        )
        fv.setText(JSON.stringify(root.scripts, null, 2))
        fv.destroy()
    }

    function addScript(script) {
        root.scripts.push(script)
        saveScripts()
        root.showAddForm = false
    }

    function updateScript(id, updatedScript) {
        const idx = root.scripts.findIndex((s) => s.id === id)
        if (idx >= 0) {
            root.scripts[idx] = updatedScript
            saveScripts()
        }
        root.showAddForm = false
        root.editingScript = null
    }

    function deleteScript(id) {
        root.scripts = root.scripts.filter((s) => s.id !== id)
        saveScripts()
    }

    function runScript(script) {
        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["bash", "-c", "' + script.command.replace(/"/g, '\\"') + '"] }',
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
            property var script: root.editingScript
            property bool isEdit: !!root.editingScript

            property string name: root.editingScript?.name ?? ""
            property string command: root.editingScript?.command ?? ""
            property string category: root.editingScript?.category ?? "general"

            Column {
                anchors.fill: parent
                spacing: 8

                Column { spacing: 4
                    Text { text: "Name"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    TextInput {
                        text: form.name
                        onTextChanged: form.name = text
                        placeholderText: "Script name"
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
                        placeholderText: "bash command"
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                        padding: 8
                    }
                }

                Column { spacing: 4
                    Text { text: "Category"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    ComboBox {
                        model: ["general", "system", "media", "development", "custom"]
                        currentIndex: model.indexOf(form.category)
                        onCurrentIndexChanged: form.category = modelData
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }
                }

                Row { spacing: 8
                    Button {
                        text: form.isEdit ? "✓ Update" : "+ Add Script"
                        onClicked: {
                            const newScript = {
                                id: form.isEdit ? form.script.id : Date.now().toString(),
                                name: form.name,
                                command: form.command,
                                category: form.category
                            }
                            if (form.isEdit) root.updateScript(form.script.id, newScript)
                            else root.addScript(newScript)
                        }
                    }
                    Button { text: "✕ Cancel"; onClicked: { root.showAddForm = false; root.editingScript = null } }
                }
            }
        }
    }

    // Script item component
    Component {
        id: scriptEntryComponent
        Item {
            id: entryItem
            property var script: modelData
            property bool hovered: false

            Column {
                width: parent.width
                spacing: 6

                Row {
                    spacing: 8
                    Column {
                        Text { text: root.script.name; font.family: "JetBrainsMono NFP"; font.pixelSize: 13; font.bold: true; color: qs.theme.Theme.foreground }
                        Text { text: root.script.category; font.family: "JetBrainsMono NFP"; font.pixelSize: 10; color: qs.theme.Theme.color8 }
                    }
                    Item { Layout.fillWidth: true }
                    Row {
                        visible: entryItem.hovered
                        spacing: 4
                        Button { text: "▶"; onClicked: root.runScript(root.script); font.pixelSize: 12 }
                        Button { text: "✏"; onClicked: { root.editingScript = root.script; root.showAddForm = true }; font.pixelSize: 12 }
                        Button { text: "✕"; onClicked: root.deleteScript(root.script.id); font.pixelSize: 12 }
                    }
                }

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
                        text: root.script.command
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

        Row {
            spacing: 10
            Text { text: "Custom Scripts"; font.family: "JetBrainsMono NFP"; font.pixelSize: 16; font.bold: true; color: qs.theme.Theme.foreground }
            Item { Layout.fillWidth: true }
            Button {
                text: root.showAddForm ? "✕" : "+"
                onClicked: { root.editingScript = null; root.showAddForm = !root.showAddForm }
            }
        }

        Loader {
            visible: root.showAddForm
            sourceComponent: scriptFormComponent
            height: 200
        }

        Column {
            spacing: 8
            Repeater {
                model: root.scripts
                delegate: Loader { sourceComponent: scriptEntryComponent }
            }
        }
    }
}