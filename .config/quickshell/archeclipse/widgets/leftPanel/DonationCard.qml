import QtQuick
import qs.theme

// Card shell for the Donations tab: surface, border and a padded content column that sizes
// to its children (previously spelled inline five times).
Rectangle {
    id: root

    // Status card tints the border while supporter status is active; the rule only draws when
    // a host opts in, so the resting card stays a borderless plate.
    property color borderColor: Theme.border
    property bool highlighted: false
    default property alias content: col.data

    width: parent.width
    implicitHeight: col.implicitHeight + 20
    radius: Theme.radius
    // Raised plate: the donation cards separate from the page by depth, and an accent
    // `borderColor` still wins when a host wants to highlight one.
    color: Theme.surfaceRaised
    border.color: root.borderColor
    border.width: root.highlighted ? 1 : 0

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: Theme.spacing
    }
}
