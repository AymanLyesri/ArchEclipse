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
