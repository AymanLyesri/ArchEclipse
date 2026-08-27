pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ArchEclipse theme — mirrors scss/colors.scss + scss/constants.scss.
// Colors are read from the same cwal (pywal) colors.scss the AGS bar uses,
// so switching wallpaper palettes affects both bars identically.
// Fallback = scss/defaultColors.scss.
QtObject {
    id: root

    // --- raw palette (parsed from cwal colors.scss) ---
    property string background: "#08080c"
    property string foreground: "#aaabb2"
    property string color1: "#493028"
    property string color2: "#413945"
    property string color3: "#4e505d"

    // --- derived, mirroring colors.scss ---
    readonly property real phi: 1.618
    readonly property real phiMin: phi - 1          // 0.618
    readonly property real phiPercentage: phiMin * 100

    function mix(a: string, b: string, t: real): string {
        const pa = Qt.rgba(parseInt(a.slice(1,3),16)/255, parseInt(a.slice(3,5),16)/255, parseInt(a.slice(5,7),16)/255, 1);
        const pb = Qt.rgba(parseInt(b.slice(1,3),16)/255, parseInt(b.slice(3,5),16)/255, parseInt(b.slice(5,7),16)/255, 1);
        const c = Qt.rgba(pa.r+(pb.r-pa.r)*t, pa.g+(pb.g-pa.g)*t, pa.b+(pb.b-pa.b)*t, 1);
        return "#" + Math.round(c.r*255).toString(16).padStart(2,"0")
                   + Math.round(c.g*255).toString(16).padStart(2,"0")
                   + Math.round(c.b*255).toString(16).padStart(2,"0");
    }
    function rgba(hex: string, alpha: real): string {
        const r = parseInt(hex.slice(1,3),16)/255;
        const g = parseInt(hex.slice(3,5),16)/255;
        const b = parseInt(hex.slice(5,7),16)/255;
        return Qt.rgba(r, g, b, alpha).toString();
    }

    // $secondary: mix($color2,$foreground,$phi-percentage) — note t>1 clamps naturally
    readonly property string secondary: mix(color2, foreground, phiMin)
    readonly property string tertiary: color3
    // $background-transparent: rgba($background, $OPACITY) ; OPACITY comes from settings.ui.opacity
    readonly property string backgroundTransparent: rgba(background, Settings.uiOpacity)
    readonly property string backgroundSecondary: mix(background, secondary, phiMin)
    readonly property string foregroundSecondary: mix(foreground, secondary, phiMin)

    // --- typography / scale (settings-driven, like $FONT-SIZE / $SCALE) ---
    readonly property string fontFamily: "JetBrainsMono NFP"
    readonly property int fontSize: Settings.uiFontSize
    readonly property int scale: Settings.uiScale
    readonly property int radius: 10
    readonly property int spacing: 8          // bar element spacing (AGS look)
    readonly property int sectionSpacing: 20  // between compact sections / expanded groups

    // --- lib.scss @include module / button equivalents ---
    readonly property string moduleBg: backgroundTransparent
    readonly property string buttonCheckedBg: foregroundSecondary
    readonly property string buttonCheckedFg: background
    readonly property string buttonHoverBg: background

    // Panel-specific colors
    readonly property string accent: foreground
    readonly property string accentBg: mix(background, foreground, 0.1)
    readonly property string fgDim: Qt.rgba(parseInt(foreground.slice(1,3),16)/255, parseInt(foreground.slice(3,5),16)/255, parseInt(foreground.slice(5,7),16)/255, 0.5).toString()
    readonly property string border: Qt.rgba(parseInt(foreground.slice(1,3),16)/255, parseInt(foreground.slice(3,5),16)/255, parseInt(foreground.slice(5,7),16)/255, 0.15).toString()
    readonly property string fg: foreground
    readonly property string bg: background

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
            root.color1 = grab("color1", "#493028");
            root.color2 = grab("color2", "#413945");
            root.color3 = grab("color3", "#4e505d");
        }
    }
}