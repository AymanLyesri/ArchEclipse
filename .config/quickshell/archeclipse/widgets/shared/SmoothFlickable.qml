import QtQuick

// Shared Flickable with wheel momentum via the native flick engine.
// Flickable only builds momentum from drag-release flicks (no
// wheel-momentum property exists), so wheel deltas are fed into flick()
// and its own deceleration, bounds and overshoot do the gliding.
//
// Usage: drop-in replacement for Flickable AND ScrollView+Column.
// All Flickable properties (contentWidth/Height, anchors, Layout.*,
// flickableDirection, ScrollBar.vertical, onContentHeightChanged, ...)
// pass through. Physics lives in SmoothWheelHandler so the ListView
// wrapper stays in sync from a single tuning point.
//
// ScrollView migration pattern:
//   ScrollView { id: s; Column { width: s.availableWidth } }
// becomes:
//   SmoothFlickable { id: s; contentWidth: s.width; contentHeight: col.height
//       Column { id: col; width: s.width } }
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
