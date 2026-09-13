import QtQuick
import qs.theme
import qs.widgets.shared

// Shared 48px sidebar rail with 40px cells (Left island tab selectors).
// The caller keeps its sidebar container and anchors this top/left/right.
//
// The delegate preserves the Left rail visuals verbatim: icon cells with
// toggle highlight, the Donations red nudge, and per-tab tooltips. Items
// are `{ name, icon }`; selection is by `currentIndex` with `selected`
// carrying the tapped index back.
//
// NOTE: `dragEnabled` is reserved and currently always false —
// RightIsland keeps its custom drag-reorder rail (Drag.active/DropArea +
// isDragging auto-hide hold), which this Repeater port cannot preserve.
Rectangle {
    id: root
    property var model: []
    property bool dragEnabled: false
    property int currentIndex: 0
    signal selected(int index)
    color: "transparent"
    implicitHeight: railColumn.implicitHeight
    height: railColumn.implicitHeight

    Column {
        id: railColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Repeater {
            model: root.model
            // Same 40px cell structure as the inline rails this
            // replaces: fixed-height full-width cell, icon centered.
            delegate: Item {
                required property var modelData
                // NOTE: `index` must be declared: with required properties
                // present, Qt6 withholds undeclared delegate context props.
                required property int index
                width: railColumn.width
                height: 40
                AppButton {
                    anchors.fill: parent
                    icon: modelData.icon !== undefined ? modelData.icon : ""
                    toggle: true
                    checked: index === root.currentIndex
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
