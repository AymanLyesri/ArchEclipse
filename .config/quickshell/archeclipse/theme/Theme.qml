pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ArchEclipse theme — colors are read from the cwal (pywal) colors.scss
// generated from the active wallpaper, so switching palettes re-themes the
// shell live. Built-in fallbacks below apply until the file loads.
QtObject {
    id: root

    // --- raw palette (parsed from cwal colors.scss) ---
    property string background: "#08080c"
    property string foreground: "#aaabb2"
    property string color0: "#08080c"
    property string color1: "#493028"
    property string color2: "#413945"
    property string color3: "#4e505d"
    property string color4: "#917f7a"
    property string color5: "#b7b5ae"
    property string color6: "#d7af96"
    property string color7: "#aaabb2"
    property string color8: "#555765"

    // --- derived helpers ---
    readonly property real phi: 1.618
    readonly property real phiMin: phi - 1          // 0.618

    function mix(a: string, b: string, t: real): string {
        const pa = Qt.rgba(parseInt(a.slice(1, 3), 16) / 255, parseInt(a.slice(3, 5), 16) / 255, parseInt(a.slice(5, 7), 16) / 255, 1);
        const pb = Qt.rgba(parseInt(b.slice(1, 3), 16) / 255, parseInt(b.slice(3, 5), 16) / 255, parseInt(b.slice(5, 7), 16) / 255, 1);
        const c = Qt.rgba(pa.r + (pb.r - pa.r) * t, pa.g + (pb.g - pa.g) * t, pa.b + (pb.b - pa.b) * t, 1);
        return "#" + Math.round(c.r * 255).toString(16).padStart(2, "0") + Math.round(c.g * 255).toString(16).padStart(2, "0") + Math.round(c.b * 255).toString(16).padStart(2, "0");
    }
    function rgba(hex: string, alpha: real): string {
        const r = parseInt(hex.slice(1, 3), 16) / 255;
        const g = parseInt(hex.slice(3, 5), 16) / 255;
        const b = parseInt(hex.slice(5, 7), 16) / 255;
        return Qt.rgba(r, g, b, alpha).toString();
    }

    // --- semantic colors, derived from the raw palette ---
    readonly property string bg: background
    readonly property string fg: foreground
    readonly property string fgDim: rgba(foreground, 0.5)
    // Accent tracks a vibrant wallpaper color (not foreground, which pywal
    // keeps a near-constant gray) so it visibly shifts with the wallpaper.
    readonly property string accent: color5
    // Muted secondary text/icons.
    readonly property string muted: mix(foreground, color2, phiMin)
    // Surfaces: translucent base, opaque hover, accent-tinted active.
    readonly property string surface: rgba(background, Settings.uiOpacity)
    readonly property string surfaceHover: background
    readonly property string surfaceActive: mix(background, accent, 0.2)
    readonly property string border: rgba(foreground, 0.15)

    // --- typography / scale (settings-driven, like $FONT-SIZE / $SCALE) ---
    readonly property string fontFamily: "JetBrainsMono NFP"
    readonly property int fontSize: Settings.uiFontSize
    // Derived type scale — shared widgets must use these (or plain
    // fontSize) instead of hardcoded pixel numbers so a single
    // Settings.uiFontSize change re-themes every font at once.
    readonly property int fontSizeSmall: Math.max(8, fontSize - 1)
    readonly property int fontSizeCaption: Math.max(7, fontSize - 2)
    readonly property int fontSizeBadge: Math.max(7, fontSize - 3)
    readonly property int fontSizeLarge: fontSize + 2
    readonly property int scale: Settings.uiScale
    readonly property int radius: 10
    readonly property int cardRadius: 8
    readonly property int chipRadius: 6
    readonly property string accentFg: "white"
    readonly property int spacing: 8          // bar element spacing
    readonly property int sectionSpacing: 20  // between compact sections / expanded groups
    // Single source of truth for bar content height — every bar widget
    // (Clock, Battery, Volume, ...) binds to this instead of hardcoding
    // its own height, so all bar content stays the same height.
    readonly property int barContentHeight: 18

    // --- animation tokens (Material-3 expressive port, pure QML) ---
    // Durations in ms, multiplied by anim.scale. Curves are cubic-bezier
    // point lists for Easing.BezierSpline (6 values per segment).
    // Spatial = movement (slide/resize), Effects = fade/color.
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
        readonly property var standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property var standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property var emphasized: [0.05, 0, 0.1333, 0.06, 0.1667, 0.4, 0.2083, 0.82, 0.25, 1, 1, 1]
        readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property var expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property var expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property var expressiveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property var expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property var expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    }

    // Danger colors for destructive actions
    readonly property string danger: "#ff4444"
    readonly property string dangerBg: Qt.rgba(1.0, 0.26, 0.26, 0.1).toString()

    property FileView _cwal: FileView {
        path: `${Quickshell.env("HOME")}/.cache/cwal/colors.scss`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
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
        }
    }
}
