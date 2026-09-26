import QtQuick

// Shared ListView with wheel momentum via the native flick engine.
// Drop-in replacement for ListView: same API (model, delegate, spacing,
// currentIndex, orientation, ...), plus wheelScale tuning.
// Physics lives in SmoothWheelHandler — same engine as SmoothFlickable,
// single tuning point. ListView IS a Flickable, so flick() drives its own
// deceleration, bounds and overshoot.
//
// NOTE: do NOT wrap a ListView in a SmoothFlickable (nested flickables
// fight over gestures/contentY), and do NOT swap a ListView for a
// Flickable+Repeater (loses virtualization, currentIndex/keyboard nav).
ListView {
    id: root

    // Momentum tuning: callers can override.
    clip: true
    flickDeceleration: 1500
    maximumFlickVelocity: 1500

    // Per-notch gain: angleDelta.y=120 -> d=60 -> 60*scale velocity.
    property real wheelScale: 16

    SmoothWheelHandler {
        target: root
        wheelScale: root.wheelScale
    }
}
