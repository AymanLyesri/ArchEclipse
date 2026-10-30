import QtQuick
import qs.theme
import qs.widgets.shared

// Shared unfold body clip: the caller sets `expand` 0->1 and passes `contentHeight`, with the
// body as a child; easing follows Settings.islandAnimStyle.
Item {
    id: root
    property real expand: 0
    property real contentHeight: 0
    // Horizontal variant (side-pill rows): the caller binds its width to the clip's, fromLeft
    // grows rightward from a left-pinned reveal, false grows leftward from a right-pinned one.
    property bool horizontal: false
    property bool fromLeft: true
    property real contentWidth: 0
    // Iris mode: seed rect to grow out of (the bar's center pill) instead of unrolling from an
    // edge; startWidth > 0 lerps the width from it to the parent's, centred, with the height.
    property real startWidth: 0
    property real startHeight: 0
    readonly property bool iris: root.startWidth > 0
    readonly property real targetWidth: parent ? parent.width : 0
    // How long the Behavior on expand actually runs (animScale applied) — fold-then-hide
    // close timers must wait exactly this, not a fixed normal.
    readonly property int expandDuration: {
        if (!Settings.animationsEnabled)
            return 0;
        const s = Settings.islandAnimStyle;
        if (s === "ExpressiveFast")
            return Theme.anim.fastSpatial;
        if (s === "ExpressiveDefault")
            return Theme.anim.defaultSpatial;
        if (s === "ExpressiveSlow")
            return Theme.anim.slowSpatial;
        return Theme.anim.normal; // Standard + Emphasized both = normal
    }
    width: root.horizontal ? Math.max(0, root.expand * root.contentWidth)
         : root.iris ? root.startWidth + (root.targetWidth - root.startWidth) * root.expand
         : root.targetWidth
    // No `x` here on purpose — callers anchor or set their own. startHeight exists only
    // mid-unfold: a non-zero resting box is a live hover area (ControlCard would open itself).
    height: root.horizontal ? (parent ? parent.height : 0)
          : root.expand > 0 ? Math.max(0, root.startHeight + (root.contentHeight - root.startHeight) * root.expand)
          : 0
    clip: true
    opacity: Math.max(0, Math.min(1, root.expand * 1.2))
    scale: 0.96 + 0.04 * root.expand
    transformOrigin: root.horizontal ? (root.fromLeft ? Item.Left : Item.Right)
                                     : (Settings.barOrientation ? Item.Top : Item.Bottom)
    Behavior on expand {
        enabled: Settings.animationsEnabled
        Anim {
            type: {
                const s = Settings.islandAnimStyle;
                if (s === "Standard")
                    return Anim.Standard;
                if (s === "ExpressiveFast")
                    return Anim.FastSpatial;
                if (s === "ExpressiveDefault")
                    return Anim.DefaultSpatial;
                if (s === "ExpressiveSlow")
                    return Anim.SlowSpatial;
                return Anim.Emphasized;
            }
        }
    }
}
