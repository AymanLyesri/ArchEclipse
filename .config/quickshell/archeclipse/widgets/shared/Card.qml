import QtQuick
import qs.theme

// Shared card shell: a Surface at the resting depth level. The content inset follows `pad`
// (the Settings slider every card obeys); the gap between rows follows the spacing ladder.
Surface {
    id: root

    default property alias content: col.children
    property int contentMargins: Theme.pad
    property int contentSpacing: Theme.spaceSm

    level: 1

    Column {
        id: col

        anchors.fill: parent
        anchors.margins: root.contentMargins
        spacing: root.contentSpacing
    }
}
