import QtQuick
import qs.theme

// Shared card shell: the one true surface/radius/border triple, with contentMargins/Spacing
// defaulting to 12/8; colour, border and radius stay overridable per instance.
Rectangle {
    id: root
    default property alias content: col.children
    property int contentMargins: Theme.pad
    property int contentSpacing: Theme.spacing
    color: Theme.surface
    radius: Theme.radius
    border.color: Theme.border
    Column {
        id: col
        anchors.fill: parent
        anchors.margins: root.contentMargins
        spacing: root.contentSpacing
    }
}
