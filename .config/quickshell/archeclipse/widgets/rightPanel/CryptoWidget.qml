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

    // State for crypto entries
    property var cryptoEntries: []
    property bool showAddForm: false
    property var editingEntry: null
    property string _selectedTimeframe: "7d"

    JsonListStore {
        id: entryStore
        filePath: Quickshell.env("HOME") + "/.cache/quickshell/crypto/entries.json"
    }

    // Load entries from settings file on startup
    Component.onCompleted: {
        loadEntries();
    }

    function loadEntries() {
        const v = entryStore.load();
        cryptoEntries = v !== null ? v : [];
    }

    function saveEntries() {
        entryStore.save(cryptoEntries);
    }

    function addEntry(entry) {
        const newEntry = Object.assign({}, entry, {
            id: entry.id || Date.now().toString()
        });
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
        // Initialize the selected timeframe for the form (default 7d)
        root._selectedTimeframe = editEntry && editEntry.timeframe ? editEntry.timeframe : "7d";
        showAddForm = !showAddForm;
        if (!showAddForm) {
            editingEntry = null;
        }
    }

    // Timeframes available
    property var timeframes: ["1h", "24h", "7d", "30d", "90d", "1y"]

    RightPanelCard {
        anchors.fill: parent
        anchors.margins: 8
        title: "Crypto Tracker"
        showAddForm: root.showAddForm
        formComponent: cryptoForm
        onAddClicked: root.toggleForm()
        onCloseClicked: {
            if (root.showAddForm)
                root.toggleForm();
        }

        // Crypto List
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

    // Form Component
    Component {
        id: cryptoForm
        FormShell {
            clip: true

            // Symbol
            Column {
                spacing: 4
                width: parent.width
                Label {
                    text: "Crypto Symbol"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                AppTextField {
                    id: symbolField
                    placeholderText: "e.g. btc, eth, sol"
                    text: editingEntry ? editingEntry.symbol : ""
                    width: parent.width
                    onTextChanged: {
                        // Auto lowercase
                    }
                }
            }

            // Timeframe (row of toggle buttons, not a dropdown)
            Column {
                spacing: 4
                width: parent.width
                Label {
                    text: "Timeframe"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                RowLayout {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.timeframes
                        delegate: AppButton {
                            toggle: true
                            text: modelData
                            Layout.fillWidth: true
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
                width: parent.width
                Label {
                    text: "Display Options"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                RowLayout {
                    width: parent.width
                    spacing: 16
                    AppCheckBox {
                        id: showPriceCheck
                        text: "Show Price"
                        checked: editingEntry ? editingEntry.showPrice : true
                        Layout.fillWidth: true
                    }
                    AppCheckBox {
                        id: showGraphCheck
                        text: "Show Graph"
                        checked: editingEntry ? editingEntry.showGraph : true
                        Layout.fillWidth: true
                    }
                }
            }

            // Actions
            RowLayout {
                width: parent.width
                spacing: 8
                AppButton {
                    text: editingEntry ? "✓ Update" : "+ Add Crypto"
                    pixelSize: Theme.fontSize
                    cornerRadius: 4
                    idleBg: Theme.surfaceActive
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
                    text: "\u{f00d} Cancel"
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
