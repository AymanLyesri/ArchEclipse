import QtQuick
import QtQuick.Controls
import qs.theme
import qs.widgets.shared

// Settings Sync card (cloud upload/download + timestamps).
Rectangle {
    id: root
    required property var store
    width: parent.width
    implicitHeight: syncCol.implicitHeight + 20
    visible: !!store.profile
    color: Theme.bg
    radius: 8

    Column {
        id: syncCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8
        Label {
            text: "Settings Sync"
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            color: Theme.fg
        }
        Row {
            width: parent.width
            spacing: 8
            AppButton {
                width: (parent.width - 8) / 2
                text: store.isSyncing ? "Downloading..." : "Download"
                enabled: !store.isSyncing
                tooltipText: "Download settings from cloud"
                onClicked: store.syncSettings("download")
            }
            AppButton {
                width: (parent.width - 8) / 2
                text: store.isSyncing ? "Uploading..." : "Upload"
                enabled: !store.isSyncing
                tooltipText: "Upload settings to cloud"
                onClicked: store.syncSettings("upload")
            }
        }
        Label {
            width: parent.width
            text: "Last sync: " + store.lastSyncAt
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fgDim
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: "Last result: " + store.lastSyncResult
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fgDim
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: "Remote updated: " + store.lastRemoteUpdatedAt
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fgDim
            elide: Text.ElideRight
        }
    }
}
