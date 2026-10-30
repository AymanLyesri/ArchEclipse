import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.bar.islands
import qs.widgets.shared

// Launcher + window title left, center pill (bandwidth | control | clock), resources and
// battery/brightness/volume/tray right; the gear turns the center pill into ControlCard.
Column {
    id: root
    spacing: Theme.spacing / 2
    property string monitorName: ""

    // Injected by Bar.qml: the stack that owns the pill width. While the sliders animate
    // their own width the pill must track rigidly (stack.rigidWidth), not ease after it.
    property var barStack: null
    readonly property bool contentGliding: volumeWidget.revealing || brightnessWidget.revealing
    // True while the center pill's own box animates (control open/close): its targets move
    // every frame, so the bar pill must track them rigidly instead of easing.
    readonly property bool panelGliding: controlCard.gliding
    onContentGlidingChanged: root.setContentGliding(root.contentGliding)
    onPanelGlidingChanged: root.setPanelGliding(root.panelGliding)
    onBarStackChanged: {
        root.setContentGliding(root.contentGliding);
        root.setPanelGliding(root.panelGliding);
    }
    Component.onDestruction: {
        root.setContentGliding(false);
        root.setPanelGliding(false);
    }
    function setContentGliding(on) {
        if (root.barStack)
            root.barStack.rigidWidth = on;
    }
    function setPanelGliding(on) {
        if (root.barStack)
            root.barStack.rigidDirect = on;
    }

    // Workspace-strip passthrough for the window mask + hover chaining: the hanging wave
    // buttons live below the never-growing pill, so they need their own region.
    readonly property Item waveHitbox: workspaces.waveHitbox
    readonly property bool stripHovered: workspaces.stripHovered
    readonly property bool stripExpanded: workspaces.stripExpanded
    readonly property real stripHang: workspaces.stripHang

    // Band hover: holds the card's hover pin while the cursor is on the bar
    // (e.g. on the gear that just opened it).
    HoverHandler {
        id: bandHover
    }

    // Fixed-width speed, always 4 chars (3 numeric + 1 unit scaling B/K/M/G) in a monospace
    // font, so the bandwidth cell never shifts width as speeds change.
    function fmtSpeed(bps) {
        if (bps < 1000)
            return String(Math.round(bps)).padStart(3, " ") + "B";
        const kb = bps / 1024;
        if (kb < 10)
            return kb.toFixed(1) + "K";
        if (kb < 1000)
            return String(Math.round(kb)).padStart(3, " ") + "K";
        const mb = kb / 1024;
        if (mb < 10)
            return mb.toFixed(1) + "M";
        if (mb < 1000)
            return String(Math.round(mb)).padStart(3, " ") + "M";
        const gb = mb / 1024;
        if (gb < 10)
            return gb.toFixed(1) + "G";
        return String(Math.round(gb)).padStart(3, " ") + "G";
    }

    Item {
        id: topRow
        // Left zone minimums count the launcher only: counting the title let a long one widen
        // the bar (783 -> 930), and the monitor added 86px nothing occupied. Widths stay implicit.
        readonly property real leftMinWidth: launcherButton.implicitWidth + Theme.spacing
        readonly property real rightMinWidth: utilities.implicitWidth
        readonly property real sideWidth: Math.max(leftMinWidth, rightMinWidth)
        // Title cap shared by Layout.maximumWidth and the elide width (minus pill chrome):
        // upstream-only, or the title width feeds the Row it is measured from (0-width fixpoint).
        readonly property real titleCap: Math.max(80, Math.min(240, sideWidth - launcherButton.implicitWidth - Theme.spacing * 2))
        // Quick settings up: the bar IS the panel (zones out, row at panel height, width
        // collapsed). Follow `open`, not `shown` — `shown` outlives the retract.
        readonly property bool panelUp: controlCard.open
        // The shell morphs with the center pill's unfold, so the bar and strip narrow as the
        // panel grows instead of snapping on the first frame.
        readonly property real closedWidth: 2 * sideWidth + centerPill.collapsedWidth + Theme.spacing * 2
        implicitWidth: closedWidth + (centerPill.openWidth - closedWidth) * controlCard.openT
        width: implicitWidth
        height: Theme.barContentHeight + (Math.max(controlCard.cardHang, Theme.barContentHeight) - Theme.barContentHeight) * controlCard.openT

        // Chrome cross-fades out on open and back in from the first frame of the retract;
        // `chromeVisible` only gates hit-testing and stays live through the fade-out.
        property real chromeOpacity: panelUp ? 0 : 1
        property bool chromeVisible: true
        onPanelUpChanged: {
            if (panelUp) {
                chromeHideTimer.restart();
            } else {
                chromeHideTimer.stop();
                chromeVisible = true;
            }
        }
        Component.onCompleted: {
            if (panelUp)
                chromeHideTimer.restart();
        }
        Behavior on chromeOpacity {
            enabled: Settings.animationsEnabled
            Anim {
                type: Anim.DefaultEffects
                duration: topRow.panelUp ? Theme.anim.defaultEffects : controlCard.expandDuration
            }
        }
        Timer {
            id: chromeHideTimer
            interval: Settings.animationsEnabled ? Theme.anim.defaultEffects : 0
            onTriggered: topRow.chromeVisible = false
        }

        // Center rectangle: bandwidth | control | clock, no top margin so the body reaches the
        // wall as one PillBackground fill; quick settings grows this same bump into the panel.
        Item {
            id: centerPill
            // Gap between the content row and the pill's wall = the stack's per-state outer
            // inset (the states that render this bar all keep the default 4).
            readonly property real edgePad: root.barStack ? root.barStack.effPad : 0
            readonly property bool controlOpen: BarState.stateFor(root.monitorName) === "control"
            // Resting bump: content row plus 20px chrome, bottom on the
            // content line and the wall side reaching the pill's inner edge.
            readonly property real collapsedWidth: centerRow.implicitWidth + 20
            readonly property real collapsedHeight: Theme.barContentHeight + edgePad
            readonly property real collapsedY: (Theme.barContentHeight - collapsedHeight) / 2 + (Settings.barOrientation ? -1 : 1) * edgePad / 2
            // Full panel footprint, driven only by `openT`: height tracks cardHang while open,
            // so the volume section's own growth still pushes the pill and strip down live.
            readonly property real openWidth: controlCard.cardWidth
            readonly property real openHeight: Math.max(controlCard.cardHang, collapsedHeight)

            anchors.horizontalCenter: parent.horizontalCenter
            width: collapsedWidth + (openWidth - collapsedWidth) * controlCard.openT
            height: collapsedHeight + (openHeight - collapsedHeight) * controlCard.openT
            // Wall edge pinned, growth away from the screen edge.
            y: Settings.barOrientation ? collapsedY : collapsedY + collapsedHeight - height

            PillBackground {
                topBar: Settings.barOrientation
                bodyWidth: centerPill.width
                bodyHeight: centerPill.height
                // The bump is the center pill's own surface, so it stays fully opaque through
                // the unfold — no hand-off fade, no double-blend shortcut.
                visible: topRow.chromeVisible || controlCard.shown
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                id: centerRow
                anchors.horizontalCenter: parent.horizontalCenter
                // Pinned to the wall with the band's height: a centred row would drag the
                // bandwidth/clock text down the middle of the panel while it cross-fades.
                height: Theme.barContentHeight
                y: (centerPill.collapsedHeight - height) / 2
                spacing: Theme.spacing / 2
                // Swapped out for the card (cross-fade, see topRow).
                visible: topRow.chromeVisible
                opacity: topRow.chromeOpacity
                // Equal-width side cells keep the control button dead-center even when
                // bandwidth and clock text widths differ.
                readonly property real sideCellWidth: Math.max(bandwidthRow.implicitWidth, clockItem.width)

                // bandwidth compact (up/down from SysInfo loop) — left
                Item {
                    width: centerRow.sideCellWidth
                    height: parent.height
                    Row {
                        id: bandwidthRow
                        spacing: Theme.spacing / 2
                        anchors.centerIn: parent
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmtSpeed(SysInfo.bandwidth[0] * 1024)
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.arrowUp
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmtSpeed(SysInfo.bandwidth[1] * 1024)
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.arrowDown
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }

                // control panel toggle — center (inlined: was
                // ControlPanelButton.qml, now the shared AppButton cell)
                AppButton {
                    id: centerButton
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 32
                    width: implicitWidth
                    height: Theme.barContentHeight
                    icon: Icons.arch
                    pixelSize: Theme.fontSize + 1
                    // The row is hidden while the panel is open, so this highlight only shows
                    // for a frame at close; kept so the toggle reflects the state.
                    toggle: true
                    checked: BarState.stateFor(root.monitorName) === "control"
                    tooltipText: "Quick settings"
                    onClicked: {
                        // Wallpaper ranks above control, so yield it first — otherwise opening
                        // control while the wallpaper island is up looks dead.
                        if (BarState.stateFor(root.monitorName) === "control")
                            BarState.deactivate("control", root.monitorName);
                        else {
                            BarState.deactivate("wallpaper", root.monitorName);
                            BarState.activate("control", 0, root.monitorName);
                        }
                    }
                }

                // clock — right, same cell width as bandwidth side
                Item {
                    width: centerRow.sideCellWidth
                    height: parent.height
                    Clock {
                        id: clockItem
                        anchors.centerIn: parent
                        hoverColor: "transparent"
                    }
                }
            }

            // Quick settings — the pill's own content while open. Clipped to the center pill's
            // real box, so the box growing is the reveal, not an inner iris animation.
            Item {
                id: panelClip
                width: centerPill.width
                height: centerPill.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: Settings.barOrientation ? parent.top : undefined
                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                clip: true
                // An opaque card would hide the chrome fading in underneath for the whole
                // retract, so the content fades with the box; opening keeps it opaque.
                opacity: controlCard.open ? 1 : controlCard.openT

                ControlCard {
                    id: controlCard
                    monitorName: root.monitorName
                    open: centerPill.controlOpen
                    bandHovered: bandHover.hovered
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: Settings.barOrientation ? parent.top : undefined
                    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                }
            }
        }

        // left zone — fixed sideWidth mirroring the right zone so the center pill stays
        // centered; the title takes only its natural slot, so no title length widens the bar.
        Item {
            id: leftZone
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: topRow.sideWidth
            height: parent.height
            // Cross-fades out while the panel opens: the bar narrows to the panel width, so
            // these would otherwise be clipped off in one frame.
            visible: topRow.chromeVisible
            opacity: topRow.chromeOpacity

            // Plain Row, not RowLayout: RowLayout distributed the mirror-slack around the
            // title (measured x 75..88 instead of 40); a Row packs left with exact spacing.
            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing

                // search/app launcher at the far left (inlined: was
                // LauncherButton.qml, now the shared AppButton cell)
                AppButton {
                    id: launcherButton
                    implicitWidth: 32
                    width: implicitWidth
                    height: Theme.barContentHeight
                    icon: Icons.search
                    pixelSize: Theme.fontSize + 3
                    idleFg: Theme.accent
                    hoverFg: Theme.accent
                    tooltipText: "Search apps · <b>SUPER</b>"
                    onClicked: {
                        if (BarState.isOpenFor("search", root.monitorName))
                            BarState.deactivate("search", root.monitorName);
                        else {
                            Launcher.pendingQuery = "";
                            BarState.activate("search", 0, root.monitorName);
                        }
                    }
                }
                WindowTitle {
                    id: windowTitleButton
                    monitorName: root.monitorName
                    // Natural size capped by an explicit width (never a layout cap, so it cannot
                    // loop into sideWidth); textMaxWidth carries that bound minus pill chrome.
                    width: Math.min(implicitWidth, topRow.titleCap)
                    textMaxWidth: Math.max(0, topRow.titleCap - 36)
                }
            }
        }

        // right zone — fixed sideWidth like the left, content right-aligned
        // so the center pill keeps symmetric spacing on both sides
        Item {
            id: rightZone
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: topRow.sideWidth
            height: parent.height
            // Cross-fades out while the panel opens: the bar narrows to the panel width, so
            // these would otherwise be clipped off in one frame.
            visible: topRow.chromeVisible
            opacity: topRow.chromeOpacity

            Row {
                id: utilities
                spacing: Theme.spacing
                height: parent.height
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                ResourceMonitor {
                    id: resourceMonitor
                    monitorName: root.monitorName
                }
                Battery {}
                Brightness {
                    id: brightnessWidget
                    monitorName: root.monitorName
                }
                Volume {
                    id: volumeWidget
                    monitorName: root.monitorName
                }
                Tray {
                    monitorName: root.monitorName
                }
            }
        }
    } // topRow

    // bottom workspace strip — full width of the bar content
    Workspaces {
        id: workspaces
        monitorName: root.monitorName
        // Pushed below the panel while quick settings is open (topRow takes
        // the panel's height), so the strip never sits behind its surface.
        width: topRow.implicitWidth
    }
}
