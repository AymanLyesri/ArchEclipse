import QtQuick

// Shared ListView with wheel momentum via the native flick engine (same API plus wheelScale).
// Never wrap a ListView in a SmoothFlickable, and never swap it for a Flickable+Repeater.
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
