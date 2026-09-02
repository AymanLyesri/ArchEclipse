import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.theme

// Single Notification Item component — port of NotificationWidget from
// widgets/rightPanel/components/Notification.tsx. Shows app name/icon, summary,
// body text with expand/collapse, copy-to-clipboard, notification actions,
// and dismiss button.
Item {
    id: root
    property var notification: {}
    property bool isHovered: false
    property bool bodyExpanded: false

    // Time display — Quickshell's NotifDataObject may not expose `time`,
    // so try notification.time first, then notification.notif.time
    readonly property double notifTime: {
        if (root.notification.time !== undefined && root.notification.time)
            return root.notification.time;
        if (root.notification.notif && root.notification.notif.time !== undefined)
            return root.notification.notif.time;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.moduleBg
        radius: Theme.radius
        border.width: 1
        border.color: Theme.border
        clip: true

        Column {
            anchors.fill: parent
            spacing: 4
            anchors.margins: 8

            // Top bar: app name, icon, time, copy, expand, dismiss
            Row {
                spacing: 6
                width: parent.width

                Text {
                    id: appIcon
                    width: 20; height: 20
                    font.pixelSize: 16
                    text: root.notification.appIcon || "●"
                    color: Theme.accent
                    visible: text !== ""
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: appNameLabel
                    text: root.notification.appName || "Unknown"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.accent
                    width: appIcon.visible ? parent.width - 20 - 8 : parent.width
                    elide: Text.ElideRight
                }

                Item { Layout.fillWidth: true }

                // Time
                Text {
                    id: timeLabel
                    text: root.notifTime > 0
                        ? new Date(root.notifTime * 1000).toLocaleTimeString([], {
                            hour: "2-digit", minute: "2-digit", hour12: true
                        })
                        : ""
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                    visible: text !== ""
                }

                // Copy to clipboard
                Button {
                    id: copyBtn
                    text: "\u{f0c5}"
                    width: 24; height: 24
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: "Copy text"
                    visible: root.isHovered
                    onClicked: {
                        const content = root.notification.body || root.notification.appName || "";
                        if (content) {
                            Quickshell.execDetached(["wl-copy", content]);
                        }
                    }
                    background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                    contentItem: Text { color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                }

                // Expand/collapse body
                Button {
                    id: expandBtn
                    text: root.bodyExpanded ? "\u{f07e}" : "\u{f07c}"
                    width: 24; height: 24
                    visible: root.notification.body && root.notification.body.length > 100
                    onClicked: root.bodyExpanded = !root.bodyExpanded
                    background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                    contentItem: Text { color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                }

                // Dismiss
                Button {
                    text: "\u{f00d}"
                    width: 24; height: 24
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: "Dismiss"
                    onClicked: {
                        root.notification.dismiss();
                    }
                    background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                    contentItem: Text { color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                }
            }

            // Summary
            Text {
                text: root.notification.summary || ""
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                width: parent.width
                wrapMode: Text.WordWrap
            }

            // Body (expandable)
            Text {
                text: root.notification.body || ""
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
                width: parent.width
                wrapMode: Text.WordWrap
                visible: text !== ""
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.isHovered = true
            onExited: root.isHovered = false
        }
    }
}
