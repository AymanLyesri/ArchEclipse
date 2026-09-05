import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.theme
import qs.services

// Port of NotificationPopups.tsx window — top-right stack of popup cards,
// overlay layer, hidden when empty. One per monitor like AGS.
// Model entries: {id, time (epoch s), notif (live NotificationObject)}.
PanelWindow {
    id: root

    required property ShellScreen screen
    anchors { top: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    margins { top: 10; right: 10 }
    implicitWidth: 400
    implicitHeight: popColumn.childrenRect.height + 4
    visible: Notifications.popups.length > 0

    Column {
        id: popColumn
        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.width
        spacing: Theme.spacing

        Repeater {
            model: Notifications.popups

            Rectangle {
                id: card
                required property var modelData
                readonly property var notif: modelData.notif
                readonly property bool critical:
                    notif && notif.urgency === NotificationUrgency.Critical
                property bool bodyExpanded: false

                width: 400
                height: contentCol.childrenRect.height + 20 + (buttonsRow.visible ? buttonsRow.height + 8 : 0)
                radius: Theme.radius
                color: critical ? Qt.rgba(0.66, 0.27, 0.27, 0.95) : Theme.moduleBg
                border.color: Qt.alpha(Theme.foreground, 0.1)
                border.width: 1

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 200 } }

                // Icon chain (AGS getNotificationIcon): file path → theme
                // name → desktopEntry → critical warning glyph → info glyph.
                readonly property string iconFile: {
                    if (!card.notif) return "";
                    if (card.notif.appIcon && String(card.notif.appIcon).startsWith("/")) return card.notif.appIcon;
                    if (card.notif.image && String(card.notif.image).startsWith("/")) return card.notif.image;
                    return "";
                }
                readonly property string iconName: {
                    if (!card.notif) return "";
                    if (card.notif.appIcon && !String(card.notif.appIcon).startsWith("/")) return card.notif.appIcon;
                    if (card.notif.image && !String(card.notif.image).startsWith("/")) return card.notif.image;
                    if (card.notif.desktopEntry) return card.notif.desktopEntry;
                    return "";
                }

                Column {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Row {
                        id: contentCol
                        width: parent.width
                        spacing: 10

                        // ---- app icon ----
                        Item {
                            id: iconSlot
                            width: 28
                            height: 28
                            IconImage {
                                id: iconImg
                                visible: status === Image.Ready && (card.iconFile !== "" || card.iconName !== "")
                                anchors.fill: parent
                                source: card.iconFile !== "" ? card.iconFile : card.iconName
                            }
                            Text {
                                visible: !iconImg.visible
                                width: parent.width; height: parent.height
                                text: card.critical ? "\u{F0266}" : "\u{F059A}"
                                color: card.critical ? "white" : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Column {
                            width: parent.width - 38
                            spacing: 3

                            // ---- top bar: title + time (24h %H:%M, AGS) ----
                            RowLayout {
                                spacing: 6
                                width: parent.width
                                Text {
                                    text: (card.notif && (card.notif.summary || card.notif.appName)) || ""
                                    textFormat: Text.StyledText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    color: card.critical ? "white" : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fontSize
                                }
                                Text {
                                    text: (card.modelData.time || 0) > 0
                                        ? new Date(card.modelData.time * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false })
                                        : ""
                                    color: card.critical ? Qt.alpha("white", 0.7) : Theme.fgDim
                                    font.pixelSize: Theme.fontSize - 2
                                    visible: text !== ""
                                }
                            }

                            // ---- body (expandable, AGS markup handling) ----
                            Text {
                                width: parent.width
                                visible: (card.notif && card.notif.body) !== ""
                                text: (card.notif && card.notif.body) || ""
                                textFormat: Text.StyledText
                                wrapMode: Text.WordWrap
                                maximumLineCount: card.bodyExpanded ? undefined : 4
                                elide: card.bodyExpanded ? Text.ElideNone : Text.ElideRight
                                color: card.critical ? Qt.alpha("white", 0.85) : Theme.foregroundSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                        }
                    }

                    // ---- action buttons (AGS: all actions, invoke, NO dismiss) ----
                    Row {
                        id: actionsRow
                        visible: card.notif && Notifications.liveActions(card.notif).length > 0
                        spacing: 4
                        Repeater {
                            model: card.notif ? Notifications.liveActions(card.notif) : []
                            delegate: Button {
                                required property var modelData
                                text: Notifications.actionLabel(modelData)
                                height: 24
                                onClicked: { try { modelData.invoke(); } catch (e) {} }
                                background: Rectangle {
                                    color: Theme.moduleBg
                                    border.color: Theme.border
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }
                        }
                    }

                    // ---- popup control buttons: copy, expand, dismiss ----
                    Row {
                        id: buttonsRow
                        visible: card.isHovered
                        spacing: 4
                        Button {
                            text: "\u{f0c5}"
                            onClicked: {
                                const n = card.notif;
                                if (!n) return;
                                // AGS: image payload via wl-copy image/png + toast
                                if (n.image && String(n.image).startsWith("/")) {
                                    const p = Qt.createQmlObject("import Quickshell.Io; Process {}", card);
                                    p.command = ["bash", "-c", "wl-copy --type image/png < " + JSON.stringify(n.image)];
                                    p.exited.connect((code) => {
                                        Notifications.notify(code === 0
                                            ? { summary: "Copied", body: n.image }
                                            : { summary: "Error", body: "Copy failed" });
                                        p.destroy();
                                    });
                                    p.running = true;
                                    return;
                                }
                                const t = n.body || n.summary;
                                if (t) Quickshell.execDetached(["wl-copy", t]);
                            }
                            contentItem: Text { text: parent.text; color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                        }
                        Button {
                            text: card.bodyExpanded ? "\u{f07e}" : "\u{f07c}"
                            visible: (card.notif && (card.notif.body || "")).length > 60
                            onClicked: card.bodyExpanded = !card.bodyExpanded
                            contentItem: Text { text: parent.text; color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                        }
                        Button {
                            text: "\u{f00d}"
                            onClicked: Notifications.closePopup(card.modelData.id, true)
                            contentItem: Text { text: parent.text; color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                        }
                    }
                }

                property bool isHovered: false
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: card.isHovered = true
                    onExited: card.isHovered = false
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton)
                            Notifications.closePopup(card.modelData.id, true);   // AGS right-click dismiss
                    }
                }
            }
        }
    }
}
