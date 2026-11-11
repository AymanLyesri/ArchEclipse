import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.theme
import qs.widgets.notifications
import qs.widgets.shared

// Notification history: newest-first cards grouped by day, so a long backlog reads as a
// timeline instead of one undifferentiated stack. Left-click copies, right-click dismisses.
Item {
    id: root

    // Retained history (NOT the ephemeral toasts): entries survive popup expiry, shaped
    // {id, time (epoch s), notif (live NotificationObject)}.
    property var notifications: Notifications.history
    property string filterText: ""

    Connections {
        target: Notifications
        function onHistoryChanged() {
            // New arrival while pinned at the top: re-pin after polish so the newest card is fully
            // visible instead of half-clipped above the viewport.
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

    // Newest-first, capped, filtered across app name + summary + body, case-insensitive. The
    // daemon already caps history, so this only slices for display.
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

    // ---- timeline rows: one day header before each day's cards ----
    function dayStart(t) {
        const d = new Date(t * 1000);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    }

    function dayLabel(t) {
        const today = root.dayStart(Date.now() / 1000);
        const d = root.dayStart(t);
        if (d === today)
            return "Today";
        if (d === today - 86400000)
            return "Yesterday";
        return new Date(t * 1000).toLocaleDateString([], {
            weekday: "short",
            day: "numeric",
            month: "short"
        });
    }

    function buildRows(list) {
        const rows = [];
        let lastDay = -1;
        for (let i = 0; i < list.length; i++) {
            const entry = list[i];
            const d = root.dayStart(entry.time || 0);
            if (d !== lastDay) {
                lastDay = d;
                rows.push({
                    kind: "day",
                    label: root.dayLabel(entry.time || 0)
                });
            }
            rows.push({
                kind: "item",
                entry: entry
            });
        }
        return rows;
    }

    property var rows: buildRows(visibleNotifications)
    readonly property int todayCount: visibleNotifications.filter(n => root.dayStart(n.time || 0) === root.dayStart(Date.now() / 1000)).length

    // Natural height for embedders: header + list (capped, internal scroll) + hint. The list
    // measures real delegate heights instead of guessing per-notification pixels.
    readonly property real maxListH: 380
    readonly property real listH: visibleNotifications.length === 0 ? 0 : Math.min(listColumn.height, maxListH)
    // Never bind Text.height to implicitHeight (WordWrap loops). Column
    // already skips invisible children; only count the hint when shown.
    readonly property real emptyHintH: visibleNotifications.length === 0 ? emptyHint.implicitHeight : 0
    implicitHeight: headerRow.implicitHeight + listH + emptyHintH + mainCol.spacing * 2 + Theme.pad * 2

    Column {
        id: mainCol
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.spaceMd

        // Header owns identity, the live count and the one destructive action. The filter is a
        // compact field on the same band, so the list starts one row higher than before.
        Column {
            id: headerRow
            width: parent.width
            spacing: Theme.spaceSm

            RowLayout {
                width: parent.width
                spacing: Theme.spacing

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Notifications"
                        font.pixelSize: Theme.typeSubtitle
                        font.weight: Font.DemiBold
                        color: Theme.fg
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: root.visibleNotifications.length === 0 ? "Nothing new" : (root.todayCount > 0 ? root.todayCount + " today · " + root.visibleNotifications.length + " total" : root.visibleNotifications.length + " in history")
                        font.pixelSize: Theme.typeCaption
                        color: Theme.muted
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                AppButton {
                    icon: Icons.trashOutline
                    pixelSize: Theme.typeLabel
                    cornerRadius: Theme.radius
                    hPadding: 8
                    tooltipText: "Clear all"
                    visible: root.notifications.length > 0
                    onClicked: Notifications.clearHistory()
                }
            }

            AppTextField {
                id: filterField
                width: parent.width
                placeholderText: "Filter by name or text..."
                text: root.filterText
                onTextChanged: root.filterText = text
            }
        }

        // The list fills the leftover card space, never sizing from content: that clipped the
        // first delegate and could push content out of the card.
        SmoothFlickable {
            id: nScroll
            width: parent.width
            // Guarded: a negative height sends Flickable into a silent polish loop
            height: visibleNotifications.length === 0 ? 0 : Math.max(0, parent.height - y - Theme.spaceSm)
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
                spacing: Theme.spaceSm

                Repeater {
                    model: root.rows
                    delegate: Item {
                        id: rowItem
                        required property var modelData
                        readonly property bool isDay: modelData.kind === "day"
                        width: listColumn.width
                        height: isDay ? dayLabelText.implicitHeight + Theme.spaceXs : cardItem.height

                        // Day header: a quiet label plus the count, no rule underneath.
                        Text {
                            id: dayLabelText
                            visible: rowItem.isDay
                            text: rowItem.modelData.label || ""
                            color: Theme.muted
                            font.pixelSize: Theme.typeCaption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                            font.capitalization: Font.AllUppercase
                            topPadding: Theme.spaceXs
                        }

                        NotificationItem {
                            id: cardItem
                            visible: !rowItem.isDay
                            width: parent.width
                            entry: rowItem.isDay ? null : (rowItem.modelData.entry || null)
                        }
                    }
                }
            }
        }

        // Empty state — small fixed hint, no blank scroll area.
        Text {
            id: emptyHint
            width: parent.width
            visible: visibleNotifications.length === 0
            text: filterText !== "" ? "No matching notifications" : "You are all caught up"
            font.pixelSize: Theme.typeLabel
            color: Theme.muted
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
