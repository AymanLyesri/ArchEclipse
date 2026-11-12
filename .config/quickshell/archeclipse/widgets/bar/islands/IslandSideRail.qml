import QtQuick
import qs.theme
import qs.widgets.shared

// Shared rail of full-bleed icon cells for the left island tabs (toggle highlight, Donations
// nudge, tooltips); `dragEnabled` is reserved — RightIsland keeps its custom reorder rail.
Rectangle {
    id: root
    property var model: []
    property bool dragEnabled: false
    property int currentIndex: 0
    property string highlightedName: ""
    signal selected(int index)
    color: "transparent"
    implicitHeight: railColumn.implicitHeight
    height: railColumn.implicitHeight

    Column {
        id: railColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // Half-step gutter: the cells are the rhythm, the rail should not add its own beat.
        spacing: Theme.spaceXs

        Repeater {
            model: root.model
            // Cell thickness is AppButton's own token value (vPadding/minHeight), not a literal;
            // the rail owns the full-bleed width so proportional glyphs cannot make cells ragged.
            delegate: Item {
                required property var modelData
                // NOTE: `index` must be declared: with required properties
                // present, Qt6 withholds undeclared delegate context props.
                required property int index
                width: railColumn.width
                height: cell.implicitHeight
                AppButton {
                    id: cell
                    anchors.fill: parent
                    icon: modelData.icon !== undefined ? modelData.icon : ""
                    cornerRadius: Theme.radius
                    pixelSize: Theme.fontSize + 2
                    toggle: true
                    checked: index === root.currentIndex
                    outlined: modelData.name === root.highlightedName
                    outlineColor: Theme.accent
                    // Selected cells sit on the raised plane, not on an accent outline.
                    activeBg: Theme.surfaceOverlay
                    // Donations special red color to nudge users toward
                    // the support widget (preserved from LeftIsland).
                    idleBg: modelData.name === "Donations" ? "#f96854" : "transparent"
                    idleFg: modelData.name === "Donations" ? "#052d49" : Theme.fg
                    borderColor: modelData.name === "Donations" ? "#f96854" : Theme.accent
                    tooltipText: modelData.name === "Donations" ? "Click to open Donations\n<b>＼(o￣∇￣)／</b> — Support the project" : "Click to open " + modelData.name
                    onClicked: root.selected(index)
                }
            }
        }
    }
}
