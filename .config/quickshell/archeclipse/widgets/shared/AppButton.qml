// THE shared button: centered glyph + optional label. Controls Button's padding pushes content
// off-center, hence Rectangle + Row + MouseArea. Depth, not outlines: flat, wash, settle.

import QtQuick
import QtQuick.Controls
import qs.theme

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
    // Icon/label gap, exposed so dense rails and roomy headers can both breathe.
    property int contentSpacing: Theme.spaceXs + 2
    // Size tokens are the only size control: an icon or short-label cell must not pin a width
    // or height at its call site, or one padded box drifts from the rest of the shell.
    property int hPadding: Theme.pad * 2
    property int vPadding: Theme.pad * 2
    property int minHeight: 22
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
    property color outlineColor: Theme.hairline
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
        // Drag paints the cell with Theme.accent; accent ink on it is invisible.
        if (root.dragging)
            return Theme.accentFg;

        if (root.highlighted)
            return root.activeFg;

        if (root.hovered && !root.quiet)
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

    implicitWidth: contentRow.implicitWidth + root.hPadding * 2
    implicitHeight: Math.max(root.minHeight, root.pixelSize + root.vPadding * 2)

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
        // Press sinks the cell; hover lifts it a hair. Visual only, layout untouched.
        scale: !root.enabled ? 1 : (hoverArea.pressed ? 0.96 : (root.hovered && !root.quiet ? 1.03 : 1))
        color: {
            if (root.dragging)
                return Theme.accent;

            if (hoverArea.pressed)
                return root.pressedBg;

            if (root.highlighted)
                return root.activeBg;

            if (root.hovered && !root.quiet)
                return root.hoverBg;

            return root.idleBg;
        }
        // A focus ring is an accessibility affordance, not decoration; nothing else outlines.
        border.width: root.activeFocus ? 2 : (root.outlined ? 1 : 0)
        border.color: root.activeFocus ? Theme.accent : (root.highlighted ? root.borderColor : root.outlineColor)
        opacity: root.enabled ? (root.dragging ? Theme.opacity.hoverDim : 1) : Theme.opacity.disabled

        Behavior on color {
            CAnim {}
        }
        Behavior on scale {
            Anim {
                type: Anim.FastEffects
            }
        }
        Behavior on border.color {
            CAnim {}
        }

        Row {
            id: contentRow

            anchors.centerIn: parent
            spacing: root.contentSpacing

            Text {
                visible: root.icon !== ""
                text: root.icon
                font.pixelSize: root.pixelSize
                font.family: root.fontFamily
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: root.fgColor

                Behavior on color {
                    CAnim {}
                }
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

                Behavior on color {
                    CAnim {}
                }
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
