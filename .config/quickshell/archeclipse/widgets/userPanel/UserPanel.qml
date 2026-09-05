import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.leftPanel

// Port of widgets/UserPanel.tsx + scss/widgets/user-panel.scss.
// Full-screen OVERLAY power grid (Esc closes):
//   Logout (top-left) | Shutdown (top-right) / Sleep (bottom-left) | Reboot (bottom-right)
// AGS details preserved: dim rgba(0,0,0,0.2), 350px buttons, 10px grid gaps,
// per-corner radii (30px outer corner / 10px rest, 50px on hover), 5px border
// transparent -> $secondary on hover, 1.1 scale + directional push on hover,
// 4em glyphs, exact tooltips, UserProfileMinimal pill centered on top.
PanelWindow {
    id: root

    required property ShellScreen screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.2)
    aboveWindows: true
    visible: false

    property string monitorName: (Hyprland.monitorFor(screen)?.name) ?? ""
    Component.onCompleted: Registry.register(`user-panel-${monitorName}`, root)
    Component.onDestruction: Registry.unregister(`user-panel-${monitorName}`)

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
    }

    // AGS 350px buttons, clamped so the 2x2 grid + gaps fits small screens.
    readonly property real btnSize: Math.max(140, Math.min(350, root.width * 0.32, root.height * 0.32))
    readonly property real gridGap: 10

    Component {
        id: actionButton
        Item {
            id: btn
            property string glyph: ""
            property string tip: ""
            property var onAct: null
            // AGS per-corner radii: one 30px outer corner, rest 10px; 50px all on hover.
            property real rTL: 10; property real rTR: 10
            property real rBR: 10; property real rBL: 10
            property real pushX: 0; property real pushY: 0
            width: root.btnSize; height: root.btnSize
            scale: ma.containsMouse ? 1.1 : 1.0
            property real transformTranslateX: 0
            property real transformTranslateY: 0
            transform: Translate { x: btn.transformTranslateX; y: btn.transformTranslateY }
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on transformTranslateX { NumberAnimation { duration: 100 } }
            Behavior on transformTranslateY { NumberAnimation { duration: 100 } }

            Shape {
                anchors.fill: parent
                ShapePath {
                    fillColor: ma.containsMouse ? Theme.bg : Theme.backgroundTransparent
                    strokeColor: ma.containsMouse ? Theme.secondary : "transparent"
                    strokeWidth: 5
                    // Per-corner rounded rect (AGS .logout/.shutdown/.sleep/.reboot radii).
                    PathMove { x: btn.rTL; y: 0 }
                    PathLine { x: btn.width - btn.rTR; y: 0 }
                    PathArc { x: btn.width; y: btn.rTR; radiusX: ma.containsMouse ? 50 : btn.rTR; radiusY: ma.containsMouse ? 50 : btn.rTR }
                    PathLine { x: btn.width; y: btn.height - btn.rBR }
                    PathArc { x: btn.width - btn.rBR; y: btn.height; radiusX: ma.containsMouse ? 50 : btn.rBR; radiusY: ma.containsMouse ? 50 : btn.rBR }
                    PathLine { x: btn.rBL; y: btn.height }
                    PathArc { x: 0; y: btn.height - btn.rBL; radiusX: ma.containsMouse ? 50 : btn.rBL; radiusY: ma.containsMouse ? 50 : btn.rBL }
                    PathLine { x: 0; y: btn.rTL }
                    PathArc { x: btn.rTL; y: 0; radiusX: ma.containsMouse ? 50 : btn.rTL; radiusY: ma.containsMouse ? 50 : btn.rTL }
                }
            }
            Text {
                anchors.centerIn: parent
                text: btn.glyph
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 4
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (btn.onAct) btn.onAct()
                onContainsMouseChanged: {
                    btn.transformTranslateX = containsMouse ? btn.pushX : 0;
                    btn.transformTranslateY = containsMouse ? btn.pushY : 0;
                }
            }
            ToolTip.visible: ma.containsMouse
            ToolTip.text: btn.tip
            ToolTip.delay: 600
        }
    }

    // 2x2 action grid (AGS attach order: Logout TL, Shutdown TR, Sleep BL, Reboot BR).
    Grid {
        anchors.centerIn: parent
        columns: 2
        rows: 2
        spacing: root.gridGap

        Loader {
            sourceComponent: actionButton
            onLoaded: {
                item.glyph = "\uF0343"; item.tip = "logout from Hyprland"
                item.rTL = 30; item.rTR = 10; item.rBR = 10; item.rBL = 10
                item.pushX = -30; item.pushY = -30
                item.onAct = () => Hyprland.dispatch("hl.dsp.exit()")
            }
        }
        Loader {
            sourceComponent: actionButton
            onLoaded: {
                item.glyph = "\uF011"; item.tip = "shutdown immediately"
                item.rTL = 10; item.rTR = 30; item.rBR = 10; item.rBL = 10
                item.pushX = 30; item.pushY = -30
                item.onAct = () => Quickshell.execDetached(["shutdown", "now"])
            }
        }
        Loader {
            sourceComponent: actionButton
            onLoaded: {
                item.glyph = "\uF0904"; item.tip = "put system to sleep"
                item.rTL = 10; item.rTR = 10; item.rBR = 10; item.rBL = 30
                item.pushX = -30; item.pushY = 30
                item.onAct = () => { root.visible = false; Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/hyprlock.sh suspend"]) }
            }
        }
        Loader {
            sourceComponent: actionButton
            onLoaded: {
                item.glyph = "\uF0709"; item.tip = "reboot immediately"
                item.rTL = 10; item.rTR = 10; item.rBR = 30; item.rBL = 10
                item.pushX = 30; item.pushY = 30
                item.onAct = () => Quickshell.execDetached(["reboot"])
            }
        }
    }

    // Center: minimal user profile pill on top of the grid (AGS overlay + .user-profile .main).
    Rectangle {
        anchors.centerIn: parent
        z: 1
        width: 280
        height: 210
        radius: 50
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        UserProfileWidget {
            anchors.centerIn: parent
            width: 240
            height: 180
            minimal: true
        }
    }
}
