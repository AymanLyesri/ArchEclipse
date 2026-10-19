import QtQuick
import qs.theme
import qs.widgets.shared

// Shared unfold body clip. Caller sets `expand` 0->1 on creation
// and passes the body height as `contentHeight`; the body itself goes
// in as a child (anchored top, like the inline bodyClips this replaces).
// Easing follows Settings.islandAnimStyle (Settings > Animations).
Item {
    id: root
    property real expand: 0
    property real contentHeight: 0
    // Horizontal variant (side-pill rows: pieces push their Row smoothly
    // because the caller binds its width to the clip's own). fromLeft=true
    // grows rightward from a left-pinned reveal; false grows leftward from
    // a right-pinned one.
    property bool horizontal: false
    property bool fromLeft: true
    property real contentWidth: 0
    // How long the Behavior on expand actually runs (same mapping as the
    // Anim type below, with animScale already applied) — fold-then-hide
    // close timers must wait exactly this long, not a fixed normal.
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
    width: root.horizontal ? Math.max(0, root.expand * root.contentWidth) : (parent ? parent.width : 0)
    height: root.horizontal ? (parent ? parent.height : 0) : Math.max(0, root.expand * root.contentHeight)
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
