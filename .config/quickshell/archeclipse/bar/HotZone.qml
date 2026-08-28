import QtQuick
import Quickshell
import qs.theme
import qs.services

// Hot-zone strips at the bar's left/right ends — reveal the left/right panels
// after a 500ms dwell (Bar.tsx hot-zone motion controllers). The panels
// themselves are not migrated yet; the dwell timers are wired and the panel
// show calls are logged until LeftPanel/RightPanel land.
Rectangle {
    id: root

    property string side: "left"
    property real size: 5
    property bool enabledHotZone: true
    property bool panelLock: false

    anchors.left: side === "left" ? parent.left : undefined
    anchors.right: side === "right" ? parent.right : undefined
    anchors.top: Settings.barOrientation ? parent.top : undefined
    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
    width: size
    height: parent.height
    color: preview ? Qt.rgba(1, 0.33, 0.33, 0.4) : "transparent"

    property bool preview: false

    Timer { id: dwellTimer; interval: 500; onTriggered: root.showPanel() }

    HoverHandler {
        enabled: root.enabledHotZone && root.panelLock
        onHoveredChanged: hovered ? dwellTimer.restart() : dwellTimer.stop()
    }

    function showPanel() {
        console.warn(`[HotZone] ${root.side} panel reveal — panels not yet migrated`);
    }
}
