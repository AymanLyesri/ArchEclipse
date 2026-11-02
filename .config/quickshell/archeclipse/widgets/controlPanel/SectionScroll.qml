import QtQuick
import QtQuick.Controls
import qs.theme
import qs.widgets.shared

// Capped scroll host for a section body: long app/device lists scroll instead of
// stretching the center pill past the screen edge. Content is a vertical Column.
Item {
    id: root

    property real maxHeight: 240
    default property alias content: inner.data

    // Explicit height: the Card's Column lays out on height, not implicitHeight.
    height: Math.min(inner.implicitHeight, root.maxHeight)

    SmoothFlickable {
        id: flick
        anchors.fill: parent
        contentWidth: flick.width
        contentHeight: inner.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        // Width from the Flickable, never parent.width: a contentItem-negotiated width
        // loops the polish pass.
        Column {
            id: inner
            width: flick.width
            spacing: Theme.spacing
        }
    }
}
