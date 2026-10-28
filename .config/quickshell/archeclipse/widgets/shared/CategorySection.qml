import QtQuick
import QtQuick.Controls
import qs.theme

// One category card for panel widgets (Settings, Key Binds, …).
//
// Category titles live in the host's CategoryNav model, so a header can
// never drift from its rail entry. Opacity composes the host's reveal state
// (staggered tab-open fade) with the nav's focus falloff into one property,
// keeping a single Behavior — no stacked opacity wrappers, no layout
// changes.
Rectangle {
    id: root

    // Optional: when set, title/focusOpacity follow the nav automatically.
    property CategoryNav nav: null
    property int categoryIndex: -1
    // Overridable for hosts that own their own group-level fade.
    property string title: root.nav && root.nav.categories[root.categoryIndex] !== undefined ? root.nav.titleFor(root.categoryIndex) : ""
    property bool revealed: true
    property real focusOpacity: root.nav ? root.nav.opacityFor(root.categoryIndex) : 1

    default property alias content: rows.data

    width: parent ? parent.width : 0
    // Same footprint the hand-written cards used (content + 2*pad + 8) so
    // the section rhythm is unchanged.
    implicitHeight: body.implicitHeight + Theme.pad * 2 + 8
    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    opacity: (root.revealed ? 1 : 0) * root.focusOpacity
    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Column {
        id: body

        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.spacing

        Label {
            // Category names can be arbitrary strings (Key Binds reads
            // them from bind.lua comments): elide instead of overflowing
            // the card.
            width: parent.width
            text: root.title
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            color: Theme.accent
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Column {
            id: rows

            width: parent.width
            spacing: Theme.spacing
        }
    }
}
