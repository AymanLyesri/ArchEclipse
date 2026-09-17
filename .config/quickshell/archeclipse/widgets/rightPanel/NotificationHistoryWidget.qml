import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.theme
import qs.widgets.shared

// Notification History widget ported from widgets/rightPanel/components/NotificationHistory.tsx
// Flat newest-first list where every row is the same card as the
// NotificationPopups popups (see ../notifications/NotificationPopups.qml
// and NotificationItem.qml): left-click a card copies its content,
// right-click dismisses (removes) it.
Item {
    id: root

    // Retained history (NOT the ephemeral toasts): entries survive popup
    // expiry exactly like binding the daemon's notification list.
    // Entry shape: {id, time (epoch s), notif (live NotificationObject)}.
    property var notifications: Notifications.history
    property string filterText: ""

    Connections {
        target: Notifications
        function onHistoryChanged() {
            // New arrival while pinned at the top: re-pin after polish so
            // the newest (first) notification is fully visible instead of
            // sitting half-clipped above the viewport.
            const wasTop = nScroll.contentY <= 1;
            root.notifications = Notifications.history;
            if (wasTop) {
                Qt.callLater(function () {
                    nScroll.contentY = 0;
                    nScroll.savedPosition = 0;
                });
            }
        }
    }

    // Newest-first, capped, filtered across app name + summary + body
    // (description), case-insensitive. The daemon already caps history at
    // maxHistory (dismissing overflow), so this only slices for display.
    function filteredList(notifications, filter) {
        const MAX_NOTIFICATIONS = 50;
        const sorted = [...notifications].sort((a, b) => b.time - a.time);
        const q = (filter || "").toLowerCase();
        if (q === "")
            return sorted.slice(0, MAX_NOTIFICATIONS);
        return sorted.filter(n => {
            const appName = ((n.notif && n.notif.appName) || "").toString().toLowerCase();
            const summary = ((n.notif && n.notif.summary) || "").toString().toLowerCase();
            const body = ((n.notif && n.notif.body) || "").toString().toLowerCase();
            return appName.includes(q) || summary.includes(q) || body.includes(q);
        }).slice(0, MAX_NOTIFICATIONS);
    }

    property var visibleNotifications: filteredList(notifications, filterText)

    // Natural height for embedders (right island card): header + filter +
    // list (capped — internal scroll takes over past the cap) + empty hint
    // + spacing/margins. The list measures real delegate heights instead
    // of guessing per-notification pixels.
    readonly property real maxListH: 380
    readonly property real listH: visibleNotifications.length === 0 ? 0 : Math.min(listColumn.height, maxListH)
    // Never bind Text.height to implicitHeight (WordWrap loops). Column
    // already skips invisible children; only count the hint when shown.
    readonly property real emptyHintH: visibleNotifications.length === 0 ? emptyHint.implicitHeight : 0
    implicitHeight: headerRow.implicitHeight + filterField.implicitHeight + listH + emptyHintH + mainCol.spacing * 3 + 16

    Column {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header: title + match count + clear-all.
        RowLayout {
            id: headerRow
            width: parent.width
            spacing: 6

            Label {
                text: "Notification History"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "(" + visibleNotifications.length + ")"
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
                visible: visibleNotifications.length > 0
            }

            AppButton {
                icon: ""
                pixelSize: Theme.fontSize - 2
                cornerRadius: 4
                tooltipText: "Clear all"
                visible: notifications.length > 0
                onClicked: Notifications.clearHistory()
            }
        }

        // Filter lives at the top so it reads before the list it filters.
        // Matches the app name, the summary title, and the body text.
        AppTextField {
            id: filterField
            width: parent.width
            placeholderText: "Filter by name or text..."
            text: root.filterText
            onTextChanged: root.filterText = text
        }

        // Notification List — fills the leftover card space (same pattern
        // as Crypto/ScriptTimer: height from parent remainder, NOT from the
        // measured content). Sizing the viewport from content height while
        // the outer card sizes itself from our implicitHeight clipped the
        // first delegate and could push content out of the card.
        SmoothFlickable {
            id: nScroll
            width: parent.width
            // Guarded: a negative height sends Flickable into a silent polish loop
            height: visibleNotifications.length === 0 ? 0 : Math.max(0, parent.height - y - 8)
            visible: visibleNotifications.length > 0
            clip: true
            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: listColumn.height
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            // Scroll position save/restore across notification changes
            // (saved scroll position, restored on idle).
            property real savedPosition: 0
            onContentYChanged: {
                nScroll.savedPosition = contentY;
            }
            onContentHeightChanged: {
                // model updated → restore (clamped) scroll position
                Qt.callLater(function () {
                    const max = Math.max(0, nScroll.contentHeight - nScroll.height);
                    nScroll.contentY = Math.min(nScroll.savedPosition, max);
                });
            }

            Column {
                id: listColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: visibleNotifications
                    delegate: NotificationItem {
                        width: parent.width
                        entry: modelData
                    }
                }
            }
        }

        // Empty state — small fixed hint, no blank scroll area.
        Text {
            id: emptyHint
            width: parent.width
            visible: visibleNotifications.length === 0
            text: filterText !== "" ? "No matching notifications" : "No notifications"
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
