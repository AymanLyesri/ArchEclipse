import QtQuick

// Shared wheel-momentum physics for all smooth scrollers: attach to any Flickable-derived type
// (`SmoothWheelHandler { target: root }`); wheelScale mirrors SmoothFlickable.wheelScale.
WheelHandler {
    id: root

    required property Flickable target
    property real wheelScale: 16

    property real velX: 0
    property real velY: 0
    property double lastT: 0

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        // Nested scrollers: when this target has nothing to scroll (or is at the edge), do NOT
        // accept — always accepting traps the wheel and the outer panel feels stuck.
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
        // Time-based decay: smooth devices send tiny deltas at high frequency, which an
        // event-count decay crushes; velocity dies within ~120ms after input stops.
        const now = Date.now();
        const dt = lastT > 0 ? now - lastT : 16;
        lastT = now;
        const decay = Math.exp(-dt / 180);
        // flick() takes finger velocity, so positive wheel deltas map directly (a minus sign
        // inverts it). Per axis take the channel carrying more — hi-res devices report both.
        const ax = event.angleDelta.x / 2;
        const ay = event.angleDelta.y / 2;
        let dx = Math.abs(event.pixelDelta.x) >= Math.abs(ax) ? event.pixelDelta.x : ax;
        let dy = Math.abs(event.pixelDelta.y) >= Math.abs(ay) ? event.pixelDelta.y : ay;
        // Horizontal-only targets never see vertical wheel deltas, so route the orthogonal axis
        // into the scrollable one (and back for vertical-only); other directions keep both.
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
