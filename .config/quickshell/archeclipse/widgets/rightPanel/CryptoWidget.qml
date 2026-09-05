import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.theme
import Quickshell
import qs.widgets.shared

// Crypto Viewer widget ported from widgets/rightPanel/components/CryptoViewer.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    // State for crypto entries
    property var cryptoEntries: []
    property bool showAddForm: false
    property var editingEntry: null
    property string _selectedTimeframe: "7d"

    // Load entries from settings file on startup
    Component.onCompleted: {
        loadEntries();
    }

    function loadEntries() {
        try {
            const fileView = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + Quickshell.env("HOME") + '/.config/ags/cache/crypto/entries.json" }', root);
            const text = fileView.text();
            if (text !== "" && text.trim().startsWith("[")) {
                cryptoEntries = JSON.parse(text);
            }
            fileView.destroy();
        } catch (e) {
            console.warn("[CryptoViewer] Failed to load entries:", e);
            cryptoEntries = [];
        }
    }

    function saveEntries() {
        try {
            const fileView = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + Quickshell.env("HOME") + '/.config/ags/cache/crypto/entries.json" }', root);
            fileView.setText(JSON.stringify(cryptoEntries, null, 2));
            fileView.destroy();
        } catch (e) {
            console.warn("[CryptoViewer] Failed to save entries:", e);
        }
    }

    function addEntry(entry) {
        const newEntry = Object.assign({}, entry, { id: entry.id || Date.now().toString() });
        cryptoEntries = [...cryptoEntries, newEntry];
        saveEntries();
    }

    function updateEntry(entry) {
        cryptoEntries = cryptoEntries.map(e => e.id === entry.id ? entry : e);
        saveEntries();
    }

    function deleteEntry(id) {
        const entry = cryptoEntries.find(e => e.id === id);
        cryptoEntries = cryptoEntries.filter(e => e.id !== id);
        saveEntries();
        if (entry && entry.symbol) {
            Quickshell.execDetached(["notify-send", "Crypto Display", entry.symbol.toUpperCase() + " removed"]);
        }
    }

    function toggleForm(editEntry = null) {
        editingEntry = editEntry;
        // Initialize the selected timeframe for the form (AGS default 7d)
        root._selectedTimeframe = editEntry && editEntry.timeframe ? editEntry.timeframe : "7d";
        showAddForm = !showAddForm;
        if (!showAddForm) {
            editingEntry = null;
        }
    }

    // Timeframes available
    property var timeframes: ["1h", "24h", "7d", "30d", "90d", "1y"]

    Column {
        anchors.fill: parent
        spacing: 8

        // Header
        Row {
            spacing: 8
            Label {
                text: "Crypto Tracker"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
            AppButton {
                text: showAddForm ? "✕" : "+"
                pixelSize: Theme.fontSize
                cornerRadius: 4
                idleBg: showAddForm ? Theme.dangerBg : Theme.accentBg
                idleFg: showAddForm ? Theme.danger : Theme.accent
                outlined: true
                outlineColor: showAddForm ? Theme.danger : Theme.accent
                implicitWidth: 40
                onClicked: toggleForm()
            }
        }

        // Add/Edit Form
        Loader {
            sourceComponent: showAddForm ? formComponent : null
            width: parent.width
            height: showAddForm ? 350 : 0
        }

        // Crypto List
        ScrollView {
            width: parent.width
            // Guarded: a negative height sends Flickable into a silent polish loop
            height: Math.max(0, parent.height - y - 8)
            clip: true

            Column {
                id: listColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: cryptoEntries
                    delegate: CryptoEntryItem {
                        width: parent.width
                        entry: modelData
                        onDeleteClicked: deleteEntry(modelData.id)
                        onEditClicked: toggleForm(modelData)
                    }
                }
            }
        }
    }

    // Form Component
    Component {
        id: formComponent
        Rectangle {
            color: Theme.moduleBg
            radius: Theme.radius
            border.width: 1
            border.color: Theme.border
            Layout.fillWidth: true
            Layout.minimumHeight: 300
            Layout.preferredHeight: 350
            clip: true

            Column {
                anchors.fill: parent
                spacing: 12
                anchors.margins: 16

                // Symbol
                Column {
                    spacing: 4
                    Label {
                        text: "Crypto Symbol"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    TextField {
                        id: symbolField
                        placeholderText: "e.g. btc, eth, sol"
                        text: editingEntry ? editingEntry.symbol : ""
                        onTextChanged: {
                            // Auto lowercase
                        }
                    }
                }

                // Timeframe (AGS uses a row of toggle buttons, not a dropdown)
                Column {
                    spacing: 4
                    Label {
                        text: "Timeframe"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    Row {
                        spacing: 4
                        Repeater {
                            model: root.timeframes
                            delegate: AppButton {
                                toggle: true
                                text: modelData
                                pixelSize: Theme.fontSize - 1
                                cornerRadius: 4
                                implicitHeight: 26
                                checked: root._selectedTimeframe === modelData
                                onClicked: root._selectedTimeframe = modelData
                            }
                        }
                    }
                }

                // Display Options
                Column {
                    spacing: 8
                    Label {
                        text: "Display Options"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    Row {
                        spacing: 16
                        CheckBox {
                            id: showPriceCheck
                            text: "Show Price"
                            checked: editingEntry ? editingEntry.showPrice : true
                            Layout.fillWidth: true
                        }
                        CheckBox {
                            id: showGraphCheck
                            text: "Show Graph"
                            checked: editingEntry ? editingEntry.showGraph : true
                            Layout.fillWidth: true
                        }
                    }
                }

                // Actions
                Row {
                    spacing: 8
                    Layout.fillWidth: true
                    AppButton {
                        text: editingEntry ? "✓ Update" : "+ Add Crypto"
                        pixelSize: Theme.fontSize
                        cornerRadius: 4
                        idleBg: Theme.accentBg
                        idleFg: Theme.accent
                        outlined: true
                        outlineColor: Theme.accent
                        Layout.fillWidth: true
                        onClicked: {
                            const symbol = symbolField.text.trim().toLowerCase();
                            if (!symbol) {
                                Quickshell.execDetached(["notify-send", "Crypto Display", "Please enter a valid symbol"]);
                                return;
                            }

                            const entry = {
                                id: editingEntry ? editingEntry.id : Date.now().toString(),
                                symbol: symbol,
                                timeframe: root._selectedTimeframe,
                                showPrice: showPriceCheck.checked,
                                showGraph: showGraphCheck.checked
                            };

                            if (editingEntry) {
                                updateEntry(entry);
                            } else {
                                addEntry(entry);
                            }
                            Quickshell.execDetached(["notify-send", "Crypto Display", symbol.toUpperCase() + " " + (editingEntry ? "updated" : "added") + " successfully"]);
                            toggleForm();
                        }
                    }
                    AppButton {
                        text: "✕ Cancel"
                        pixelSize: Theme.fontSize
                        cornerRadius: 4
                        idleBg: Theme.dangerBg
                        idleFg: Theme.danger
                        outlined: true
                        outlineColor: Theme.danger
                        onClicked: toggleForm()
                    }
                }
            }
        }
    }
}