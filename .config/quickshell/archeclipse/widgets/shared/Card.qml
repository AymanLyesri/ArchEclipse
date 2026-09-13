import QtQuick
import qs.theme

// Shared card shell: the one true surface/radius/border triple.
// contentMargins/contentSpacing default to the standard 12/8; delegates that
// were built with tighter geometry override them at the use site (visuals
// unchanged). color/border.color/radius are likewise overridable per instance.
Rectangle {
    id: root
    default property alias content: col.children
    property int contentMargins: 12
    property int contentSpacing: 8
    color: Theme.surface
    radius: Theme.cardRadius
    border.color: Theme.border
    Column {
        id: col
        anchors.fill: parent
        anchors.margins: root.contentMargins
        spacing: root.contentSpacing
    }
}
