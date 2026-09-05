import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.theme

// Notification History widget ported from widgets/rightPanel/components/NotificationHistory.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    // Get notifications from the service
    property var notifications: []
    property string filterText: ""
    property var expandedStacks: {}

    Connections {
        target: Notifications
        function onPopupsChanged() {
            root.notifications = Notifications.popups;
        }
    }

    function stackNotifications(notifications, filter) {
        const MAX_NOTIFICATIONS = 50;
        const stacks = new Map();

        const sorted = [...notifications].sort((a, b) => b.notif.time - a.notif.time);

        sorted.forEach(n => {
            if (filter && !n.summary.includes(filter) && !n.appName.includes(filter))
                return;

            const key = n.summary || "Unknown";
            if (!stacks.has(key)) stacks.set(key, []);
            stacks.get(key).push(n);
        });

        const result = [...stacks.entries()].map(([title, notifications]) => ({ title, notifications }));

        // Flatten manually since flatMap might not be available
        const flat = [];
        result.forEach(s => s.notifications.forEach(n => flat.push(n)));
        flat.slice(MAX_NOTIFICATIONS).forEach(n => n.notif.dismiss());

        return result;
    }

    property var stackedNotifications: stackNotifications(notifications, filterText)

    Column {
        anchors.fill: parent
        spacing: 8

        // Header with filter
        Row {
            spacing: 8
            Label {
                text: "Notification History"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
            TextField {
                id: filterField
                placeholderText: "Filter..."
                text: filterText
                onTextChanged: root.filterText = text
                Layout.preferredWidth: 150
                background: Rectangle {
                    color: Theme.bg
                    radius: 4
                    border.width: 1
                    border.color: Theme.border
                }
            }
        }

        // Notification List
        ScrollView {
            id: nScroll
            width: parent.width
            // Guarded: a negative height sends Flickable into a silent polish loop
            height: Math.max(0, parent.height - y - 8)
            clip: true

            // Scroll position save/restore across notification changes
            // (AGS NotificationHistory savedScrollPosition + idle_add).
            property real savedPosition: 0
            onContentItemChanged: {
                if (contentItem) contentItem.contentYChanged.connect(function(){
                    nScroll.savedPosition = contentItem.contentY
                })
            }
            onContentHeightChanged: {
                // model updated → restore (clamped) scroll position
                Qt.callLater(function(){
                    const c = nScroll.contentItem
                    if (!c) return
                    const max = Math.max(0, c.contentHeight - nScroll.height)
                    c.contentY = Math.min(nScroll.savedPosition, max)
                })
            }

            Column {
                id: listColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: stackedNotifications
                    delegate: StackItem {
                        width: parent.width
                        stack: modelData
                        expandedStacks: root.expandedStacks
                        onToggleExpanded: {
                            const newStacks = Object.assign({}, root.expandedStacks);
                            newStacks[modelData.title] = !newStacks[modelData.title];
                            root.expandedStacks = newStacks;
                        }
                        onClearStack: {
                            modelData.notifications.forEach(n => n.notif.dismiss());
                        }
                    }
                }
            }
        }
    }
}