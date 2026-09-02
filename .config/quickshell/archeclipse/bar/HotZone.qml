import QtQuick
import Quickshell
import qs.theme
import qs.services

// Hot-zone strips at the bar's left/right ends — reveal the left/right panels
// after a 500ms dwell (mirrors AGS LeftPanelHover.tsx / RightPanelHover.tsx).
// The panels register themselves with Registry by monitor name.
Rectangle {
    id: root

    property string side: "left"
    property real size: 5
    property bool enabledHotZone: true
    property bool panelLock: false
    property string monitorName: ""

    anchors.left: side === "left" ? parent.left : undefined
    anchors.right: side === "right" ? parent.right : undefined
    anchors.top: Settings.barOrientation ? parent.top : undefined
    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom

    width: size
    height: parent.height
    color: preview ? Qt.rgba(1, 0.33, 0.33, 0.4) : "transparent"

    readonly property string panelKey: side === "left"
        ? `left-panel-${root.monitorName}`
        : `right-panel-${root.monitorName}`

    property bool preview: false

    Timer {
        id: dwellTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root.panelLock) return
            root.showPanel()
        }
    }

    HoverHandler {
        enabled: root.enabledHotZone && root.panelLock === false
        onHoveredChanged: {
            if (hovered) {
                dwellTimer.restart()
            } else {
                dwellTimer.stop()
            }
        }
    }

    // Also track hover on the zone itself for preview mode (debug)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.enabledHotZone
        onEntered: {
            if (Settings.leftPanelLock || Settings.rightPanelLock) return
            dwellTimer.restart()
        }
        onExited: dwellTimer.stop()
        onClicked: root.showPanel()
    }

    function showPanel() {
        const panel = Registry.get(root.panelKey)
        if (panel) {
            panel.visible = true
        } else {
            console.warn("[HotZone] Panel not registered for key:", root.panelKey)
        }
    }

    Connections {
        target: Settings
        function onLeftPanelHotZoneChanged() {}
        function onRightPanelHotZoneChanged() {}
    }
}