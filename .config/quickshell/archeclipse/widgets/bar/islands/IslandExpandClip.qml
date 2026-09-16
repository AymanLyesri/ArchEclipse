import QtQuick

// Shared unfold body clip. Caller sets `expand` 0->1 on creation
// and passes the body height as `contentHeight`; the body itself goes
// in as a child (anchored top, like the inline bodyClips this replaces).
Item {
    id: root
    property real expand: 0
    property real contentHeight: 0
    width: parent ? parent.width : 0
    height: Math.max(0, root.expand * root.contentHeight)
    clip: true
    opacity: Math.max(0, Math.min(1, root.expand * 1.2))
    scale: 0.96 + 0.04 * root.expand
    transformOrigin: Item.Top
    Behavior on expand {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
}
