import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Notification Stack Item component
Item {
    id: root
    property var stack: {}
    property var expandedStacks: {}
    signal toggleExpanded()
    signal clearStack()

    property bool isExpanded: !!(stack && stack.title && expandedStacks && expandedStacks[stack.title] === true)

    Column {
        anchors.fill: parent
        spacing: 0

        // Header
        Row {
            spacing: 5
            Label {
                id: titleLabel
                text: stack ? "(" + stack.notifications.length + ") " + stack.title : ""
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Row {
                spacing: 5
                visible: stack.notifications.length > 1
                Button {
                    text: isExpanded ? "▲" : "▼"
                    onClicked: root.toggleExpanded()
                    background: Rectangle {
                        color: Theme.accentBg
                        radius: 4
                        border.width: 1
                        border.color: Theme.accent
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        color: Theme.accent
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
                Button {
                    text: "🗑"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Clear all"
                    onClicked: root.clearStack()
                    background: Rectangle {
                        color: Theme.dangerBg
                        radius: 4
                        border.width: 1
                        border.color: Theme.danger
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        color: Theme.danger
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }

        // Content
        Loader {
            sourceComponent: isExpanded ? expandedContent : collapsedContent
            Layout.fillWidth: true
        }
    }

    Component {
        id: collapsedContent
        Column {
            spacing: 5
            NotificationItem {
                notification: stack.notifications[0]
            }
        }
    }

    Component {
        id: expandedContent
        Column {
            spacing: 5
            // Per-stack scrollable content (AGS notification-stack scrolledwindow
            // with "expanded"/"collapsed" class) — caps expanded height so a huge
            // stack scrolls within itself instead of blowing out the panel.
            ScrollView {
                width: parent.width
                height: Math.min(220, stack.notifications.length * 68)
                clip: true
                Column {
                    width: parent.width
                    spacing: 5
                    Repeater {
                        model: stack.notifications
                        delegate: NotificationItem {
                            width: parent.width
                            notification: modelData
                        }
                    }
                }
            }
        }
    }
}