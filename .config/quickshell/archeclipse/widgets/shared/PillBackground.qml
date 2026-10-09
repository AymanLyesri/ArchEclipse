import QtQuick
import qs.theme

// Single-fill pill background: body rect + both concave screen-edge
// flares traced as ONE path with ONE fill, so no internal seam can
// appear. (Two abutting AA'd shapes leave a wallpaper hairline at
// fractional positions; two overlapping ones double-blend because
// Theme.surface is translucent.) Replaces Rectangle-bg + InvertedCorner
// pairs for the main bar pill and the left/right side pills.
Canvas {
    id: root
    property int bodyWidth: 100
    property int bodyHeight: 32
    property int flare: Theme.radius
    property int corner: Theme.radius
    // true = pill touches the top screen edge (straight top, rounded
    // bottom + top flares); false = mirrored for a bottom bar.
    property bool topBar: true
    property color color: Theme.surface
    // Recolor one outer flare to match adjacent content (e.g. the
    // island sidebar rail): the sliver is overpainted with its own
    // color after the body fill. Defaults off — overpainting the SAME
    // translucent color would double-blend and darken the sliver.
    property bool leftFlare: false
    property color leftFlareColor: Theme.bg
    property bool rightFlare: false
    property color rightFlareColor: Theme.bg

    width: bodyWidth + flare * 2
    height: bodyHeight

    onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
            return;
        const f = root.flare;
        const bw = root.bodyWidth;
        const bh = root.bodyHeight;
        if (f <= 0 || bw <= 0 || bh <= 0)
            return;
        const W = bw + f * 2;
        const cr = Math.min(root.corner, bw / 2, bh / 2);
        if (cr <= 0)
            return;
        ctx.reset();
        ctx.fillStyle = root.color;
        ctx.beginPath();
        if (root.topBar) {
            ctx.moveTo(0, 0);
            ctx.lineTo(W, 0);
            ctx.arc(W, f, f, -Math.PI / 2, Math.PI, true);
            ctx.lineTo(W - f, bh - cr);
            ctx.arc(W - f - cr, bh - cr, cr, 0, Math.PI / 2, false);
            ctx.lineTo(f + cr, bh);
            ctx.arc(f + cr, bh - cr, cr, Math.PI / 2, Math.PI, false);
            ctx.lineTo(f, f);
            ctx.arc(0, f, f, 0, -Math.PI / 2, true);
        } else {
            ctx.moveTo(0, bh);
            ctx.lineTo(W, bh);
            ctx.arc(W, bh - f, f, Math.PI / 2, Math.PI, false);
            ctx.lineTo(W - f, cr);
            ctx.arc(W - f - cr, cr, cr, 0, -Math.PI / 2, true);
            ctx.lineTo(f + cr, 0);
            ctx.arc(f + cr, cr, cr, -Math.PI / 2, Math.PI, true);
            ctx.lineTo(f, bh - f);
            ctx.arc(0, bh - f, f, 0, Math.PI / 2, false);
        }
        ctx.closePath();
        ctx.fill();
        // Outer-flare recolor slivers: same geometry as the body's flare
        // region, painted over it. The shared straight edge becomes a
        // deliberate two-color boundary (like any card edge), never a
        // wallpaper hairline or a double-blend overlap.
        if (root.leftFlare) {
            ctx.fillStyle = root.leftFlareColor;
            ctx.beginPath();
            if (root.topBar) {
                ctx.moveTo(0, 0);
                ctx.lineTo(f, 0);
                ctx.lineTo(f, f);
                ctx.arc(0, f, f, 0, -Math.PI / 2, true);
            } else {
                ctx.moveTo(0, bh);
                ctx.lineTo(f, bh);
                ctx.lineTo(f, bh - f);
                ctx.arc(0, bh - f, f, 0, Math.PI / 2, false);
            }
            ctx.closePath();
            ctx.fill();
        }
        if (root.rightFlare) {
            ctx.fillStyle = root.rightFlareColor;
            ctx.beginPath();
            if (root.topBar) {
                ctx.moveTo(W - f, 0);
                ctx.lineTo(W, 0);
                ctx.arc(W, f, f, -Math.PI / 2, Math.PI, true);
            } else {
                ctx.moveTo(W - f, bh);
                ctx.lineTo(W, bh);
                ctx.arc(W, bh - f, f, Math.PI / 2, Math.PI, false);
            }
            ctx.closePath();
            ctx.fill();
        }
    }
    onVisibleChanged: {
        if (visible)
            requestPaint();
    }
    onBodyWidthChanged: requestPaint()
    onBodyHeightChanged: requestPaint()
    onFlareChanged: requestPaint()
    onCornerChanged: requestPaint()
    onTopBarChanged: requestPaint()
    onColorChanged: requestPaint()
    onLeftFlareChanged: requestPaint()
    onLeftFlareColorChanged: requestPaint()
    onRightFlareChanged: requestPaint()
    onRightFlareColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
