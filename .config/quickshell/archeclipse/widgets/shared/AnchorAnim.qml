import QtQuick
import qs.theme

// Shared anchor-animation dispatcher (Caelestia AnchorAnim.qml port).
// Use inside `Transition { AnchorAnim {} }` for anchor re-targeting.
AnchorAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial
    }

    property int type: AnchorAnim.DefaultSpatial

    duration: {
        if (type < AnchorAnim.StandardSmall || type > AnchorAnim.SlowSpatial)
            return Theme.anim.defaultSpatial;

        if (type === AnchorAnim.FastSpatial)
            return Theme.anim.fastSpatial;
        if (type === AnchorAnim.DefaultSpatial)
            return Theme.anim.defaultSpatial;
        if (type === AnchorAnim.SlowSpatial)
            return Theme.anim.slowSpatial;

        const types = ["small", "normal", "large", "extraLarge"];
        const idx = type % 4; // 0-7 are the 4 standard/emphasized sizes
        return Theme.anim[types[idx]];
    }
    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        if (type === AnchorAnim.FastSpatial)
            return Theme.anim.expressiveFastSpatial;
        if (type === AnchorAnim.DefaultSpatial)
            return Theme.anim.expressiveDefaultSpatial;
        if (type === AnchorAnim.SlowSpatial)
            return Theme.anim.expressiveSlowSpatial;

        if (type >= AnchorAnim.StandardSmall && type <= AnchorAnim.StandardExtraLarge)
            return Theme.anim.standard;
        if (type >= AnchorAnim.EmphasizedSmall && type <= AnchorAnim.EmphasizedExtraLarge)
            return Theme.anim.emphasized;

        return Theme.anim.expressiveDefaultSpatial;
    }
}
