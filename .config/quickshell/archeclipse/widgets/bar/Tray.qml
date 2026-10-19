import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.theme
import qs.services
import qs.widgets.shared

// Tray widget implementation: first 3 items are shown inline,
// hidden items are accessible via an overflow popup ("more" icon, MAX_VISIBLE=3).
//
// Drag & Drop behavior:
//   * Between bar icons -> reorders items.
//   * Onto the "..." button or open overflow popup -> moves item to the hidden list.
//   * From overflow popup into the bar -> makes the item visible in the bar.
// Saved configuration path: ~/.cache/quickshell/settings/tray-order.json
Row {
    id: root
    spacing: 2
    property string monitorName: ""

    // Maximum number of visible icons in the bar strip
    readonly property int maxVisible: 3

    // Persistence configuration
    property var order: []
    readonly property string orderPath: `${Quickshell.env("HOME")}/.cache/quickshell/settings/tray-order.json`

    // File view to read and write the persisted tray item order
    property FileView _orderFile: FileView {
        path: root.orderPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsedData = JSON.parse(text());
                if (Array.isArray(parsedData))
                    root.order = parsedData.map(String);
            } catch (e) {
                // Ignore parsing errors on malformed JSON
            }
        }
    }

    // Generate a unique identifier key for a tray item
    function keyOf(item) {
        return String((item && (item.id || item.title)) || "");
    }

    // Computed property: returns items sorted according to the user's saved order
    readonly property var ordered: {
        const sourceItems = SystemTray.items.values.slice();
        const savedOrder = root.order;
        const getRank = item => {
            const index = savedOrder.indexOf(root.keyOf(item));
            return index < 0 ? 1e9 : index;
        };
        return sourceItems.map((item, index) => ({
            it: item,
            i: index,
            r: getRank(item)
        })).sort((a, b) => a.r !== b.r ? a.r - b.r : a.i - b.i).map(entry => entry.it);
    }

    // Save the updated tray order to disk
    function saveOrder(list) {
        const keys = list.map(root.keyOf);
        const absentKeys = root.order.filter(k => keys.indexOf(k) < 0);
        const allKeys = keys.concat(absentKeys);
        root.order = allKeys;
        root._orderFile.setText(JSON.stringify(allKeys));
    }

    // Register popup items with the bar window input mask to prevent click-through issues
    function setPopupMask(item) {
        const window = QsWindow.window;
        if (window && window.trayPopupItem !== undefined)
            window.trayPopupItem = item;
    }

    // Drag & Drop internal state
    property var dragItem: null
    property bool dragActive: false
    property bool dragClickGuard: false
    property bool dragHeld: false
    property real dragPressX: 0
    property real dragPressY: 0
    property int dropIndex: -1
    property string dropZone: ""
    property var _ghost: null
    property var _line: null
    property double popupClosedAt: 0

    // Timer to automatically open the overflow popup when hovering over the "..." button during drag
    Timer {
        id: openOverflowTimer
        interval: 300
        onTriggered: {
            if (root.dropZone === "overflowBtn" && !overflowPopup.opened) {
                overflowPopup.open();
            }
        }
    }

    // Component for the floating drag ghost icon
    Component {
        id: ghostComp
        Item {
            id: ghost
            width: 20
            height: 20
            z: 1000
            opacity: Theme.opacity.soft
            property var icon: ""
            IconImage {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: ghost.icon
            }
        }
    }

    // Component for the insertion indicator line
    Component {
        id: lineComp
        Rectangle {
            z: 999
            width: 2
            radius: 1
            color: Theme.accent
            visible: false
        }
    }

    // Helper functions for spatial bounding calculations
    function sceneRect(item) {
        const pos = item.mapToItem(null, 0, 0);
        return {
            x: pos.x,
            y: pos.y,
            w: item.width,
            h: item.height
        };
    }

    function inRect(rect, x, y, padding) {
        return x >= rect.x - padding &&
               x <= rect.x + rect.w + padding &&
               y >= rect.y - padding &&
               y <= rect.y + rect.h + padding;
    }

    // Handle drag initiation on mouse press
    function dragPress(item, area, mouse) {
        if (mouse.button !== Qt.LeftButton)
            return;
        const pos = area.mapToItem(null, mouse.x, mouse.y);
        root.dragItem = item;
        root.dragPressX = pos.x;
        root.dragPressY = pos.y;
        root.dragActive = false;
    }

    // Handle drag movement and ghost positioning
    function dragMove(area, mouse) {
        if (!root.dragItem)
            return;
        const pos = area.mapToItem(null, mouse.x, mouse.y);
        
        if (!root.dragActive) {
            if (Math.abs(pos.x - root.dragPressX) < 8 && Math.abs(pos.y - root.dragPressY) < 8)
                return;
            root.dragActive = true;
            if (!root.dragHeld) {
                root.dragHeld = true;
                BarState.holdPopup(root.monitorName);
            }
            
            const overlay = Overlay.overlay;
            if (overlay) {
                root._ghost = ghostComp.createObject(overlay, {
                    icon: root.dragItem.icon
                });
                root._line = lineComp.createObject(overlay);
            }
        }

        if (root._ghost) {
            root._ghost.x = pos.x - 10;
            root._ghost.y = pos.y - 10;
        }
        
        root.updateDrop(pos.x, pos.y);
    }

    // Calculate target drop index and active drop zone based on cursor coordinates
    function updateDrop(x, y) {
        const list = root.ordered;
        const totalCount = list.length;
        const maxVis = root.maxVisible;
        const fromIndex = list.indexOf(root.dragItem);
        
        let zone = "";
        let idx = -1;
        let lineX = 0, lineY = 0, lineH = 0;

        // 1) Check drop interaction inside the open overflow popup
        if (overflowPopup.opened && overflowPopup.background && root.inRect(root.sceneRect(overflowPopup.background), x, y, 4)) {
            let targetCell = popupRep.count;
            for (let k = 0; k < popupRep.count; k++) {
                const delegateItem = popupRep.itemAt(k);
                if (!delegateItem)
                    continue;
                const center = delegateItem.mapToItem(null, delegateItem.width / 2, delegateItem.height / 2);
                const rowTop = center.y - delegateItem.height / 2;
                if (y < rowTop || (y < rowTop + delegateItem.height && x < center.x)) {
                    targetCell = k;
                    break;
                }
            }
            
            if (fromIndex >= maxVis) {
                const calculatedSlot = maxVis + targetCell;
                idx = calculatedSlot > fromIndex ? calculatedSlot - 1 : calculatedSlot;
            } else {
                idx = maxVis + Math.max(0, targetCell - 1);
            }
            idx = Math.min(idx, totalCount - 1);
            zone = "popup";
        } 
        // 2) Check drop interaction over the overflow button ("...")
        else if (overflow.visible && root.inRect(root.sceneRect(overflow), x, y, 2)) {
            zone = "overflowBtn";
            idx = fromIndex < maxVis ? Math.min(maxVis, totalCount - 1) : -1;
            if (!overflowPopup.opened && !openOverflowTimer.running) {
                openOverflowTimer.restart();
            }
        } 
        // 3) Check drop interaction between items in the main bar strip
        else if (root.inRect(root.sceneRect(root), x, y, 6)) {
            let slot = 0;
            for (let k = 0; k < inlineRep.count; k++) {
                const delegateItem = inlineRep.itemAt(k);
                if (delegateItem && delegateItem.mapToItem(null, delegateItem.width / 2, 0).x < x)
                    slot++;
            }
            
            if (fromIndex < maxVis)
                idx = slot > fromIndex ? slot - 1 : slot;
            else
                idx = Math.min(slot, maxVis - 1);
                
            zone = "bar";
            if (inlineRep.count > 0) {
                const referenceItem = inlineRep.itemAt(Math.min(slot, inlineRep.count - 1));
                if (referenceItem) {
                    const rect = root.sceneRect(referenceItem);
                    lineX = (slot < inlineRep.count ? rect.x : rect.x + rect.w) - 1;
                    lineY = rect.y;
                    lineH = rect.h;
                }
            }
        }

        if (zone !== "overflowBtn") {
            openOverflowTimer.stop();
        }

        root.dropZone = zone;
        root.dropIndex = idx;
        if (root._line) {
            root._line.visible = zone === "bar" && idx >= 0;
            root._line.x = lineX;
            root._line.y = lineY;
            root._line.height = lineH;
        }
    }

    // Finalize or cancel the drag operation
    function dragFinish(commit) {
        const wasActive = root.dragActive;
        const item = root.dragItem;
        const idx = root.dropIndex;
        
        openOverflowTimer.stop();

        if (wasActive && commit && item && idx >= 0) {
            const list = root.ordered.slice();
            const fromIndex = list.indexOf(item);
            if (fromIndex >= 0 && idx !== fromIndex) {
                list.splice(fromIndex, 1);
                list.splice(idx, 0, item);
                root.saveOrder(list);
            }
        }

        if (root._ghost) {
            root._ghost.destroy();
            root._ghost = null;
        }
        if (root._line) {
            root._line.destroy();
            root._line = null;
        }

        root.dragItem = null;
        root.dragActive = false;
        root.dropIndex = -1;
        root.dropZone = "";

        if (root.dragHeld) {
            root.dragHeld = false;
            BarState.releasePopup(root.monitorName);
        }

        if (wasActive) {
            root.dragClickGuard = true;
            Qt.callLater(() => {
                root.dragClickGuard = false;
            });
        }
    }

    // Repeater for visible bar items
    Repeater {
        id: inlineRep
        model: root.ordered.slice(0, root.maxVisible)

        Item {
            id: entry
            required property var modelData
            width: 20
            height: Theme.barContentHeight

            Component.onDestruction: {
                if (root.dragItem === entry.modelData)
                    root.dragFinish(false);
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: inlineHover.hovered ? Theme.surfaceHover : "transparent"
            }

            IconImage {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: entry.modelData.icon
                asynchronous: true
                opacity: (root.dragActive && root.dragItem === entry.modelData) ? 0.3 : 1
            }

            MouseArea {
                id: inlineMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: root.dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                onPressed: mouse => root.dragPress(entry.modelData, inlineMouse, mouse)
                onPositionChanged: mouse => root.dragMove(inlineMouse, mouse)
                onReleased: root.dragFinish(true)
                onCanceled: root.dragFinish(false)
                onClicked: mouse => {
                    if (root.dragClickGuard)
                        return;
                    if (mouse.button === Qt.LeftButton)
                        entry.modelData.activate();
                    else if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate?.();
                    else if (entry.modelData.hasMenu)
                        menu.open();
                }
                onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y > 0, false)
            }

            HoverHandler {
                id: inlineHover
                cursorShape: Qt.ArrowCursor
            }

            AppTooltip {
                visible: inlineHover.hovered && !root.dragActive && text.length > 0
                text: {
                    const item = entry.modelData;
                    return (item.tooltipTitle || item.title || item.tooltipDescription || "").trim();
                }
            }

            QsMenuAnchor {
                id: menu
                menu: entry.modelData.menu
                anchor.item: entry
                anchor.edges: Edges.Bottom
                property bool held: false
                Component.onDestruction: {
                    if (held)
                        BarState.releasePopup(root.monitorName);
                }
            }

            Connections {
                target: menu
                function onVisibleChanged() {
                    if (menu.visible && !menu.held) {
                        menu.held = true;
                        BarState.holdPopup(root.monitorName);
                    } else if (!menu.visible && menu.held) {
                        menu.held = false;
                        BarState.releasePopup(root.monitorName);
                    }
                }
            }
        }
    }

    // Overflow button displayed when hidden items exceed maxVisible
    Item {
        id: overflow
        visible: SystemTray.items.values.length > root.maxVisible
        width: 20
        height: Theme.barContentHeight

        onVisibleChanged: {
            if (!visible && overflowPopup.opened)
                overflowPopup.close();
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusSm
            color: Theme.accent
            opacity: root.dropZone === "overflowBtn" ? 0.3 : 0
        }

        IconImage {
            anchors.centerIn: parent
            width: 12
            height: 12
            source: Quickshell.iconPath("view-more-symbolic", true)
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: {
                if (overflowPopup.opened)
                    overflowPopup.close();
                else if (Date.now() - root.popupClosedAt > 250)
                    overflowPopup.open();
            }
            cursorShape: Qt.PointingHandCursor
        }

        // Popup containing hidden tray items
        Popup {
            id: overflowPopup
            parent: root
            y: overflow.height + 6
            x: overflow.x - overflowPopup.implicitWidth / 2 + overflow.width / 2
            padding: 6
            closePolicy: Popup.CloseOnPressOutside
            background: Rectangle {
                color: Theme.surface
                radius: Theme.cardRadius
                border.color: root.dropZone === "popup" ? Theme.accent : Theme.border
                border.width: root.dropZone === "popup" ? 2 : 1
            }

            onOpened: {
                BarState.holdPopup(root.monitorName);
                root.setPopupMask(overflowPopup.background);
            }
            onClosed: {
                root.popupClosedAt = Date.now();
                root.setPopupMask(null);
                BarState.releasePopup(root.monitorName);
            }

            Grid {
                id: popupGrid
                columns: Math.max(1, Math.min(4, popupRep.count))
                spacing: 4

                Repeater {
                    id: popupRep
                    model: root.ordered.slice(root.maxVisible)
                    delegate: Item {
                        id: hiddenEntry
                        required property var modelData
                        width: 28
                        height: 28

                        Component.onDestruction: {
                            if (root.dragItem === hiddenEntry.modelData)
                                root.dragFinish(false);
                        }

                        MouseArea {
                            id: hiddenMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: root.dragActive ? Qt.ClosedHandCursor : Qt.ArrowCursor
                            onPressed: mouse => root.dragPress(hiddenEntry.modelData, hiddenMouse, mouse)
                            onPositionChanged: mouse => root.dragMove(hiddenMouse, mouse)
                            onReleased: root.dragFinish(true)
                            onCanceled: root.dragFinish(false)
                            onClicked: mouse => {
                                if (root.dragClickGuard)
                                    return;
                                if (mouse.button === Qt.LeftButton)
                                    hiddenEntry.modelData.activate();
                                else if (hiddenEntry.modelData.hasMenu)
                                    hiddenMenu.open();
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: hiddenHover.hovered ? Theme.surfaceHover : "transparent"
                        }

                        IconImage {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: hiddenEntry.modelData.icon
                            asynchronous: true
                            opacity: (root.dragActive && root.dragItem === hiddenEntry.modelData) ? 0.3 : 1
                        }

                        HoverHandler {
                            id: hiddenHover
                            cursorShape: Qt.ArrowCursor
                        }

                        AppTooltip {
                            visible: hiddenHover.hovered && !root.dragActive && text.length > 0
                            text: {
                                const item = hiddenEntry.modelData;
                                return (item.tooltipTitle || item.title || item.tooltipDescription || "").trim();
                            }
                        }

                        QsMenuAnchor {
                            id: hiddenMenu
                            menu: hiddenEntry.modelData.menu
                            anchor.item: hiddenEntry
                            anchor.edges: Edges.Right
                            property bool held: false
                            Component.onDestruction: {
                                if (held)
                                    BarState.releasePopup(root.monitorName);
                            }
                        }

                        Connections {
                            target: hiddenMenu
                            function onVisibleChanged() {
                                if (hiddenMenu.visible && !hiddenMenu.held) {
                                    hiddenMenu.held = true;
                                    BarState.holdPopup(root.monitorName);
                                } else if (!hiddenMenu.visible && hiddenMenu.held) {
                                    hiddenMenu.held = false;
                                    BarState.releasePopup(root.monitorName);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
