import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared

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
                // Expand chevron only for multi-item stacks; the clear button
                // ALWAYS renders (AGS ClearNotifications, no length guard).
                AppButton {
                    visible: stack.notifications.length > 1
                    icon: isExpanded ? "▲" : "▼"
                    pixelSize: Theme.fontSize - 2
                    cornerRadius: 4
                    idleBg: Theme.accentBg
                    idleFg: Theme.accent
                    outlined: true
                    outlineColor: Theme.accent
                    onClicked: root.toggleExpanded()
                }
                AppButton {
                    icon: "🗑"
                    pixelSize: Theme.fontSize - 2
                    cornerRadius: 4
                    idleBg: Theme.dangerBg
                    idleFg: Theme.danger
                    outlined: true
                    outlineColor: Theme.danger
                    tooltipText: "Clear all"
                    onClicked: root.clearStack()
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
                entry: stack.notifications[0]
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
                            entry: modelData
                        }
                    }
                }
            }
        }
    }
}