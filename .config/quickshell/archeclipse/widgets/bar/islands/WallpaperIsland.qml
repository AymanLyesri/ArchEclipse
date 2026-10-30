import QtQuick
import qs.services
import qs.widgets.bar.islands
import qs.widgets.wallpaperPanel

// Wallpaper island: the full switcher body inline in the bar pill, same unfold pattern as
// SearchIsland. Persistent (no leave auto-close): Esc, SUPER+W or the control button closes it.
Column {
    id: root
    // The bar sizes the pill from THIS item's width (Bar.qml stack.activeWidth) — a value on the
    // body is inert. Never declare implicitWidth here: it is read-only and the island fails to load.
    width: root.screen ? Math.min(1280, root.screen.width - 64) : 1280

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""
    property var screen: null

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    Component.onCompleted: {
        expand = 1;
        // NOTE: the registered handle is the *body*, not the island root — Ipc.wallpaperDiag
        // reads body probes off it; both entries die in onDestruction (`destroyed` not connectable).
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
        monitorName: root.monitorName
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

    WallpaperAnimatedPreview {
        screen: root.screen
        monitorName: root.monitorName
        source: body.animatedPreviewPath
    }
}
