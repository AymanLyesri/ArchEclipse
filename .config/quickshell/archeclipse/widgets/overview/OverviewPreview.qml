import QtQuick
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.widgets.shared

// OverviewPreview — one live window tile in the overview grid.
// ScreencopyView captures the Wayland toplevel live (end-4 OverviewWindow
// pattern); hover/press dim it, the app icon badges the corner, and the
// MouseArea drives dragging (the card DropArea moves the window off
// drop.source on drop), click to focus, middle-click to close.
//
// Geometry (x/y/width/height) is owned by the parent wrapper — this item
// only fills it. Window actions go through `host` (the OverviewBody).
Item {
    id: root

    property var captureSrc
    property string iconText: ""
    property string winTitle: ""
    property string winAddr: ""
    property int wsId: 1
    property var host: null
    property bool hovered: false
    property bool pressed: false

    anchors.fill: parent

    // Clipped container: ScreencopyView paints square video frames, so the
    // rounding must come from a clipping parent (plain `clip: true` only
    // clips rectangularly).
    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.chipRadius
        color: "transparent"
        // Constant width (color-only hover): toggling width 0→1 would
        // shift the tile content by a pixel on every hover.
        border.color: root.hovered ? Theme.accent : "transparent"
        border.width: 1

        ScreencopyView {
            id: preview
            anchors.fill: parent
            captureSource: root.captureSrc ?? null
            live: true
        }

        // Icon badge while the capture has no content yet (or if the
        // compositor ends the stream).
        Text {
            anchors.centerIn: parent
            visible: !preview.hasContent
            text: root.iconText
            color: Theme.muted
            font.family: "JetBrainsMono NFP"
            font.pixelSize: Math.max(10, Math.min(parent.width, parent.height) * 0.4)
        }

        // Interaction overlay.
        Rectangle {
            anchors.fill: parent
            color: root.pressed ? Qt.alpha(Theme.surfaceActive, 0.5)
                : root.hovered ? Qt.alpha(Theme.surfaceActive, 0.3) : "transparent"
        }

        // App icon corner badge (shared pill — hides itself on empty text).
        AppBadge {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 3
            text: root.iconText
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: false
        propagateComposedEvents: true
        cursorShape: Qt.PointingHandCursor
        // Wheel-transparent so a wrapping scroller keeps working.
        onWheel: wheel => wheel.accepted = false
        drag.target: root.parent
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onPressed: mouse => {
            if (mouse.button !== Qt.LeftButton)
                return;
            root.pressed = true;
            root.Drag.active = true;
            root.Drag.source = root;
            root.Drag.hotSpot.x = mouse.x;
            root.Drag.hotSpot.y = mouse.y;
        }
        onReleased: {
            if (!root.Drag.active)
                return;
            root.pressed = false;
            root.Drag.active = false;
            // Target is resolved geometrically in finishDrag (it snaps back
            // itself on a miss); on a move this tile vanishes with its
            // workspace.
            if (root.host)
                root.host.finishDrag(root.wsId, root.winAddr, root.parent);
        }
        onClicked: event => {
            if (root.host === null || root.host === undefined)
                return;
            if (event.button === Qt.LeftButton)
                root.host.focusWindow(root.winAddr);
            else if (event.button === Qt.MiddleButton)
                root.host.closeWindow(root.winAddr);
        }
    }
}
