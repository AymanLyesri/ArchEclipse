import QtQuick
import qs.theme

// Shared color-animation preset (Caelestia CAnim.qml port).
// Usage: `Behavior on color { CAnim {} }`.
ColorAnimation {
    duration: Theme.anim.slowEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.anim.expressiveSlowEffects
}
