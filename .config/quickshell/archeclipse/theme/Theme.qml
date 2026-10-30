pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ArchEclipse theme: the greeter prefers its system palette, the desktop reads the
// cwal (pywal) colors.scss of the active wallpaper; built-in fallbacks until it loads.
QtObject {
    id: root

    // --- raw palette (parsed from cwal colors.scss) ---
    property string background: "#08080c"
    property string foreground: "#aaabb2"
    // Vivid, legible UI accent from the coloreclipse binary: cwal's color5 is only a
    // prominence rank and often too dim to read, so it is a fallback for old palettes.
    property string rawAccent: "#b7b5ae"
    property string color0: "#08080c"
    property string color1: "#493028"
    property string color2: "#413945"
    property string color3: "#4e505d"
    property string color4: "#917f7a"
    property string color5: "#b7b5ae"
    property string color6: "#d7af96"
    property string color7: "#aaabb2"
    property string color8: "#555765"
    // Extended slots (color9..15) arrive from newer wallpaper palettes only;
    // older palettes leave these "" and every band-scan skips empty slots.
    property string color9: ""
    property string color10: ""
    property string color11: ""
    property string color12: ""
    property string color13: ""
    property string color14: ""
    property string color15: ""
    // True when at least one extended slot was really parsed from a palette.
    property bool _hasExtended: false


    // --- derived helpers ---
    readonly property real phi: 1.618
    readonly property real phiMin: phi - 1          // 0.618

    function mix(a: string, b: string, t: real): string {
        const pa = toRgb(a);
        const pb = toRgb(b);
        if (!pa || !pb)
            return "" + a;
        const c = Qt.rgba(pa[0] / 255 + (pb[0] / 255 - pa[0] / 255) * t, pa[1] / 255 + (pb[1] / 255 - pa[1] / 255) * t, pa[2] / 255 + (pb[2] / 255 - pa[2] / 255) * t, 1);
        return "#" + Math.round(c.r * 255).toString(16).padStart(2, "0") + Math.round(c.g * 255).toString(16).padStart(2, "0") + Math.round(c.b * 255).toString(16).padStart(2, "0");
    }
    // Alpha compose, tolerant of "#rrggbb", "#rgb" and Qt's internal "#aarrggbb" form
    // (a `color` argument coerces to 8 digits, so callers may pass e.g. `danger`).
    function rgba(hex: string, alpha: real): string {
        const p = toRgb(hex);
        if (!p)
            return "transparent";
        return Qt.rgba(p[0] / 255, p[1] / 255, p[2] / 255, alpha).toString();
    }

    // --- colour maths (palette-load-time only, same rule as mix/rgba) ---
    // Accepts "#rrggbb", "#fff" and Qt's "#aarrggbb"; the alpha half is ignored.
    function toRgb(c) {
        const h = ("" + c).replace("#", "");
        const g = h.length === 8 ? h.slice(2) : h;
        const e = g.length === 3 ? g[0] + g[0] + g[1] + g[1] + g[2] + g[2] : g;
        if (e.length !== 6)
            return null;
        const n = parseInt(e, 16);
        if (isNaN(n))
            return null;
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    }
    function relLum(c): real {
        const p = toRgb(c);
        if (!p)
            return 0;
        const lin = v => {
            const x = v / 255;
            return x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
        };
        return 0.2126 * lin(p[0]) + 0.7152 * lin(p[1]) + 0.0722 * lin(p[2]);
    }
    function contrastRatio(a, b): real {
        const la = relLum(a);
        const lb = relLum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }
    // Hex of an [r,g,b] byte triplet.
    function _rgbHex(p) {
        const h = v => Math.round(Math.min(255, Math.max(0, v))).toString(16).padStart(2, "0");
        return "#" + h(p[0]) + h(p[1]) + h(p[2]);
    }
    // Brighten `ink` until it clears `floor` on `bg` keeping hue/saturation (desaturate
    // only when V saturates): mixing toward the fg turned red into gray (#493028 -> #807676).
    function contrastFix(ink, bg, floor): string {
        if (contrastRatio(ink, bg) >= floor)
            return "" + ink;
        const rgb = toRgb(ink);
        if (!rgb)
            return "" + ink;
        const v0 = Math.max(0.0001, _hsv(ink)[2]);
        const up = relLum(bg) < 0.5;
        let v = v0;
        for (let i = 0; i < 20; i++) {
            v = up ? Math.min(1, v + 0.06) : Math.max(0, v - 0.06);
            const k = v / v0;
            const cand = _rgbHex([rgb[0] * k, rgb[1] * k, rgb[2] * k]);
            if (contrastRatio(cand, bg) >= floor)
                return cand;
            if (v === 1 || v === 0)
                break;
        }
        const pole = up ? "#ffffff" : "#000000";
        let cur = "" + ink;
        for (let i = 0; i < 24; i++) {
            if (contrastRatio(cur, bg) >= floor)
                return cur;
            cur = mix(cur, pole, 0.08);
        }
        return cur;
    }
    // Readable-of-two over a background: whoever wins contrast. Ties pick a.
    function pickOn(bg, a, b): string {
        return contrastRatio(a, bg) >= contrastRatio(b, bg) ? ("" + a) : ("" + b);
    }
    // Ratio-based type step (18/20/22/24/32/48/56 at uiFontSize 12 map to
    // m = 1.5/1.67/1.83/2/2.67/4/4.67 exactly, and rescale with the setting).
    function fs(m: real): int {
        return Math.round(fontSize * m);
    }

    // --- semantic derivation (mirror of tools/style_audit.py --palette) ---
    function _hsv(c) {
        const p = toRgb(c);
        if (!p)
            return [0, 0, 0];
        const r = p[0] / 255;
        const g = p[1] / 255;
        const b = p[2] / 255;
        const mx = Math.max(r, g, b);
        const mn = Math.min(r, g, b);
        const d = mx - mn;
        let h = 0;
        if (d > 0) {
            if (mx === r)
                h = ((g - b) / d) % 6;
            else if (mx === g)
                h = (b - r) / d + 2;
            else
                h = (r - g) / d + 4;
        }
        h = (h * 60) % 360;
        if (h < 0)
            h += 360;
        return [h, mx === 0 ? 0 : d / mx, mx];
    }
    function _slotHex(i) {
        switch (i) {
        case 1: return color1;
        case 2: return color2;
        case 3: return color3;
        case 4: return color4;
        case 5: return color5;
        case 6: return color6;
        case 7: return color7;
        case 8: return color8;
        case 9: return color9;
        case 10: return color10;
        case 11: return color11;
        case 12: return color12;
        case 13: return color13;
        case 14: return color14;
        case 15: return color15;
        }
        return "";
    }
    // Highest-contrast slot whose hue lands in `band`: empty, near-gray and near-black
    // slots are skipped, since a warm gray would ship a taupe "danger" (measured #917f7a).
    function _bestHue(band, minSat) {
        const floor = minSat === undefined ? 0.15 : minSat;
        let best = null;
        for (let i = 1; i <= 15; i++) {
            const c = _slotHex(i);
            if (!c || typeof c !== "string" || c.length !== 7)
                continue;
            const hsv = _hsv(c);
            if (hsv[1] < floor || hsv[2] < 0.12)
                continue;
            let inBand = false;
            for (let j = 0; j < band.length; j++) {
                if (hsv[0] >= band[j][0] && hsv[0] <= band[j][1]) {
                    inBand = true;
                    break;
                }
            }
            if (!inBand)
                continue;
            const score = contrastRatio(c, background);
            if (!best || score > best[0])
                best = [score, c];
        }
        return best ? best[1] : "";
    }
    // Danger: a genuinely-red saturated slot first (slot numbers are NOT hue-loyal in
    // cwal), then color14 if it is itself red, then #ff4444 — all contrast-fixed to 4.5:1.
    function _deriveDanger(): string {
        let ink = _bestHue([[345.0, 360.0], [0.0, 15.0]], 0.30);
        if (!ink && color14 && typeof color14 === "string" && color14.length === 7) {
            const h = _hsv(color14);
            const redish = (h[0] >= 330 || h[0] <= 25) && h[1] >= 0.30 && h[2] >= 0.12;
            if (redish)
                ink = color14;
        }
        if (!ink)
            ink = "#ff4444";
        return contrastFix(ink, background, 4.5);
    }
    // Success: green band, $color22-ish fallback when the palette has none.
    function _deriveSuccess(): string {
        const ink = _bestHue([[90.0, 170.0]]);
        if (!ink)
            return contrastFix("#22c55e", background, 4.5);
        return contrastFix(ink, background, 4.5);
    }
    // Chart ramp: three hue-separated (>=30deg) slots contrast-fixed to 3:1, mirroring
    // tools/style_audit.py --palette order; near-blacks are excluded (they read as ink).
    function _charts() {
        const cands = [];
        for (let i = 1; i <= 15; i++) {
            const c = _slotHex(i);
            if (!c || typeof c !== "string" || c.length !== 7)
                continue;
            const hsv = _hsv(c);
            if (hsv[1] < 0.15 || hsv[2] < 0.25)
                continue;
            const fixed = contrastFix(c, background, 3.0);
            if (contrastRatio(fixed, background) < 3.0)
                continue;
            cands.push([contrastRatio(fixed, background), _hsv(fixed)[0], fixed]);
        }
        cands.sort((a, b) => b[0] - a[0]);
        const used = [];
        const out = [];
        for (let k = 0; k < cands.length && out.length < 3; k++) {
            let far = true;
            for (let u = 0; u < used.length; u++) {
                const d = Math.abs(cands[k][1] - used[u]) % 360;
                if (Math.min(d, 360 - d) < 30) {
                    far = false;
                    break;
                }
            }
            if (far) {
                out.push(cands[k][2]);
                used.push(cands[k][1]);
            }
        }
        const ramp = [accent, mix(accent, foreground, 0.35), mix(accent, foreground, 0.65)];
        while (out.length < 3)
            out.push(contrastFix(ramp[out.length], background, 3.0));
        return out;
    }

    // --- semantic colors, derived from the raw palette ---
    // `background` is used as-is: the binary already keeps light mode at luminance >= 0.92.
    readonly property string bg: background
    readonly property string fg: foreground
    readonly property string fgDim: rgba(foreground, 0.7)
    // The binary ranks the six palette accents by contrast x saturation and enforces a
    // WCAG floor; cwal's color5 is only a prominence rank and is often too dim.
    readonly property string accent: rawAccent
    // Muted secondary text/icons.
    readonly property string muted: mix(foreground, color2, phiMin)
    // Surfaces: translucent base, opaque hover, accent-tinted active.
    readonly property string surface: rgba(bg, Settings.uiOpacity)
    readonly property string surfaceHover: bg
    readonly property string surfaceActive: mix(bg, accent, 0.2)
    readonly property string border: rgba(foreground, 0.15)

    // --- status / data-viz tokens (see helpers below; floors: text 4.5:1,
    // non-text 3:1, both validated by tools/style_audit.py --palette) ---
    readonly property color danger: _deriveDanger()
    readonly property color dangerBg: rgba(danger, 0.12)
    // Solid critical card fill: danger is TEXT-grade, so using it as a surface inverts
    // the theme (pale salmon cards) — blend it back toward the background.
    readonly property color dangerSurface: mix(danger, background, 0.45)
    // Ink for text on the SOLID critical card: the best of accentFg/foreground over
    // dangerSurface, contrast-fixed to 4.5:1 (best-of-two alone measured 3.8:1).
    readonly property color criticalFg: contrastFix(pickOn(dangerSurface, "#ffffff", foreground), dangerSurface, 4.5)
    readonly property color success: _deriveSuccess()
    readonly property color chart1: _charts()[0]
    readonly property color chart2: _charts()[1]
    readonly property color chart3: _charts()[2]
    // Track wash for bars/progress rails.
    readonly property color track: rgba(foreground, 0.15)
    // Scrims over wallpaper imagery (lockscreen, fullscreen viewers).
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.45)
    readonly property color scrimHeavy: Qt.rgba(0, 0, 0, 0.6)
    readonly property color scrimSoft: Qt.rgba(0, 0, 0, 0.2)
    // Fixed inks over unpredictable imagery (thumbnails/photos) and their photo-frame
    // background. Deliberate constants: their background is never a palette surface.
    readonly property color onMediaInk: "#ffffff"
    readonly property color onMediaBg: Qt.rgba(0, 0, 0, 1)
    // Inks over the weather plate (services/Weather.codeInfo backgrounds —
    // fixed dark blues year-round, never derived from the wallpaper).
    readonly property color onPlateInk: "#E0E0E0"
    readonly property color onPlateInkDim: "#CFCFCF"

    // --- typography / scale (settings-driven, like $FONT-SIZE / $SCALE) ---
    readonly property string fontFamily: "JetBrainsMono NFP"
    readonly property int fontSize: Settings.uiFontSize
    // Derived type scale — use these (or plain fontSize) instead of hardcoded pixels so
    // one Settings.uiFontSize change re-themes every font at once.
    readonly property int fontSizeSmall: Math.max(8, fontSize - 1)
    readonly property int fontSizeCaption: Math.max(7, fontSize - 2)
    readonly property int fontSizeBadge: Math.max(7, fontSize - 3)
    readonly property int fontSizeLarge: fontSize + 2
    readonly property int radius: Settings.uiRadius
    readonly property string accentFg: "white"
    readonly property int spacing: Settings.uiSpacing   // bar element spacing
    // The ONE padding token: content inset for cards, panels and island bodies. Padings
    // of 8+ bind this; smaller values are optical micro-adjustments and stay literal.
    readonly property int pad: Settings.uiPad
    // Single source for bar content height — every bar widget binds this instead of
    // hardcoding its own, so all bar content stays the same height.
    readonly property int barContentHeight: 18
    // Height of the chained status pills (weather/media/recording): deliberately taller
    // than barContentHeight so the three read as one family, centered in the bar band.
    readonly property int sidePillHeight: 24
    // Gap between the main pill and the chained side pills; also the matching
    // leftPush/rightPush offset, so the x-chain and its mirror cannot drift apart.
    readonly property int sidePillMargin: 8
    // The ONE inset between a bar pill's edge and its island content: wrappers add no
    // outer margin and bodies pad no root layout (they once stacked to 8–17px).
    readonly property int islandPad: 8

    // Three nameable emphasis levels for opacity literals.
    readonly property QtObject opacity: QtObject {
        property real disabled: 0.4
        property real hoverDim: 0.7
        property real soft: 0.85
    }

    // --- animation tokens (Material-3 expressive port, pure QML) ---
    // ms durations x anim.scale; spatial = movement, effects = fade/color.
    readonly property QtObject anim: QtObject {
        // Global motion gate: disabling animations snaps every Theme.anim
        // duration to 0; otherwise durations scale by Settings.animScale.
        property real scale: Settings.animationsEnabled ? Settings.animScale : 0
        // standard durations
        readonly property int small: Math.round(200 * scale)
        readonly property int normal: Math.round(400 * scale)
        readonly property int large: Math.round(600 * scale)
        readonly property int extraLarge: Math.round(1000 * scale)
        // expressive durations
        readonly property int fastSpatial: Math.round(350 * scale)
        readonly property int defaultSpatial: Math.round(500 * scale)
        readonly property int slowSpatial: Math.round(650 * scale)
        readonly property int fastEffects: Math.round(150 * scale)
        readonly property int defaultEffects: Math.round(200 * scale)
        readonly property int slowEffects: Math.round(300 * scale)
        // easing curves (BezierSpline point lists)
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var emphasized: [0.05, 0, 0.1333, 0.06, 0.1667, 0.4, 0.2083, 0.82, 0.25, 1, 1, 1]
        readonly property var expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property var expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property var expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property var expressiveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property var expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property var expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    }

    readonly property string _greeterPalettePath: String(Qt.resolvedUrl("../colors.scss")).replace(/^file:\/\//, "")
    property bool _greeterPaletteLoaded: false

    function applyPalette(t: string) {
        const grab = (name, fb) => {
            const m = t.match(new RegExp("\\$" + name + "\\s*:\\s*(#[0-9a-fA-F]{6})"));
            return m ? m[1] : fb;
        };
        root.background = grab("background", "#08080c");
        root.foreground = grab("foreground", "#aaabb2");
        root.color0 = grab("color0", "#08080c");
        root.color1 = grab("color1", "#493028");
        root.color2 = grab("color2", "#413945");
        root.color3 = grab("color3", "#4e505d");
        root.color4 = grab("color4", "#917f7a");
        root.color5 = grab("color5", "#b7b5ae");
        root.color6 = grab("color6", "#d7af96");
        root.color7 = grab("color7", "#aaabb2");
        root.color8 = grab("color8", "#555765");
        // Extended slots: missing entries stay "" (band scans skip them).
        let extended = false;
        for (let i = 9; i <= 15; i++) {
            const v = grab("color" + i, "");
            root["color" + i] = v;
            if (v !== "")
                extended = true;
        }
        root._hasExtended = extended;
    }

    // The greeter mirror carries its own palette next to shell.qml; prefer
    // it when present, while the desktop keeps its user palette.
    property FileView _greeterPalette: FileView {
        path: root._greeterPalettePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root._greeterPaletteLoaded = true;
            root.applyPalette(text());
        }
    }

    property FileView _cwal: FileView {
        path: `${Quickshell.env("HOME")}/.cache/coloreclipse/colors.scss`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // The greeter mirror is the palette owner once loaded; skip the
            // whole cwal parse. Before that point this file is the source.
            if (root._greeterPaletteLoaded)
                return;
            root.applyPalette(text());
            const t = text();
            const grab = (name, fb) => {
                const m = t.match(new RegExp("\\$" + name + "\\s*:\\s*(#[0-9a-fA-F]{6})"));
                return m ? m[1] : fb;
            };
            root.background = grab("background", "#08080c");
            root.foreground = grab("foreground", "#aaabb2");
            root.rawAccent = grab("accent", "#b7b5ae");
            root.color0 = grab("color0", "#08080c");
            root.color1 = grab("color1", "#493028");
            root.color2 = grab("color2", "#413945");
            root.color3 = grab("color3", "#4e505d");
            root.color4 = grab("color4", "#917f7a");
            root.color5 = grab("color5", "#b7b5ae");
            root.color6 = grab("color6", "#d7af96");
            root.color7 = grab("color7", "#aaabb2");
            root.color8 = grab("color8", "#555765");
            // Extended slots: same null-tolerant idiom as applyPalette.
            let extended = false;
            for (let i = 9; i <= 15; i++) {
                const v = grab("color" + i, "");
                root["color" + i] = v;
                if (v !== "")
                    extended = true;
            }
            root._hasExtended = extended;
        }
    }
}
