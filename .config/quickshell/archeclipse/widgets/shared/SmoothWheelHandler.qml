import QtQuick

// Shared wheel-momentum physics for all smooth scrollers.
// Attach to any Flickable-derived type (Flickable, ListView, GridView):
// feeds wheel deltas into flick() so the native deceleration,
// bounds and overshoot do the gliding.
//
//   SmoothWheelHandler { target: root }
//
// target: the Flickable to drive. wheelScale mirrors
// SmoothFlickable.wheelScale (angleDelta.y=120 -> d=60 -> 60*scale).
WheelHandler {
    id: root

    required property Flickable target
    property real wheelScale: 16

    property real velX: 0
    property real velY: 0
    property double lastT: 0

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        // Nested scrollers (e.g. NotificationHistory's inner list inside
        // the right island's outer scroll): if this target has nothing to scroll
        // or is already at the edge in the wheel direction, do NOT accept —
        // let the event bubble to the outer Flickable. Always accepting
        // traps the wheel: the inner list eats it while stationary and the
        // outer panel feels stuck ("can't scroll in the category").
        const dy0 = (event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2);
        const dx0 = (event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 2);
        const dir = target.flickableDirection;
        const horizontalOnly = (dir === Flickable.HorizontalFlick);
        const verticalOnly = (dir === Flickable.VerticalFlick);
        // Effective scroll deltas after the axis remap applied below.
        let edy = verticalOnly && !horizontalOnly ? dy0 + dx0 : dy0;
        let edx = horizontalOnly && !verticalOnly ? dx0 + dy0 : dx0;
        // Vertical flick() polarity: positive velocity moves content
        // down (contentY decreases). Wheel-up deltas are positive.
        const maxY = Math.max(0, target.contentHeight - target.height);
        const maxX = Math.max(0, target.contentWidth - target.width);
        const canUp = target.contentY > 0;
        const canDown = target.contentY < maxY;
        const canLeft = target.contentX > 0;
        const canRight = target.contentX < maxX;
        const wantsV = (edy > 0 && canUp) || (edy < 0 && canDown);
        const wantsH = (edx > 0 && canLeft) || (edx < 0 && canRight);
        const canScrollV = !(verticalOnly && !horizontalOnly) || maxY > 0;
        const canScrollH = !(horizontalOnly && !verticalOnly) || maxX > 0;
        const handlesV = verticalOnly && !horizontalOnly ? (maxY > 0 && wantsV) : (canScrollV && wantsV);
        const handlesH = horizontalOnly && !verticalOnly ? (maxX > 0 && wantsH) : (canScrollH && wantsH);
        if ((!handlesV && !handlesH) || !target.interactive) {
            event.accepted = false;
            return;
        }
        // Time-based decay: smooth-scroll devices send tiny deltas at
        // high frequency, which an event-count decay crushes to a crawl.
        // Velocity accumulates across rapid events and dies within ~120ms
        // once input stops, so stale speed never leaks into the next gesture.
        const now = Date.now();
        const dt = lastT > 0 ? now - lastT : 16;
        lastT = now;
        const decay = Math.exp(-dt / 180);
        // NOTE: flick() takes finger velocity, not content velocity:
        // positive moves content down/right (contentY/X decreases, i.e.
        // scroll up/left), matching positive wheel deltas (wheel up).
        // A minus sign here inverts the scroll direction.
        // Hi-res devices report BOTH channels at once with wildly different
        // scales (e.g. pixelDelta=(0,-1) alongside angleDelta=(0,-9)): a
        // pixel-first pick discards ~90% of the signal and the flick never
        // builds momentum. Take whichever channel carries more per axis —
        // classic wheels (pixel 0), touchpads (angle 0) and hi-res (both)
        // all resolve to their live signal.
        const ax = event.angleDelta.x / 2;
        const ay = event.angleDelta.y / 2;
        let dx = Math.abs(event.pixelDelta.x) >= Math.abs(ax) ? event.pixelDelta.x : ax;
        let dy = Math.abs(event.pixelDelta.y) >= Math.abs(ay) ? event.pixelDelta.y : ay;
        // Horizontal-only targets (e.g. wallpaper strip with
        // flickableDirection: HorizontalFlick) never see vertical wheel
        // deltas — a plain mouse wheel would do nothing. Route the
        // orthogonal axis into the scrollable one so the wheel glides.
        // Same in reverse for vertical-only targets (shift+wheel yields
        // angleDelta.x, which would otherwise be dropped). Only explicit
        // single-axis directions remap; anything else keeps both axes.
        // (dir/horizontalOnly/verticalOnly are declared at the top of
        // this handler so the edge check above shares them.)
        if (horizontalOnly && !verticalOnly) {
            dx = dx + dy;
            dy = 0;
            velY = 0;
        } else if (verticalOnly && !horizontalOnly) {
            dy = dy + dx;
            dx = 0;
            velX = 0;
        }
        velX = Math.max(-target.maximumFlickVelocity, Math.min(target.maximumFlickVelocity, velX * decay + dx * wheelScale));
        velY = Math.max(-target.maximumFlickVelocity, Math.min(target.maximumFlickVelocity, velY * decay + dy * wheelScale));
        if (dx === 0 && dy === 0) {
            // Trailing scroll-end event: flicking here dies with the
            // gesture, so re-flick once dispatch finishes and coast.
            const vx = velX;
            const vy = velY;
            Qt.callLater(() => {
                return target.flick(vx, vy);
            });
        } else {
            target.flick(velX, velY);
        }
        event.accepted = true;
    }
}
