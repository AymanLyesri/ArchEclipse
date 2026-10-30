import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.shared
import qs.widgets.media
import qs.widgets.rightPanel

// RightIsland: the former RightPanel body in the right side pill, scoped to its monitor; same
// expand-driver unfold as SearchIsland. The panel lock and a widget drag pin it open.
Item {
    id: root
    width: Settings.panelWidthFor("right", root.monitorName)
    // Explicit full height, NOT implicit: positioner implicit sizes freeze at completion time,
    // so an animated-only height never reached the pill; the Loader measures this one.
    height: bodyHeight

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""

    // Full monitor height from the bar owner: side islands stretch the whole vertical screen
    // like the old edge panels (the pill adds 10px padding, leaving a 5px bottom margin).
    property int screenHeight: 1080

    // Fixed dropdown height: the island is a floating card and the widget stack scrolls
    // internally (like the search island's fixed body height).
    property int bodyHeight: Math.max(400, screenHeight - 15)

    // True while a widget selector is being drag-reordered.
    // The auto-hide timer skips hiding while this is set.
    property bool isDragging: false

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    Component.onCompleted: {
        expand = 1;
        Registry.register(root.registryKey(), root);
        Registry.register("right-island", root);
    }
    onMonitorNameChanged: {
        if (root.monitorName !== "")
            Registry.register(root.registryKey(), root);
    }
    Component.onDestruction: {
        Registry.unregister("right-island");
        Registry.unregister(root.registryKey());
    }
    function registryKey() {
        return `right-island-${root.monitorName || Registry.monitorName}`;
    }

    // Hover tracking lives here (stable container — content never swaps under the cursor).
    // Leaving arms the close timer, which re-checks so a fast flick still closes.
    HoverHandler {
        id: islandHover
        onHoveredChanged: {
            if (islandHover.hovered) {
                leaveTimer.stop();
                // Pin hover-driven islands so a hold expiry can't close
                // the panel while it is being used.
                BarState.activate("right", 0, root.monitorName);
            } else {
                root.requestAutoHide();
            }
        }
    }
    function requestAutoHide() {
        if (BarState.tourHoldFor(root.monitorName))
            return;
        if (Settings.panelLockFor("right", root.monitorName))
            return;
        if (islandHover.hovered)
            return;
        if (root.isDragging)
            return;
        leaveTimer.restart();
    }
    // Called on every (re)open: the island survives closes, so a leaveTimer armed before the
    // last close must not fire into the fresh session. Also clears a mid-drag leftover.
    function cancelPendingHide() {
        leaveTimer.stop();
        root.isDragging = false;
    }
    Timer {
        id: leaveTimer
        interval: Settings.revealOutPressure
        onTriggered: {
            if (!BarState.tourHoldFor(root.monitorName) && !Settings.panelLockFor("right", root.monitorName) && !islandHover.hovered && !root.isDragging)
                BarState.deactivate("right", root.monitorName);
        }
    }

    // Esc dismiss once the surface has focus (click a control first).
    IslandEscClose {
        states: ["right"]
        monitorName: root.monitorName
    }

    IslandExpandClip {
        expand: root.expand
        contentHeight: bodyRow.height
        anchors.top: Settings.barOrientation ? parent.top : undefined
        anchors.bottom: Settings.barOrientation ? undefined : parent.bottom

        Row {
            id: bodyRow
            width: parent.width
            height: root.bodyHeight
            spacing: 0
            // <main-content/> first, <Actions/> last: the sidebar displays
            // on the RIGHT (mirrors the left island's rail).
            layoutDirection: Qt.RightToLeft

            // ----- Sidebar with widget toggles (drag-reorderable) -----
            // Stays custom (not IslandSideRail): live reorder + the isDragging hold need it.
            Rectangle {
                id: sidebar
                width: 48
                height: parent.height
                color: Theme.bg
                // Square on the screen-edge side so the rail runs flush
                // into the panel's edge (mirrors bar orientation).
                topLeftRadius: Settings.barOrientation ? 0 : Theme.radius
                topRightRadius: Settings.barOrientation ? 0 : Theme.radius
                bottomLeftRadius: Settings.barOrientation ? Theme.radius : 0
                bottomRightRadius: Settings.barOrientation ? Theme.radius : 0

                clip: true
                visible: true

                Column {
                    id: selectorColumn
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.pad
                    spacing: Theme.spacing

                    Repeater {
                        id: widgetSelectorRepeater
                        model: Settings.rightPanelWidgets
                        delegate: Item {
                            id: selectorItem
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 40
                            // Set on release after a real drag so the
                            // trailing click doesn't toggle the widget.
                            property bool suppressClick: false
                            // Y at press time: the Column owns the absolute y (index*48), so the
                            // target slot derives from the drag DELTA, not absolute y.
                            property real dragStartY: 0

                            // --- Drag to reorder, resolved on release: live reordering rebuilds
                            // the delegate under the cursor, kills the gesture, strands isDragging ---
                            Drag.active: cellBtn.dragActive
                            Drag.hotSpot: Qt.point(width / 2, height / 2)
                            Drag.source: selectorItem

                            AppButton {
                                id: cellBtn
                                anchors.fill: parent
                                icon: modelData.icon
                                toggle: true
                                checked: modelData.enabled
                                outlined: BarState.tourHighlightMonitor === (root.monitorName || Registry.monitorName) && BarState.tourHighlightTab === modelData.name
                                outlineColor: Theme.accent
                                // Tooltip: "<b>Hold To Drag</b>\n${name}"
                                tooltipText: "Hold To Drag\n" + modelData.name
                                draggable: true
                                dragTarget: selectorItem
                                dragAxis: Drag.YAxis
                                dragMinimum: -selectorItem.index * 48
                                dragMaximum: (Settings.rightPanelWidgets.length - 1 - selectorItem.index) * 48
                                onPressed: {
                                    cellBtn.dragging = true;
                                    root.isDragging = true;
                                    selectorItem.dragStartY = selectorItem.y;
                                }
                                onReleased: {
                                    cellBtn.dragging = false;
                                    root.isDragging = false;
                                    // Release-time reorder: target slot from the dragged offset
                                    // (cell 40 + spacing 8 = 48px pitch), clamped to the list.
                                    const to = Math.max(0, Math.min(Settings.rightPanelWidgets.length - 1, selectorItem.index + Math.round((selectorItem.y - selectorItem.dragStartY) / 48)));
                                    selectorItem.x = 0;
                                    selectorItem.y = 0;
                                    if (to !== selectorItem.index) {
                                        selectorItem.suppressClick = true;
                                        const list = Settings.rightPanelWidgets.slice();
                                        const [item] = list.splice(selectorItem.index, 1);
                                        list.splice(to, 0, item);
                                        Settings.rightPanelWidgets = list;
                                        Settings.updateSetting("rightPanel.widgets", list);
                                    }
                                }
                                onClicked: {
                                    if (selectorItem.suppressClick) {
                                        selectorItem.suppressClick = false;
                                        return;
                                    }
                                    const widgets = Settings.rightPanelWidgets.slice();
                                    const w = widgets[index];
                                    const newWidgets = widgets.map(item => item.name === w.name ? Object.assign({}, item, {
                                            enabled: !item.enabled
                                        }) : item);
                                    Settings.rightPanelWidgets = newWidgets;
                                    Settings.updateSetting("rightPanel.widgets", newWidgets);
                                }
                            }
                        }
                    }
                }

                // Window Actions: bottom cluster (valign END, shared).
                IslandWindowActions {
                    side: "right"
                    monitorName: root.monitorName
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.pad
                }
            }

            // ----- Main content area — all enabled widgets -----
            SmoothFlickable {
                id: contentScroll
                width: parent.width - sidebar.width
                height: parent.height
                clip: true
                contentWidth: width
                contentHeight: contentColumn.height
                flickableDirection: Flickable.VerticalFlick
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

                Column {
                    id: contentColumn
                    // Width MUST come from the Flickable's explicit width, never parent.width:
                    // the viewport negotiates with content and wedges a silent polish loop.
                    width: contentScroll.width
                    spacing: Theme.spacing
                    padding: Theme.pad

                    Repeater {
                        id: enabledWidgetRepeater
                        model: {
                            // Filter to only enabled widgets, preserving order
                            const capture = Registry.get("capture-session");
                            const widgets = capture && capture.active && capture.monitor === root.monitorName && capture.rightWidgets
                                ? capture.rightWidgets : Settings.rightPanelWidgets;
                            const monitorName = root.monitorName || Registry.monitorName;
                            const tourWidget = BarState.tourHighlightMonitor === monitorName ? BarState.tourRightWidget : "";
                            if (tourWidget !== "") {
                                const selected = widgets.find(widget => widget.name === tourWidget);
                                return selected ? [selected] : [];
                            }
                            const result = [];
                            for (let i = 0; i < widgets.length; i++) {
                                if (widgets[i].enabled) {
                                    result.push(widgets[i]);
                                }
                            }
                            return result;
                        }

                        delegate: Item {
                            required property var modelData
                            readonly property bool isBare: modelData.name === "Media" || modelData.name === "Waifu"
                            // Fill the padded area, not the full Column width: parent.width here
                            // overshoots the viewport by the padding and clip cuts the right edge.
                            width: contentColumn.width - contentColumn.leftPadding - contentColumn.rightPadding
                            // Fade-in on show.
                            opacity: 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim.large
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Component.onCompleted: opacity = 1
                            // Fixed per-widget card heights (internal scroll), kept in sync with each
                            // widget's content; each owns its 8px padding, Media/Waifu size to content.
                            height: {
                                switch (modelData.name) {
                                case "Waifu":
                                    {
                                        // Embedded BooruDialog: follow its measured content
                                        // height (Media-case pattern), with a placeholder fallback.
                                        const measured = widgetLoader.item ? widgetLoader.item.implicitHeight : 0;
                                        if (measured > 0)
                                            return measured;
                                        return 190;
                                    }
                                case "Media":
                                    {
                                        // Dynamic like NotificationHistory: follow implicitHeight
                                        // (250 with lyrics, 170 without) — a fixed guess clipped rows.
                                        const measured = widgetLoader.item ? widgetLoader.item.implicitHeight : 0;
                                        if (measured > 0)
                                            return measured;
                                        return 250;
                                    }
                                case "NotificationHistory":
                                    {
                                        // Dynamic: follow the measured content height (header + list,
                                        // capped internally); per-notification guesses clipped tall cards.
                                        const measured = widgetLoader.item ? widgetLoader.item.implicitHeight : 0;
                                        if (measured > 0)
                                            return Math.min(520, Math.max(150, measured + 16));
                                        const n = Notifications.history ? Notifications.history.length : 0;
                                        if (n === 0)
                                            return 150;
                                        return Math.min(520, 150 + n * 110);
                                    }
                                case "Calendar":
                                    return 330;
                                case "SystemResources":
                                    {
                                        // Shared SystemResourcesContent stacks vertically on narrow
                                        // panels, so measure instead of fixing a height.
                                        const measured = widgetLoader.item ? widgetLoader.item.implicitHeight : 0;
                                        if (measured > 0)
                                            return Math.min(700, Math.max(200, measured + 16));
                                        return 300;
                                    }
                                default:
                                    return 300;
                                }
                            }
                            // Flat card. Media/Waifu render as-is
                            // with no outer card container.
                            Rectangle {
                                id: cardBg
                                anchors.fill: parent
                                visible: !isBare

                                color: Theme.surface
                                radius: Theme.radius
                            }

                            Loader {
                                id: widgetLoader
                                // No inset here: each widget pads itself so content never paints over
                                // the card border; Media/Waifu fill the delegate with no card.
                                anchors.fill: parent
                                sourceComponent: {
                                    switch (modelData.name) {
                                    case "Waifu":
                                        return waifuWidget;
                                    case "Media":
                                        return mediaWidget;
                                    case "NotificationHistory":
                                        return notificationHistoryWidget;
                                    case "Calendar":
                                        return calendarWidget;
                                    case "SystemResources":
                                        return systemResourcesWidget;
                                    default:
                                        return undefinedComponent;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Widget component definitions
        Component {
            id: undefinedComponent
            Text {
                text: "Unknown widget"
            }
        }
        Component {
            id: calendarWidget
            CalendarWidget {}
        }
        Component {
            id: mediaWidget
            MediaWidget {}
        }
        Component {
            id: notificationHistoryWidget
            NotificationHistoryWidget {}
        }
        Component {
            id: systemResourcesWidget
            SystemResourcesWidget {}
        }
        Component {
            id: waifuWidget
            WaifuWidget {
                monitorName: root.monitorName
            }
        }
    }
}
