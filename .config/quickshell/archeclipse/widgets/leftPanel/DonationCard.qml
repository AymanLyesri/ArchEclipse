import QtQuick
import qs.theme

// Card shell for the Donations tab: surface, border and a padded content column that sizes
// to its children (previously spelled inline five times).
Rectangle {
    id: root

    // Status card tints the border while supporter status is active.
    property color borderColor: Theme.border
    default property alias content: col.data

    width: parent.width
    implicitHeight: col.implicitHeight + 20
    radius: Theme.radius
    color: Theme.surface
    border.color: root.borderColor
    border.width: 1

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: Theme.spacing
    }
}
