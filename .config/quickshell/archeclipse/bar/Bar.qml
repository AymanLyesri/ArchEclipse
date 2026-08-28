import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.bar

// Port of widgets/bar/Bar.tsx — the floating ArchEclipse bar pill.
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen);
        if (hmon && hmon.name) return hmon.name;
        // fallback: try to get monitor name from screen
        return screen?.name ?? "unknown";
    }

    // --- window geometry / layer ---
    anchors { left: true; right: true; top: Settings.barOrientation; bottom: !Settings.barOrientation }

    // layer-shell keyboard grab while the search island is open
    WlrLayershell.keyboardFocus: BarState.state === "search"
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand
    exclusiveZone: Settings.barLock ? implicitHeight : -1
    color: "transparent"
    aboveWindows: true

    readonly property int barHeight: 34
    implicitHeight: barHeight + (Settings.barOrientation ? 6 : 0)

    readonly property bool fullWidth: Settings.barFullWidth

    // visibility: fullscreen client hides; search pins; override wins;
    // otherwise lock/smart-hide logic.
    readonly property bool fullscreenActive: {
        const mon = Hyprland.monitorFor(screen);
        const ws = mon?.activeWorkspace;
        if (!ws) return false;
        const tops = Hyprland.toplevels.values.filter(t => t.workspace === ws);
        return tops.some(t => t.lastIpcObject?.fullscreen?.client > 0 || t.lastIpcObject?.fullscreen === 2);
    }
    readonly property bool smartHideBlocked: {
        BarState.hyprlandTick;
        if (!Settings.barSmartHide) return false;
        const mon = Hyprland.monitorFor(screen);
        const ws = mon?.activeWorkspace;
        if (!ws) return false;
        return Hyprland.toplevels.values.some(t => t.workspace === ws);
    }

    readonly property bool barVisible: {
        if (fullscreenActive) return false;
        if (BarState.state === "search") return true;
        const override = BarState.barShown[monitorName];
        if (override !== undefined) return override;
        return Settings.barLock || smartHideBlocked;
    }

    // --- hover: expand on enter, collapse after leave delay ---
    property bool hovered: false
    Component.onCompleted: {
        if (Settings.barExpanded) BarState.activate("expanded", 0);
    }
    onHoveredChanged: {
        if (hovered) {
            BarState.activate("expanded", 0);
            hideTimer.stop();
        } else {
            hideTimer.restart();
        }
    }
    Timer {
        id: hideTimer
        interval: 250
        onTriggered: {
            if (!root.hovered && !Settings.barExpanded)
                BarState.deactivate("expanded");
        }
    }

    // idle watchdog for hover-reveal overrides
    Connections {
        target: BarState
        function onBarShownChanged() {
            if (BarState.barShown[root.monitorName] === true) idleTimer.restart();
            else idleTimer.stop();
        }
    }
    Timer {
        id: idleTimer
        interval: 1500
        running: BarState.barShown[root.monitorName] === true
        onTriggered: {
            if (Settings.barLock) return;
            if (BarState.state === "search") { idleTimer.restart(); return; }
            if (!root.hovered) BarState.concealBar(root.monitorName);
            else idleTimer.restart();
        }
    }

    Item {
        id: stripRoot
        anchors.fill: parent

        // Hover detection lives on this stable container
        HoverHandler {
            id: pillHover
            enabled: true
        }
        readonly property bool pointerOnPill: {
            const p = pillHover.point.position;
            return pillHover.hovered &&
                   p.x >= (pill.x - 4) && p.x <= (pill.x + pill.width + 4);
        }
        onPointerOnPillChanged: root.hovered = pointerOnPill

        // ---- the pill ----
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.barHeight
            width: Math.max(stack.width + 10, 100)
            radius: Theme.radius
            color: Theme.moduleBg
            border.width: 0

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                }
            }

            // ---- state stack with crossfade ----
            Item {
                id: stack
                anchors.centerIn: parent
                width: currentPageLoader.item ? currentPageLoader.item.width : 0
                height: childrenRect.height

                property string current: BarState.state
                onCurrentChanged: fade.restart()
                readonly property string previous: ""

                SequentialAnimation {
                    id: fade
                    PropertyAction { target: stack; property: "opacity"; value: 0.35 }
                    NumberAnimation { target: stack; property: "opacity"; from: 0.35; to: 1; duration: 250; easing.type: Easing.InOutQuad }
                }

                Loader {
                    id: currentPageLoader
                    sourceComponent: {
                        switch (stack.current) {
                        case "expanded": return expandedPage;
                        case "volume": return volumePage;
                        case "brightness": return brightnessPage;
                        case "recording": return recordingPage;
                        case "player": return playerPage;
                        case "search": return searchPage;
                        default: return compactPage;
                        }
                    }
                }

                Component { id: compactPage; CompactBar {} }
                Component { id: expandedPage; ExpandedBar {} }
                Component { id: volumePage; VolumePulse {} }
                Component { id: brightnessPage; BrightnessPulse {} }
                Component { id: recordingPage; RecordingIndicator {} }
                Component { id: playerPage; PlayerPulse {} }
                Component { id: searchPage; SearchBar {} }
            }
        }

        // ---- launcher results popup ----
        PopupWindow {
            id: launcherPopup
            visible: BarState.state === "search"
            anchor.window: root
            anchor.item: pill
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 8
            color: "transparent"
            implicitWidth: 520
            implicitHeight: Math.min(launcherPanel.height + 4, 480)
            LauncherPanel { id: launcherPanel }
        }

        // ---- hot zones (left/right panel reveal strips) ----
        HotZone {
            side: "left"
            size: Settings.leftPanelHotZoneSize
            enabled: Settings.leftPanelHotZone
            panelLock: Settings.leftPanelLock
        }
        HotZone {
            side: "right"
            size: Settings.rightPanelHotZoneSize
            enabled: Settings.rightPanelHotZone
            panelLock: Settings.rightPanelLock
        }
    }

    visible: barVisible
}