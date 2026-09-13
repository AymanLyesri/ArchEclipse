import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared

// Shared right-panel card: header + add-form loader + guarded list.
// Delegates are passed as default content into the list column; the one true
// formatNextRun lives here (verbatim from TaskItem.qml) and hosted delegates
// reach it by walking up to objectName "rightPanelCard".
Column {
    id: root
    objectName: "rightPanelCard"
    default property alias content: listCol.children
    property string title: ""
    property bool showAddForm: false
    property Component formComponent: null
    property int listSpacing: 8
    signal addClicked()
    signal closeClicked()
    spacing: 8
    RowLayout {
        width: parent.width
        spacing: 8
        Label {
            text: root.title
            font.pixelSize: Theme.fontSize + 4
            font.bold: true
            color: Theme.fg
            Layout.fillWidth: true
        }
        AppButton { text: "+"; implicitWidth: 40; onClicked: root.addClicked() }
        AppButton { text: "\u2715"; implicitWidth: 40; onClicked: root.closeClicked() }
    }
    Loader {
        sourceComponent: root.showAddForm ? root.formComponent : null
        width: parent.width
        height: root.showAddForm ? 350 : 0
    }
    SmoothFlickable {
        width: parent.width
        // Guarded: a negative height sends Flickable into a silent polish loop
        height: Math.max(0, parent.height - y - 8)
        clip: true
        contentWidth: width
        contentHeight: listCol.height
        Column {
            id: listCol
            width: parent.width
            spacing: root.listSpacing
        }
    }
    function formatNextRun(nextRun) {
        if (!nextRun)
            return "Not scheduled";
        const date = new Date(nextRun);
        const now = new Date();
        const isToday = date.toDateString() === now.toDateString();

        if (isToday) {
            return "Today, " + date.toLocaleTimeString("en-US", {
                hour: "2-digit",
                minute: "2-digit",
                hour12: false
            });
        }
        return date.toLocaleString("en-US", {
            hour: "2-digit",
            minute: "2-digit",
            hour12: false,
            month: "short",
            day: "numeric"
        });
    }
}
