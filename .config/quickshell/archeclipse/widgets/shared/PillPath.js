.pragma library

// Single source for the pill silhouette: PillBackground fills this path and PillBorderMeter
// strokes insets of it — duplicated arc math put the stroke a pixel off the fill's flare.

// Whole pill fill path: both concave screen-edge flares plus the rounded far corners.
// Coordinates are the canvas's own: x=0 is the left flare tip, body spans [f, f+bodyWidth].
function bodyPath(ctx, W, H, f, cr, topBar) {
    ctx.beginPath();
    if (topBar) {
        ctx.moveTo(0, 0);
        ctx.lineTo(W, 0);
        ctx.arc(W, f, f, -Math.PI / 2, Math.PI, true);
        ctx.lineTo(W - f, H - cr);
        ctx.arc(W - f - cr, H - cr, cr, 0, Math.PI / 2, false);
        ctx.lineTo(f + cr, H);
        ctx.arc(f + cr, H - cr, cr, Math.PI / 2, Math.PI, false);
        ctx.lineTo(f, f);
        ctx.arc(0, f, f, 0, -Math.PI / 2, true);
    } else {
        ctx.moveTo(0, H);
        ctx.lineTo(W, H);
        ctx.arc(W, H - f, f, Math.PI / 2, Math.PI, false);
        ctx.lineTo(W - f, cr);
        ctx.arc(W - f - cr, cr, cr, 0, -Math.PI / 2, true);
        ctx.lineTo(f + cr, 0);
        ctx.arc(f + cr, cr, cr, -Math.PI / 2, Math.PI, true);
        ctx.lineTo(f, H - f);
        ctx.arc(0, H - f, f, 0, Math.PI / 2, false);
    }
    ctx.closePath();
}

// Inset end stroke; frac trims it from the top, so a fill grows top to bottom on screen.
// The mirror flips the bottom bar, so only the top bar needs the reversed trace.
function strokeEnd(ctx, end, topBar, W, H, f, cr, d, tail, paint, frac) {
    const sx = 2 * Math.sqrt(Math.max(0, f * d));
    const sr = f + d;
    const r = Math.max(0.5, cr - d);
    const shoulderEnd = Math.atan2(d - f, sx);
    // Forward trace is tail -> corner -> side -> shoulder (bottom-up before the
    // mirror); the top bar reverses it so the fill starts at the top.
    const segments = topBar ? [
        { arc: true, cx: 0, cy: f, r: sr, a0: shoulderEnd, a1: 0, x0: sx, y0: d, x1: sr, y1: f },
        { arc: false, x0: f + d, y0: f, x1: f + d, y1: H - cr },
        { arc: true, cx: f + cr, cy: H - cr, r: r, a0: Math.PI, a1: Math.PI / 2, x0: f + d, y0: H - cr, x1: f + cr, y1: H - d },
        { arc: false, x0: f + cr, y0: H - d, x1: f + cr + Math.max(0, tail), y1: H - d }
    ] : [
        { arc: false, x0: f + cr + Math.max(0, tail), y0: H - d, x1: f + cr, y1: H - d },
        { arc: true, cx: f + cr, cy: H - cr, r: r, a0: Math.PI / 2, a1: Math.PI, x0: f + cr, y0: H - d, x1: f + d, y1: H - cr },
        { arc: false, x0: f + d, y0: H - cr, x1: f + d, y1: f },
        { arc: true, cx: 0, cy: f, r: sr, a0: 0, a1: shoulderEnd, x0: sr, y0: f, x1: sx, y1: d }
    ];
    let remaining = Math.max(0, Math.min(1, frac)) * endLength(H, f, cr, d, tail);
    ctx.save();
    ctx.translate(end === "right" ? W : 0, topBar ? 0 : H);
    ctx.scale(end === "right" ? -1 : 1, topBar ? 1 : -1);
    ctx.beginPath();
    if (remaining > 0) {
        ctx.moveTo(segments[0].x0, segments[0].y0);
        for (const s of segments) {
            if (remaining <= 0)
                break;
            const len = s.arc ? Math.abs(s.a1 - s.a0) * s.r : Math.hypot(s.x1 - s.x0, s.y1 - s.y0);
            if (len <= 0)
                continue;
            const take = Math.min(remaining, len);
            if (s.arc) {
                const dir = s.a1 >= s.a0 ? 1 : -1;
                ctx.arc(s.cx, s.cy, s.r, s.a0, s.a0 + dir * take / s.r, s.a1 < s.a0);
            } else {
                const k = take / len;
                ctx.lineTo(s.x0 + (s.x1 - s.x0) * k, s.y0 + (s.y1 - s.y0) * k);
            }
            remaining -= take;
        }
    }
    paint(ctx);
    ctx.restore();
}

// Arc-length of strokeEnd, so the trim above and its callers agree on the full run.
function endLength(H, f, cr, d, tail) {
    const sx = 2 * Math.sqrt(Math.max(0, f * d));
    const shoulder = (f + d) * Math.abs(Math.atan2(d - f, sx));
    const side = Math.max(0, (H - cr) - f);
    const corner = Math.max(0.5, cr - d) * Math.PI / 2;
    return shoulder + side + corner + Math.max(0, tail);
}
