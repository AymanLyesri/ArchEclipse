import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: screen ? screen.name : ""
    property bool selecting: false
    property real startX: 0
    property real startY: 0
    property real currentX: 0
    property real currentY: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    visible: selecting
    WlrLayershell.layer: WlrLayer.Overlay
    // WlrLayershell.namespace: "selection-overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Component.onCompleted: Registry.register("drag-overlay-" + monitorName, root)
    Component.onDestruction: Registry.unregister("drag-overlay-" + monitorName)

    function startSelection(x: real, y: real): void {
        startX = x;
        startY = y;
        currentX = x;
        currentY = y;
        selecting = true;
    }

    function updateSelection(x: real, y: real): void {
        if (!selecting)
            return;
        currentX = x;
        currentY = y;
    }

    function stopSelection(): void {
        selecting = false;
    }

    Rectangle {
        x: Math.min(root.startX, root.currentX)
        y: Math.min(root.startY, root.currentY)
        width: Math.max(1, Math.abs(root.currentX - root.startX))
        height: Math.max(1, Math.abs(root.currentY - root.startY))
        color: Theme.surface
        // border.color: Theme.accent
        // border.width: 2
        radius: 16
        visible: root.selecting
    }
}
