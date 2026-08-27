import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Io

Item {
    id: root

    property string className: ""

    // Crypto entries
    property var entries: []

    // UI state
    property bool showAddForm: false
    property var editingEntry: null

    // Timeframes
    readonly property var timeframes: ["1h", "24h", "7d", "30d", "90d", "1y"]

    // Storage path
    readonly property string storagePath: Quickshell.env("HOME") + "/.config/ags/cache/crypto/entries.json"

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
                console.error("Failed to parse crypto entries:", e)
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

    function pinEntry(entry) {
        qs.theme.Settings.updateSetting("crypto.favorite", { symbol: entry.symbol, timeframe: entry.timeframe })
    }

    // Form component
    Component {
        id: cryptoFormComponent
        Item {
            id: form
            property var entry: root.editingEntry
            property bool isEdit: !!root.editingEntry

            property string symbol: root.editingEntry?.symbol ?? "btc"
            property string timeframe: root.editingEntry?.timeframe ?? "7d"
            property bool showPrice: root.editingEntry?.showPrice ?? true
            property bool showGraph: root.editingEntry?.showGraph ?? true

            Column {
                anchors.fill: parent
                spacing: 8

                // Symbol input
                Column { spacing: 4
                    Text { text: "Crypto Symbol"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    TextInput {
                        text: form.symbol
                        onTextChanged: form.symbol = text
                        placeholderText: "e.g. btc, eth, sol"
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                        padding: 8
                    }
                }

                // Timeframe selector
                Column { spacing: 4
                    Text { text: "Timeframe"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    Row { spacing: 4
                        Repeater {
                            model: root.timeframes
                            delegate: CheckBox {
                                text: modelData
                                checked: form.timeframe === modelData
                                onToggled: { if (checked) form.timeframe = modelData }
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // Display options
                Column { spacing: 4
                    Text { text: "Display Options"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.foreground }
                    Row { spacing: 8
                        CheckBox { text: "Show Price"; checked: form.showPrice; onToggled: form.showPrice = checked }
                        CheckBox { text: "Show Graph"; checked: form.showGraph; onToggled: form.showGraph = checked }
                    }
                }

                // Actions
                Row { spacing: 8
                    Button {
                        text: form.isEdit ? "✓ Update" : "+ Add Crypto"
                        onClicked: {
                            const newEntry = {
                                id: form.isEdit ? form.entry.id : Date.now().toString(),
                                symbol: form.symbol.trim().toLowerCase(),
                                timeframe: form.timeframe,
                                showPrice: form.showPrice,
                                showGraph: form.showGraph
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
        id: cryptoEntryComponent
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
                        Text { text: root.entry.symbol.toUpperCase(); font.family: "JetBrainsMono NFP"; font.pixelSize: 13; font.bold: true; color: qs.theme.Theme.foreground }
                        Text { text: root.entry.timeframe + " timeframe"; font.family: "JetBrainsMono NFP"; font.pixelSize: 10; color: qs.theme.Theme.color8 }
                    }
                    Item { Layout.fillWidth: true }
                    // Actions on hover
                    Row {
                        visible: entryItem.hovered
                        spacing: 4
                        Button { text: "📌"; onClicked: root.pinEntry(root.entry); font.pixelSize: 12 }
                        Button { text: "✏"; onClicked: { root.editingEntry = root.entry; root.showAddForm = true }; font.pixelSize: 12 }
                        Button { text: "✕"; onClicked: root.deleteEntry(root.entry.id); font.pixelSize: 12 }
                    }
                }

                // Crypto chart/price (placeholder - would use actual Crypto component)
                Rectangle {
                    width: parent.width
                    height: 100
                    radius: 6
                    color: qs.theme.Theme.color0
                    border.color: qs.theme.Theme.color8
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.entry.symbol.toUpperCase() + " Chart/Price"
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        color: qs.theme.Theme.color8
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
            Text { text: "Crypto Tracker"; font.family: "JetBrainsMono NFP"; font.pixelSize: 16; font.bold: true; color: qs.theme.Theme.foreground }
            Item { Layout.fillWidth: true }
            Button {
                text: root.showAddForm ? "✕" : "+"
                onClicked: { root.editingEntry = null; root.showAddForm = !root.showAddForm }
            }
        }

        // Add/Edit form
        Loader {
            visible: root.showAddForm
            sourceComponent: cryptoFormComponent
            height: 250
        }

        // Entries list
        Column {
            spacing: 8
            Repeater {
                model: root.entries
                delegate: Loader { sourceComponent: cryptoEntryComponent }
            }
        }
    }
}