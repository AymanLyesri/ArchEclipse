import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: root

    property string className: ""

    // Notifications from system
    property var notifications: Quickshell.Services.Notifications.notificationServer.popups

    // Filter
    property string filter: "all" // all, unread, dismissed

    // Grouped notifications
    property var groupedNotifications: []

    function updateGrouped() {
        const items = root.notifications
        const now = Date.now()

        // Sort by timestamp (newest first)
        const sorted = [...items].sort((a, b) => {
            const ta = new Date(a.timestamp).getTime()
            const tb = new Date(b.timestamp).getTime()
            return tb - ta
        })

        // Group by app
        const grouped = {}
        for (const n of sorted) {
            const key = n.appName
            if (!grouped[key]) grouped[key] = []
            grouped[key].push(n)
        }

        root.groupedNotifications = Object.entries(grouped).map(([app, notifs]) => ({
            app,
            notifications: notifs
        }))
    }

    Component.onCompleted: {
        updateGrouped()
        Quickshell.Services.Notifications.notificationServer.onPopupsChanged = updateGrouped
    }

    function dismissNotification(notification) {
        notification.close(Quickshell.Services.Notifications.NotificationCloseReason.DismissedByUser)
    }

    function dismissAll(app) {
        for (const n of app.notifications) {
            dismissNotification(n)
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Filter tabs
        Row {
            spacing: 5
            Repeater {
                model: ["all", "unread", "dismissed"]
                delegate: Button {
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    checked: root.filter === modelData
                    onClicked: root.filter = modelData
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 11
                    background: Rectangle {
                        color: root.filter === modelData ? qs.theme.Theme.accentBg : qs.theme.Theme.color0
                        border.color: root.filter === modelData ? qs.theme.Theme.accent : qs.theme.Theme.color8
                        border.width: 1
                        radius: 4
                    }
                }
            }
        }

        // Notification list
        Column {
            spacing: 8
            Repeater {
                model: root.groupedNotifications
                delegate: Item {
                    id: groupItem
                    property var group: modelData
                    width: parent.width

                    Column {
                        spacing: 4

                        // App header
                        Row {
                            spacing: 8
                            Text { text: root.group.app; font.family: "JetBrainsMono NFP"; font.pixelSize: 13; font.bold: true; color: qs.theme.Theme.foreground }
                            Item { Layout.fillWidth: true }
                            Button { text: "✕ All"; onClicked: root.dismissAll(root.group); font.pixelSize: 10; background: Rectangle { color: "transparent" } }
                        }

                        // Notifications
                        Column {
                            spacing: 4
                            Repeater {
                                model: root.group.notifications
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 60
                                    radius: 6
                                    color: qs.theme.Theme.color0
                                    border.color: qs.theme.Theme.color8
                                    border.width: 1

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 2

                                        Row {
                                            spacing: 8
                                            Text { text: modelData.summary; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; font.bold: true; color: qs.theme.Theme.foreground }
                                            Item { Layout.fillWidth: true }
                                            Text { text: Qt.formatDateTime(new Date(modelData.timestamp), "HH:mm"); font.family: "JetBrainsMono NFP"; font.pixelSize: 9; color: qs.theme.Theme.color8 }
                                        }

                                        Text {
                                            text: modelData.body
                                            font.family: "JetBrainsMono NFP"
                                            font.pixelSize: 10
                                            color: qs.theme.Theme.color8
                                            wrapMode: Text.Wrap
                                        }

                                        Row {
                                            Item { Layout.fillWidth: true }
                                            Button {
                                                text: "Dismiss"
                                                onClicked: root.dismissNotification(modelData)
                                                font.pixelSize: 9
                                                background: Rectangle { color: qs.theme.Theme.accentBg; border.color: qs.theme.Theme.accent; border.width: 1; radius: 3 }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (modelData.actions.length > 0) {
                                                modelData.actions[0].invoke()
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
    }
}