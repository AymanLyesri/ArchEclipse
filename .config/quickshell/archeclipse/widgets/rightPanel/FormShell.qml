import QtQuick
import QtQuick.Layouts
import qs.theme

Rectangle {
    id: root
    default property alias content: col.children
    color: Theme.surface
    radius: Theme.cardRadius
    Layout.fillWidth: true
    Layout.minimumHeight: 300
    Layout.preferredHeight: 350
    Column {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
    }
}
