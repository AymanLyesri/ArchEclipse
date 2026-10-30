// THE shared button for the whole shell: centered glyph + optional label in a rounded cell.
// A Controls Button's padding pushes content off-center, so this is Rectangle + Row + MouseArea.

import QtQuick
import QtQuick.Controls
import qs.theme

    // toggle: false = momentary, true = highlighted while caller-driven `checked` (autoToggle
    // opts into local state). text is an optional label, outlined always draws the border.
Item {
    id: root

    property string icon: ""
    property string text: ""
    // Optional maximum width for the text label; -1 keeps natural sizing.
    property real labelMaxWidth: -1
    // Every button must explain itself, but NOT via `required property`: a delegate root with any
    // required property makes Qt withhold modelData, giving silent empty icons shell-wide.
    property string tooltipText: ""
    // False opts out of the hover tooltip popup (the button still needs tooltipText): a popup
    // grab stealing the pointer reads as hover-out and closes stadium pills.
    property bool showTooltip: true
    // Quiet mode: no hover reading at all (hoverEnabled off, no hover scale) for cells inside
    // auto-revealing stadiums, where any hover reaction churned the reveal (probe-proven).
    property bool quiet: false
    property string fontFamily: Theme.fontFamily
    property string labelFontFamily: ""
    property int pixelSize: Theme.fontSize
    property int cornerRadius: Theme.radius
    property bool toggle: false
    property bool checked: false
    property bool autoToggle: false
    property bool outlined: false
    property color idleBg: "transparent"
    property color hoverBg: Theme.surfaceHover
    property color pressedBg: Theme.surfaceActive
    property color activeBg: Theme.surfaceActive
    property color idleFg: Theme.fg
    property color hoverFg: idleFg
    property color activeFg: Theme.accent
    property color borderColor: Theme.accent
    property color outlineColor: Theme.border
    property bool borderedWhenActive: false
    property bool dragging: false
    // Reorder drag (right selector rail). Null target = plain click cell.
    property bool draggable: false
    property Item dragTarget: null
    property int dragAxis: Drag.YAxis
    property real dragMinimum: -10000
    property real dragMaximum: 10000
    property alias hovered: hoverArea.containsMouse
    property alias dragActive: hoverArea.drag.active
    readonly property bool highlighted: root.toggle && root.checked
    readonly property color fgColor: {
        if (root.highlighted)
            return root.activeFg;

        if (root.hovered)
            return root.hoverFg;

        return root.idleFg;
    }

    signal clicked
    signal pressed
    signal released

    // Loud stand-in for the removed required-property gate: warn (not error), since some cells
    // legitimately ship an empty tooltip. Greppable on reload in /tmp/qs-bar-$USER.log.
    Component.onCompleted: if (tooltipText === "" && showTooltip)
        console.warn("MISSING TOOLTIPTEXT AppButton:", this, "icon:", JSON.stringify(icon), "text:", JSON.stringify(text))

    implicitWidth: contentRow.implicitWidth + 28
    implicitHeight: 34

    // Keyboard activation: Return/Enter/Space click the cell, one focus
    // ring style for every button instance in the shell.
    activeFocusOnTab: true
    Keys.onReturnPressed: event => {
        event.accepted = true;
        root.clicked();
    }
    Keys.onEnterPressed: event => {
        event.accepted = true;
        root.clicked();
    }
    Keys.onSpacePressed: event => {
        event.accepted = true;
        root.clicked();
    }

    AppTooltip {
        visible: root.showTooltip && root.hovered && root.tooltipText !== ""
        text: root.tooltipText
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: root.cornerRadius
        // Subtle grow on hover, shrink on press — visual only, layout unchanged.
        // Quiet cells skip the hover branch entirely (hover stays unread).
        scale: !root.enabled ? 1 : (hoverArea.pressed ? 0.96 : (root.hovered && !root.quiet ? 1.04 : 1))
        color: {
            if (root.dragging)
                return Theme.accent;

            if (hoverArea.pressed)
                return root.pressedBg;

            if (root.highlighted)
                return root.activeBg;

            if (root.hovered)
                return root.hoverBg;

            return root.idleBg;
        }
        Behavior on color {
            CAnim {}
        }
        Behavior on scale {
            Anim {
                type: Anim.FastEffects
            }
        }
        border.width: root.activeFocus ? 2 : (root.outlined ? 1 : ((root.highlighted || root.dragging) && root.borderedWhenActive ? 1 : 0))
        border.color: {
            // Focus ring: accent ring beats every idle/outline border.
            if (root.activeFocus)
                return Theme.accent;

            if (root.dragging)
                return Theme.accent;

            if (root.highlighted)
                return root.borderColor;

            return root.outlined ? root.outlineColor : root.borderColor;
        }
        opacity: root.enabled ? (root.dragging ? Theme.opacity.hoverDim : 1) : Theme.opacity.disabled

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
                width: root.labelMaxWidth >= 0 ? root.labelMaxWidth : implicitWidth
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
        hoverEnabled: !root.quiet
        acceptedButtons: Qt.LeftButton
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        drag.target: root.draggable ? root.dragTarget : null
        drag.axis: root.dragAxis
        drag.minimumY: root.dragMinimum
        drag.maximumY: root.dragMaximum
        onPressed: root.pressed()
        onReleased: root.released()
        onClicked: {
            if (root.toggle && root.autoToggle)
                root.checked = !root.checked;

            root.clicked();
        }
    }
}
