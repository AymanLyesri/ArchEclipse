import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services

// Single Notification Item component — port of NotificationWidget from
// widgets/rightPanel/components/Notification.tsx. Shows app name/icon, summary,
// body text with expand/collapse, copy-to-clipboard, notification actions,
// and dismiss button.
//
// Props: `entry` = {id, time (epoch s, snapshot at receipt), notif (live
// NotificationObject)}. All display fields read the live object; dismiss and
// action-invoke act on it directly (AGS: n.dismiss(), n.invoke(action.id)).
Item {
    id: root
    property var entry: null
    readonly property var notification: entry ? entry.notif : null
    property bool isHovered: false
    property bool bodyExpanded: false

    // Snapshot receipt time (QS NotificationObject has no .time; AGS shows
    // 24h %H:%M from GLib DateTime).
    readonly property double notifTime: entry && entry.time ? entry.time : 0

    // ---- icon chain (AGS getNotificationIcon): appIcon path → appIcon theme
    // name → image path → image theme name → desktopEntry → urgency fallback
    readonly property string iconFile: {
        const n = root.notification;
        if (!n) return "";
        if (n.appIcon && String(n.appIcon).startsWith("/")) return n.appIcon;
        if (n.image && String(n.image).startsWith("/")) return n.image;
        return "";
    }
    readonly property string iconName: {
        const n = root.notification;
        if (!n) return "";
        if (n.appIcon && !String(n.appIcon).startsWith("/")) return n.appIcon;
        if (n.image && !String(n.image).startsWith("/")) return n.image;
        if (n.desktopEntry) return n.desktopEntry;
        return "";
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

                Item {
                    id: appIconWrap
                    width: 20; height: 20
                    visible: root.iconFile !== "" || root.iconName !== "" || (root.notification && root.notification.urgency === 2)
                    IconImage {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.iconFile !== "" ? root.iconFile : root.iconName
                        visible: status === Image.Ready && (root.iconFile !== "" || root.iconName !== "")
                    }
                    Text {
                        anchors.fill: parent
                        visible: root.iconFile === "" && root.iconName === ""
                        text: "\u{F059A}"
                        font.pixelSize: 16
                        color: Theme.accent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    id: appNameLabel
                    text: (root.notification && root.notification.appName) || "Unknown"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.accent
                    width: appIconWrap.visible ? parent.width - 20 - 8 : parent.width
                    elide: Text.ElideRight
                }

                Item { Layout.fillWidth: true }

                // Time — 24h %H:%M like AGS utils/time.ts
                Text {
                    id: timeLabel
                    text: root.notifTime > 0
                        ? new Date(root.notifTime * 1000).toLocaleTimeString([], {
                            hour: "2-digit", minute: "2-digit", hour12: false
                        })
                        : ""
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                    visible: text !== ""
                }

                // Copy to clipboard (AGS copyNotificationContent: image payload
                // via wl-copy --type image/png with Copied/Error toast, else text)
                Button {
                    id: copyBtn
                    text: "\u{f0c5}"
                    width: 24; height: 24
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: "Copy text"
                    visible: root.isHovered
                    onClicked: root.copyContent()
                    background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                    contentItem: Text { color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                }

                // Expand/collapse body
                Button {
                    id: expandBtn
                    text: root.bodyExpanded ? "\u{f07e}" : "\u{f07c}"
                    width: 24; height: 24
                    visible: root.notification && root.notification.body && root.notification.body.length > 100
                    onClicked: root.bodyExpanded = !root.bodyExpanded
                    background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                    contentItem: Text { color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                }

                // Dismiss (AGS dismissNotification → n.dismiss())
                Button {
                    text: "\u{f00d}"
                    width: 24; height: 24
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: "Dismiss"
                    onClicked: {
                        try { if (root.notification) root.notification.dismiss(); } catch (e) {}
                    }
                    background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                    contentItem: Text { color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                }
            }

            // Summary (AGS: Pango markup validated, escaped when invalid)
            Text {
                text: (root.notification && root.notification.summary) || ""
                textFormat: Text.StyledText
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.fg
                width: parent.width
                wrapMode: Text.WordWrap
            }

            // Body (expandable, AGS markup handling)
            Text {
                text: (root.notification && root.notification.body) || ""
                textFormat: Text.StyledText
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
                width: parent.width
                wrapMode: Text.WordWrap
                maximumLineCount: root.bodyExpanded ? undefined : 3
                elide: root.bodyExpanded ? Text.ElideNone : Text.ElideRight
                visible: text !== ""

                // "more" hint when collapsed and truncated
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.bodyExpanded = !root.bodyExpanded
                }
            }

            // Notification action buttons (AGS getActions: ALL actions kept,
            // invoke WITHOUT dismiss, label = last ":" segment).
            Row {
                spacing: 6
                width: parent.width
                visible: (root.notification && Notifications.liveActions(root.notification).length) > 0
                Repeater {
                    model: root.notification ? Notifications.liveActions(root.notification) : []
                    delegate: Button {
                        required property var modelData
                        text: Notifications.actionLabel(modelData)
                        height: 24
                        font.pixelSize: Theme.fontSize - 2
                        onClicked: { try { modelData.invoke(); } catch (e) {} }
                        background: Rectangle {
                            color: Theme.accentBg
                            radius: 4
                            border.color: Theme.accent
                        }
                        contentItem: Text {
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize - 2
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.isHovered = true
            onExited: root.isHovered = false
        }
    }

    function copyContent() {
        const n = root.notification;
        if (!n) return;
        if (n.image && String(n.image).startsWith("/")) {
            const p = Qt.createQmlObject("import Quickshell.Io; Process {}", root);
            p.command = ["bash", "-c", "wl-copy --type image/png < " + JSON.stringify(n.image)];
            p.exited.connect((code) => {
                if (code === 0) Notifications.notify({ summary: "Copied", body: n.image });
                else Notifications.notify({ summary: "Error", body: "Copy failed" });
                p.destroy();
            });
            p.running = true;
            return;
        }
        const content = n.body || n.appName || "";
        if (content) {
            Quickshell.execDetached(["wl-copy", content]);
        }
    }
}
