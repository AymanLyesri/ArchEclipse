import QtQuick
import qs.widgets.shared

// System Resources widget — thin wrapper around the shared
// SystemResourcesContent (same widget as the bar's SystemMonitorIsland).
Item {
    id: root

    implicitHeight: content.implicitHeight + 16

    SystemResourcesContent {
        id: content
        anchors.fill: parent
        anchors.margins: 8
    }
}
