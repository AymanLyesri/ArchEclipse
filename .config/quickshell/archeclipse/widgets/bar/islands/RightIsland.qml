import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.shared
import qs.widgets.media
import qs.widgets.rightPanel

// RightIsland: the former RightPanel body (widget stack + toggle sidebar)
// living INSIDE the bar pill as a Dynamic-Island state (BarState "right").
//
// Same spring-unfold pattern as Search/ControlIsland — the pill grows
// (width via the pill spring, height snapped on the window) while this
// body unfolds via the expand driver (clip + opacity + scale only, so no
// expensive layout animates per-frame).
//
// Open: SUPER+R bind, right HotZone hover, IPC.
// Close: bind toggle, Esc, close button, or 1s after the cursor leaves
// (Settings.rightPanelLock pins it open; an active widget-selector drag
// also holds it open, matching the old panel).
Column {
    id: root
    width: Settings.rightPanelWidth
    // Explicit full height (NOT implicit): positioner implicit sizes freeze
    // at completion-time values in this engine, so a height driven only by
    // the expand animation would never reach the pill — the Loader measures
    // this explicit height and the pill snaps to it, exactly like the
    // static DefaultBar/PlayerIsland pages. The expand driver below still
    // unfolds the content inside the snapped pill (clip + opacity + scale).
    height: bodyHeight
    spacing: 0

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""

    // Full monitor height, passed by the bar owner. Side islands stretch
    // the whole vertical screen like the old edge panels did (the pill
    // adds its 10px padding, leaving a 5px bottom margin).
    property int screenHeight: 1080

    // Fixed dropdown height (the old panel stretched full monitor height;
    // the island is a floating card — the widget stack scrolls internally,
    // same as the search island's fixed body height).
    property int bodyHeight: Math.max(400, screenHeight - 15)

    // True while a widget selector is being drag-reordered.
    // The auto-hide timer skips hiding while this is set.
    property bool isDragging: false

    // Spring driver: 0 -> 1 on creation unfolds the body.
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
        Registry.unregister(root.registryKey());
        Registry.unregister("right-island");
    }
    function registryKey() {
        return `right-island-${root.monitorName || Registry.monitorName}`;
    }

    Behavior on expand {
        SpringAnimation {
            spring: 3.5
            damping: 0.32
            mass: 1.0
        }
    }

    // Hover tracking lives here (stable container — content never swaps
    // under the cursor while open). Leaving arms the close timer; the
    // timer re-checks so a fast flick across still closes.
    HoverHandler {
        id: islandHover
        onHoveredChanged: {
            if (islandHover.hovered) {
                leaveTimer.stop();
                // Pin hover-driven islands so a hold expiry can't close
                // the panel while it is being used.
                BarState.activate("right", 0);
            } else {
                root.requestAutoHide();
            }
        }
    }
    function requestAutoHide() {
        if (Settings.rightPanelLock)
            return;
        if (islandHover.hovered)
            return;
        if (root.isDragging)
            return;
        leaveTimer.restart();
    }
    // Called by the bar owner on every (re)open: the island now survives
    // closes, so a leaveTimer armed before the last close must not fire
    // into the fresh session. Also clears a mid-drag close leftover that
    // would otherwise pin the island open (autohide skips while dragging).
    function cancelPendingHide() {
        leaveTimer.stop();
        root.isDragging = false;
    }
    Timer {
        id: leaveTimer
        interval: 1000
        onTriggered: {
            if (!Settings.rightPanelLock && !islandHover.hovered && !root.isDragging)
                BarState.deactivate("right");
        }
    }

    // Esc dismiss once the surface has focus (click a control first).
    Item {
        id: escGrab
        width: 1
        height: 1
        focus: true
        Keys.onEscapePressed: BarState.deactivate("right")
    }

    Item {
        id: bodyClip
        width: parent.width
        height: Math.max(0, root.expand * bodyRow.height)
        clip: true
        opacity: Math.max(0, Math.min(1, root.expand * 1.2))
        scale: 0.96 + 0.04 * root.expand
        transformOrigin: Item.Top

        Row {
            id: bodyRow
            width: parent.width
            height: root.bodyHeight
            spacing: 0
            // <main-content/> first, <Actions/> last: the sidebar displays
            // on the RIGHT (mirrors the left island's rail).
            layoutDirection: Qt.RightToLeft

            // ----- Sidebar with widget toggles (drag-reorderable) -----
            Rectangle {
                id: sidebar
                width: 48
                height: parent.height
                color: Theme.bg
                radius: Theme.radius

                clip: true
                visible: true

                Column {
                    id: selectorColumn
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    spacing: 8

                    Repeater {
                        id: widgetSelectorRepeater
                        model: Settings.rightPanelWidgets
                        delegate: Item {
                            id: selectorItem
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 40

                            // --- Drag to reorder ---
                            Drag.active: cellBtn.dragActive
                            Drag.hotSpot: Qt.point(width / 2, height / 2)
                            Drag.source: selectorItem
                            Drag.mimeData: {
                                "text/plain": String(index)
                            }

                            AppButton {
                                id: cellBtn
                                anchors.fill: parent
                                icon: modelData.icon
                                toggle: true
                                checked: modelData.enabled
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
                                }
                                onReleased: {
                                    cellBtn.dragging = false;
                                    root.isDragging = false;
                                    selectorItem.x = 0;
                                    selectorItem.y = 0;
                                }
                                onClicked: {
                                    const widgets = Settings.rightPanelWidgets.slice();
                                    const w = widgets[index];
                                    const newWidgets = widgets.map(item => item.name === w.name ? Object.assign({}, item, {
                                            enabled: !item.enabled
                                        }) : item);
                                    Settings.rightPanelWidgets = newWidgets;
                                    Settings.updateSetting("rightPanel.widgets", newWidgets);
                                }

                                DropArea {
                                    id: dropArea
                                    anchors.fill: parent
                                    onEntered: {
                                        const list = Settings.rightPanelWidgets.slice();
                                        const from = Number(drag.source.index);
                                        const to = selectorItem.index;
                                        if (from === to || !list[from])
                                            return;
                                        const [item] = list.splice(from, 1);
                                        list.splice(to, 0, item);
                                        Settings.rightPanelWidgets = list;
                                        Settings.updateSetting("rightPanel.widgets", list);
                                    }
                                }
                            }
                        }
                    }
                }

                // ----- Window Actions (valign END) -----
                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    width: parent.width
                    spacing: 5

                    // Expand (+50 to max 1500)
                    AppButton {
                        width: parent.width
                        icon: ""
                        pixelSize: 14
                        cornerRadius: 6
                        hoverBg: Theme.surface
                        hoverFg: Theme.accent
                        tooltipText: "Expand island"
                        onClicked: {
                            const w = Settings.rightPanelWidth;
                            Settings.rightPanelWidth = w < 1500 ? w + 50 : 1500;
                        }
                    }
                    // Shrink (-50 to min 250)
                    AppButton {
                        width: parent.width
                        icon: ""
                        pixelSize: 14
                        cornerRadius: 6
                        hoverBg: Theme.surface
                        hoverFg: Theme.accent
                        tooltipText: "Shrink island"
                        onClicked: {
                            const w = Settings.rightPanelWidth;
                            Settings.rightPanelWidth = w > 250 ? w - 50 : 250;
                        }
                    }
                    // Exclusivity (active = non-exclusive, inverted) —
                    // reserves the island's width from the docked screen
                    // edge while open (vertical zone; the bar's top strip
                    // reservation is replaced, not added).
                    AppButton {
                        width: parent.width
                        icon: ""
                        pixelSize: 14
                        cornerRadius: 6
                        toggle: true
                        checked: !Settings.rightPanelExclusivity
                        hoverBg: Theme.surface
                        tooltipText: Settings.rightPanelExclusivity ? "Exclusive zone: on" : "Exclusive zone: off"
                        // checked is the inverse of the setting: writing it
                        // back as-is toggles exclusivity.
                        onClicked: Settings.rightPanelExclusivity = checked
                    }
                    // Lock — pins the island open across hover-leave.
                    AppButton {
                        width: parent.width
                        icon: Settings.rightPanelLock ? "" : ""
                        pixelSize: 14
                        cornerRadius: 6
                        toggle: true
                        checked: Settings.rightPanelLock
                        hoverBg: Theme.surface
                        tooltipText: Settings.rightPanelLock ? "Unlock island" : "Lock island"
                        onClicked: Settings.rightPanelLock = !checked
                    }
                    // Close
                    AppButton {
                        width: parent.width
                        icon: ""
                        pixelSize: 14
                        cornerRadius: 6
                        hoverBg: Theme.surface
                        hoverFg: Theme.danger
                        tooltipText: "Close island"
                        onClicked: BarState.deactivate("right")
                    }
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
                    // Width MUST come from the Flickable's explicit width, never
                    // the viewport (parent.width): the viewport width negotiates
                    // with content size, which feeds back through delegates and
                    // wedges the scene in a silent polish loop (0-width freeze).
                    width: contentScroll.width
                    spacing: 8
                    padding: 4

                    Repeater {
                        id: enabledWidgetRepeater
                        model: {
                            // Filter to only enabled widgets, preserving order
                            const widgets = Settings.rightPanelWidgets;
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
                            // Fill the padded area, not the full Column width:
                            // width: parent.width here overshoots the viewport
                            // by leftPadding+rightPadding and clip cuts the
                            // right edge off every card.
                            width: contentColumn.width - contentColumn.leftPadding - contentColumn.rightPadding
                            // Fade-in on show.
                            opacity: 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 600
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Component.onCompleted: opacity = 1
                            // Panel-card heights per widget (fixed heights
                            // with internal scroll).
                            // Heights must stay in sync with each widget's content.
                            // Each widget owns its inner padding (8px per side);
                            // Media/Waifu have no outer card and size to content.
                            height: {
                                switch (modelData.name) {
                                case "Waifu":
                                    {
                                        const wd = Settings.waifu;
                                        if (!wd || !wd.id)
                                            return 200;
                                        // Same base as WaifuWidget.mediaHeight
                                        // (no outside container: full width).
                                        const w = width;
                                        const a = (wd.width > 0 && wd.height > 0) ? wd.width / wd.height : 1.0;
                                        const h = Math.min(Math.max(w / a, 120), 520);
                                        // Overlay layout: actions float on top of
                                        // the image, so the card is just the media.
                                        return h;
                                    }
                                case "Media":
                                    return 170;
                                case "NotificationHistory":
                                    {
                                        // Dynamic: follow the widget's measured
                                        // content height (header + real list
                                        // height capped internally + filter)
                                        // instead of guessing per-notification
                                        // pixels, which clipped tall cards.
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
                                        // Shared SystemResourcesContent stacks
                                        // vertically on narrow panels, so measure
                                        // instead of using a fixed height.
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
                                // No inset here: each widget sets its own inner
                                // padding so content never paints over the card
                                // border. Media/Waifu fill the delegate with no card.
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
            CalendarWidget {
                Layout.fillWidth: true
            }
        }
        Component {
            id: mediaWidget
            MediaWidget {
                Layout.fillWidth: true
            }
        }
        Component {
            id: notificationHistoryWidget
            NotificationHistoryWidget {
                Layout.fillWidth: true
            }
        }
        Component {
            id: systemResourcesWidget
            SystemResourcesWidget {
                Layout.fillWidth: true
            }
        }
        Component {
            id: waifuWidget
            WaifuWidget {
                Layout.fillWidth: true
            }
        }
    }
}
