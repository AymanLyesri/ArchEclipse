pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mirrors the subset of ArchEclipse settings.json (cache/settings/settings.json)
// that the bar consumes. Values are read once at startup — the AGS settings UI
// remains the editor; this shell follows the same file so both stay in sync.
QtObject {
    id: root

    // defaults matching constants/settings.constants.ts
    property bool barLock: true
    property bool barSmartHide: false
    property bool barExpanded: false
    property bool barFullWidth: false
    property int revealPressure: 250
    property bool barOrientation: true        // true = top
    property bool workspaceNumbers: false
    property var barLayout: ({ workspaces: true, information: true, utilities: true })
    property string dateFormat: "%H:%M"
    readonly property var dateFormats: ["%H:%M", "%I:%M %p"]
    property real uiOpacity: 0.618
    property int uiScale: 10
    property int uiFontSize: 12
    property real leftPanelHotZoneSize: 5
    property real rightPanelHotZoneSize: 5
    property bool leftPanelHotZone: true
    property bool rightPanelHotZone: true
    property bool notifDnd: false
    property bool leftPanelLock: false
    property bool rightPanelLock: false

    function fmt(d, f) {
        const p = (n) => n.toString().padStart(2, "0");
        if (f === "%I:%M %p") {
            let h = d.getHours() % 12; if (h === 0) h = 12;
            return `${p(h)}:${p(d.getMinutes())} ${d.getHours() < 12 ? "AM" : "PM"}`;
        }
        return `${p(d.getHours())}:${p(d.getMinutes())}`;
    }

    property FileView _file: FileView {
        path: `${Quickshell.env("HOME")}/.config/ags/cache/settings/settings.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.barLock = s.bar.lock.value;
                root.barSmartHide = s.bar.smartHide.value;
                root.barExpanded = s.bar.expanded.value;
                root.barFullWidth = s.bar.fullWidth.value;
                root.revealPressure = s.bar.revealPressure?.value ?? 250;
                root.barOrientation = s.bar.orientation.value;
                root.workspaceNumbers = s.bar.workspaceNumbers.value;
                root.barLayout = {};
                for (const w of s.bar.layout) root.barLayout[w.name] = !!w.enabled;
                root.dateFormat = s.dateFormat;
                root.uiOpacity = s.ui.opacity.value;
                root.uiScale = s.ui.scale.value;
                root.uiFontSize = s.ui.fontSize.value;
                root.leftPanelHotZoneSize = s.leftPanel.hotZoneSize?.value ?? 5;
                root.rightPanelHotZoneSize = s.rightPanel.hotZoneSize?.value ?? 5;
                root.leftPanelHotZone = s.leftPanel.hotZone?.value ?? true;
                root.rightPanelHotZone = s.rightPanel.hotZone?.value ?? true;
                root.leftPanelLock = !!s.leftPanel.lock;
                root.notifDnd = !!s.notifications?.dnd;
                root.rightPanelLock = !!s.rightPanel.lock;
            } catch (e) {
                console.warn("[Settings] parse failed:", e);
            }
        }
    }
}
