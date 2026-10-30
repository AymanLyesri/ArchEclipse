import QtQuick

// Shared Flickable with wheel momentum through the native flick engine: wheel deltas go into
// flick(), so its deceleration, bounds and overshoot do the gliding. Physics: SmoothWheelHandler.
Flickable {
    id: root

    // Momentum tuning: callers can override (e.g. BooruGrid pins
    // maximumFlickVelocity lower for a slower feel).
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
