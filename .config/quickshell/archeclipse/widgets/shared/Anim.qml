import QtQuick
import qs.theme

// Shared number-animation dispatcher (Caelestia Anim.qml port, pure QML).
// Usage: `Behavior on x { Anim {} }` (defaults to DefaultSpatial),
// or targeted: `Anim { target: foo; property: "opacity"; to: 0; type: Anim.FastEffects }`.
NumberAnimation {
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
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    duration: {
        if (type < Anim.StandardSmall || type > Anim.SlowEffects)
            return Theme.anim.normal;

        if (type === Anim.FastSpatial)
            return Theme.anim.fastSpatial;
        if (type === Anim.DefaultSpatial)
            return Theme.anim.defaultSpatial;
        if (type === Anim.SlowSpatial)
            return Theme.anim.slowSpatial;
        if (type === Anim.FastEffects)
            return Theme.anim.fastEffects;
        if (type === Anim.DefaultEffects)
            return Theme.anim.defaultEffects;
        if (type === Anim.SlowEffects)
            return Theme.anim.slowEffects;

        const types = ["small", "normal", "large", "extraLarge"];
        const idx = type % 4; // 0-7 are the 4 standard/emphasized sizes
        return Theme.anim[types[idx]];
    }
    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        if (type === Anim.FastSpatial)
            return Theme.anim.expressiveFastSpatial;
        if (type === Anim.DefaultSpatial)
            return Theme.anim.expressiveDefaultSpatial;
        if (type === Anim.SlowSpatial)
            return Theme.anim.expressiveSlowSpatial;
        if (type === Anim.FastEffects)
            return Theme.anim.expressiveFastEffects;
        if (type === Anim.DefaultEffects)
            return Theme.anim.expressiveDefaultEffects;
        if (type === Anim.SlowEffects)
            return Theme.anim.expressiveSlowEffects;

        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return Theme.anim.emphasized;
        return Theme.anim.standard;
    }
}
