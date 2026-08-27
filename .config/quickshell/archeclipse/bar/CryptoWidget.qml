import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.theme
import Quickshell

// Crypto Viewer widget ported from widgets/rightPanel/components/CryptoViewer.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    // State for crypto entries
    property var cryptoEntries: []
    property bool showAddForm: false
    property var editingEntry: null

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
        cryptoEntries = cryptoEntries.filter(e => e.id !== id);
        saveEntries();
    }

    function toggleForm(editEntry = null) {
        editingEntry = editEntry;
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
            Button {
                text: showAddForm ? "✕" : "+"
                onClicked: toggleForm()
                Layout.preferredWidth: 40
                background: Rectangle {
                    color: showAddForm ? Theme.dangerBg : Theme.accentBg
                    radius: 4
                    border.width: 1
                    border.color: showAddForm ? Theme.danger : Theme.accent
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    color: showAddForm ? Theme.danger : Theme.accent
                    font.pixelSize: Theme.fontSize
                }
            }
        }

        // Add/Edit Form
        Loader {
            sourceComponent: showAddForm ? formComponent : null
            Layout.fillWidth: true
        }

        // Crypto List
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                id: listColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: cryptoEntries
                    delegate: EntryItem {
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

                // Timeframe
                Column {
                    spacing: 4
                    Label {
                        text: "Timeframe"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    ComboBox {
                        id: timeframeCombo
                        model: root.timeframes
                        currentIndex: editingEntry ? root.timeframes.indexOf(editingEntry.timeframe) : 2
                        Layout.fillWidth: true
                        background: Rectangle {
                            color: Theme.bg
                            radius: 4
                            border.width: 1
                            border.color: Theme.border
                        }
                        contentItem: Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: model[timeframeCombo.currentIndex]
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
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
                    Button {
                        text: editingEntry ? "✓ Update" : "+ Add Crypto"
                        Layout.fillWidth: true
                        onClicked: {
                            const symbol = symbolField.text.trim().toLowerCase();
                            if (!symbol) return;

                            const entry = {
                                id: editingEntry ? editingEntry.id : Date.now().toString(),
                                symbol: symbol,
                                timeframe: timeframeCombo.currentText,
                                showPrice: showPriceCheck.checked,
                                showGraph: showGraphCheck.checked
                            };

                            if (editingEntry) {
                                updateEntry(entry);
                            } else {
                                addEntry(entry);
                            }
                            toggleForm();
                        }
                        background: Rectangle {
                            color: Theme.accentBg
                            radius: 4
                            border.width: 1
                            border.color: Theme.accent
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize
                        }
                    }
                    Button {
                        text: "✕ Cancel"
                        onClicked: toggleForm()
                        background: Rectangle {
                            color: Theme.dangerBg
                            radius: 4
                            border.width: 1
                            border.color: Theme.danger
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: Theme.danger
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }
        }
    }
}