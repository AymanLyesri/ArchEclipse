import QtQuick
import qs.services
import qs.widgets.bar.islands
import qs.widgets.wallpaperPanel

// Wallpaper island: the full switcher body inline in the bar pill.
// Same unfold pattern as SearchIsland — the pill grows (width via
// the pill transition, height snapped on the window) while this body unfolds.
//
// Persistent like SearchIsland (no leave auto-close — picking a wallpaper
// is a task, not a hover peek). Closes via Esc, SUPER+W toggle, or the
// control-panel wallpaper button.
Column {
    id: root
    width: 1500
    spacing: 0

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    Component.onCompleted: {
        expand = 1;
        // NOTE: the registered handle is the *body* (not the island
        // root) — Ipc.wallpaperDiag reads body probes (categories,
        // wallStrip, ...) off it. Both the bare alias and the keyed
        // entry are unregistered in onDestruction below (`destroyed`
        // is not connectable in this engine, so no helper does it).
        Registry.register(root.registryKey(), body);
        Registry.register("wallpaper-island", body);
    }
    onMonitorNameChanged: {
        if (root.monitorName !== "")
            Registry.register(root.registryKey(), body);
    }
    Component.onDestruction: {
        Registry.unregister("wallpaper-island");
        Registry.unregister(root.registryKey());
    }
    function registryKey() {
        return `wallpaper-island-${root.monitorName || Registry.monitorName}`;
    }

    // Esc dismiss once the surface has focus (click a control first).
    IslandEscClose {
        states: ["wallpaper"]
    }

    IslandExpandClip {
        expand: root.expand
        contentHeight: body.height

        WallpaperPanelBody {
            id: body
            anchors.top: parent.top
            width: parent.width
            // True height: the body reports chrome + view row + filter +
            // masonry results, and the pill grows to fit (rows × tile size).
            height: body.implicitHeight
            monitorName: root.monitorName
        }
    }
}
