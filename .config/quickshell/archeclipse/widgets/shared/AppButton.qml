import QtQuick
import QtQuick.Controls
import qs.theme

// THE shared button for the whole shell: selector rails, WindowActions,
// tab bars, dialog actions, media controls. Centered JetBrainsMono NFP
// glyph + optional text label in a rounded cell — identical visuals
// everywhere (a Controls Button's built-in padding/insets shift content
// off-center, so this is a plain Rectangle + Row + MouseArea by design).
//
//   toggle: false -> momentary action (expand / close / save / play)
//   toggle: true  -> highlighted while `checked`. `checked` is ALWAYS
//                    caller-driven (a Settings binding or a selected-tab
//                    expression) — the button never flips it, except when
//                    autoToggle is set for unbound local-state uses.
//   text          -> optional label after the icon (icon may be empty).
//   outlined      -> border always visible (tabs); color follows highlight.
//   enabled       -> Item.enabled dims the cell and blocks clicks.
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string tooltipText: ""
    property string fontFamily: "JetBrainsMono NFP"
    property string labelFontFamily: ""
    property int pixelSize: 20
    property int cornerRadius: 8

    property bool toggle: false
    property bool checked: false
    property bool autoToggle: false
    property bool outlined: false

    property color idleBg: "transparent"
    property color hoverBg: "transparent"
    property color activeBg: Theme.accentBg
    property color idleFg: Theme.fg
    property color hoverFg: idleFg
    property color activeFg: Theme.accent
    property color borderColor: Theme.accent
    property color outlineColor: Theme.border
    property bool borderedWhenActive: true
    property bool dragging: false

    // Reorder drag (right selector rail). Null target = plain click cell.
    property bool draggable: false
    property Item dragTarget: null
    property int dragAxis: Drag.YAxis
    property real dragMinimum: -10000
    property real dragMaximum: 10000

    property alias hovered: hoverArea.containsMouse
    property alias dragActive: hoverArea.drag.active

    signal clicked
    signal pressed
    signal released

    implicitWidth: contentRow.implicitWidth + 28
    implicitHeight: 34

    readonly property bool highlighted: root.toggle && root.checked
    readonly property color fgColor: {
        if (root.highlighted) return root.activeFg
        if (root.hovered) return root.hoverFg
        return root.idleFg
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: {
            if (root.dragging) return Theme.accent
            if (root.highlighted) return root.activeBg
            if (root.hovered) return root.hoverBg
            return root.idleBg
        }
        border.width: root.outlined ? 1 : ((root.highlighted || root.dragging) && root.borderedWhenActive ? 1 : 0)
        border.color: {
            if (root.dragging) return Theme.accent
            if (root.highlighted) return root.borderColor
            return root.outlined ? root.outlineColor : root.borderColor
        }
        opacity: root.enabled ? (root.dragging ? 0.6 : 1) : 0.4

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: root.icon !== ""
                text: root.icon
                font.pixelSize: root.pixelSize
                font.family: root.fontFamily
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: root.fgColor
            }
            Text {
                visible: root.text !== ""
                text: root.text
                font.pixelSize: root.pixelSize
                font.family: root.labelFontFamily !== "" ? root.labelFontFamily : Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: root.fgColor
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        enabled: root.enabled
        drag.target: root.draggable ? root.dragTarget : null
        drag.axis: root.dragAxis
        drag.minimumY: root.dragMinimum
        drag.maximumY: root.dragMaximum
        onPressed: root.pressed()
        onReleased: root.released()
        onClicked: {
            if (root.toggle && root.autoToggle) root.checked = !root.checked
            root.clicked()
        }
    }

    ToolTip.visible: root.hovered && root.tooltipText !== ""
    ToolTip.text: root.tooltipText
    ToolTip.delay: 600
}
