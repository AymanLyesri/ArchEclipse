import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.bar.islands
import qs.widgets.shared

// Center section (ex-Information) is inlined here directly:
// launcher + focused window title on the left; center rectangle with
// bandwidth | control panel | clock; resource bars + battery/brightness/
// volume/tray on the right. The title never contributes to the bar's
// width (see topRow.leftMinWidth) — it fills only its own natural slot.
// Weather and media live outside this bar as their own standalone pills
// (Bar.qml, recording-pill pattern).
// Top row holds all content; the workspace strip sits at the very bottom,
// stretched across the full bar width.
// The control panel is NOT an island page and NOT a card hanging off the
// bar: clicking the gear swaps the center pill's content for ControlCard
// and the bar becomes that panel — the zones drop out, the width collapses
// to the panel + the pill's inset, and the row takes the panel's height so
// the workspace strip is pushed below it.
Column {
    id: root
    spacing: Theme.spacing / 2
    property string monitorName: ""

    // Injected by Bar.qml (currentPageLoader.onLoaded) — the stack that owns
    // the pill width. The volume/brightness sliders animate their own width,
    // and while they do the pill must track them rigidly instead of easing
    // toward a target that moves every frame (see stack.rigidWidth in Bar.qml).
    property var barStack: null
    readonly property bool contentGliding: volumeWidget.revealing || brightnessWidget.revealing
    // True while the center pill's own box animates (control open/close).
    // Its width/height targets move every frame during that unfold, so the
    // bar pill must track them rigidly instead of easing after a moving target.
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

    // Workspace-strip passthrough for the window mask + hover chaining
    // (Bar.qml): the hanging wave buttons live BELOW the (never-growing)
    // pill, so clicks/hover there need their own region.
    readonly property Item waveHitbox: workspaces.waveHitbox
    readonly property bool stripHovered: workspaces.stripHovered
    readonly property bool stripExpanded: workspaces.stripExpanded
    readonly property real stripHang: workspaces.stripHang

    // Band hover: holds the card's hover pin while the cursor is on the bar
    // (e.g. on the gear that just opened it).
    HoverHandler {
        id: bandHover
    }

    // Fixed-width dynamic speed: always 4 chars (3-char numeric + 1-char
    // unit that scales B/K/M/G), so the bandwidth cell never shifts width
    // as speeds change. Monospace font keeps every string the same width.
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
        // Left zone minimums — the fixed resident item is the launcher; the
        // focused window title is deliberately NOT counted. It elides into
        // whatever the zone is given, so a long title can never widen the
        // pill: counting it made the whole bar track the focused window
        // (783 -> 930 just by focusing a long-titled window, and the width
        // no longer retracted when the title shortened). Counting the
        // resource monitor here is equally wrong — it lives in `utilities`
        // (right zone); the phantom width was 86px that nothing occupied.
        // Widths stay implicit-only (never assigned) so the sideWidth ->
        // zone-width -> fill-width chain can't bind back into itself
        // (Flickable-style polish loop, cf. RightIsland).
        readonly property real leftMinWidth: launcherButton.implicitWidth + Theme.spacing
        readonly property real rightMinWidth: utilities.implicitWidth
        readonly property real sideWidth: Math.max(leftMinWidth, rightMinWidth)
        // Title cap shared by WindowTitle's Layout.maximumWidth and its
        // text elide width (minus pill chrome) — upstream-only values so
        // the title width can never bind back into the layout (degenerate
        // 0-width fixed point, seen 2026-10-14).
        readonly property real titleCap: Math.max(80, Math.min(240, sideWidth - launcherButton.implicitWidth - Theme.spacing * 2))
        // Quick settings up: the bar IS the panel. Zones drop out, the row
        // takes the panel's height (which pushes the workspace strip below
        // it) and the width collapses to the panel + the pill's own inset.
        // Follows the *intent* (`open`), not the body's lifetime (`shown`):
        // `shown` outlives the close retract, so keying the chrome off it kept
        // the band content away for the whole fold and landed it afterwards.
        readonly property bool panelUp: controlCard.open
        // The shell morphs with the same unfold driver as the center pill, so
        // the bar (and the strip below it) narrows as the panel grows instead
        // of snapping to the open width on the first frame.
        readonly property real closedWidth: 2 * sideWidth + centerPill.collapsedWidth + Theme.spacing * 2
        implicitWidth: closedWidth + (centerPill.openWidth - closedWidth) * controlCard.openT
        width: implicitWidth
        height: Theme.barContentHeight + (Math.max(controlCard.cardHang, Theme.barContentHeight) - Theme.barContentHeight) * controlCard.openT

        // Bar chrome (zones, band row, notch) cross-fades out while the panel
        // opens, and back in from the FIRST frame of the close retract: the
        // band content returns gradually across the shrinking panel instead of
        // popping in once the box has already folded. Opening keeps the short
        // effects fade; closing spans the whole retract so the two halves land
        // together. `chromeVisible` only gates hit-testing — it stays live for
        // the length of the fade-out, then drops the invisible buttons.
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

        // Center rectangle — bandwidth on the left, control panel
        // button dead-center, clock on the right. No top margin: the
        // body reaches the bar's screen-edge wall, traced by
        // PillBackground as one fill (straight wall edge + concave
        // inverted corners, rounded lower corners like before).
        //
        // Quick settings lives INSIDE this pill: the gear swaps the band
        // row for ControlCard and the bump itself grows (wide enough for
        // the 680 body, as tall as the unfolded card) while its wall-side
        // edge stays pinned. The bar pill follows it — a single surface
        // around the panel, with the workspace strip pushed underneath.
        Item {
            id: centerPill
            // Gap between the content row and the pill's wall = the
            // stack's per-state outer inset (only shown for states that
            // render this bar, which all keep the default 4).
            readonly property real edgePad: root.barStack ? root.barStack.effPad : 0
            readonly property bool controlOpen: BarState.stateFor(root.monitorName) === "control"
            // Resting bump: content row plus 20px chrome, bottom on the
            // content line and the wall side reaching the pill's inner edge.
            readonly property real collapsedWidth: centerRow.implicitWidth + 20
            readonly property real collapsedHeight: Theme.barContentHeight + edgePad
            readonly property real collapsedY: (Theme.barContentHeight - collapsedHeight) / 2 + (Settings.barOrientation ? -1 : 1) * edgePad / 2
            // Full panel footprint. `openT` is the single unfold driver: this
            // item's real width/height grow from the band bump and the bar pill
            // + strip morph with it (topRow above). Height tracks cardHang
            // while open, so the volume section's own growth still pushes the
            // pill (and the strip) down live.
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
                // The bump is the center pill's own surface: it is what you
                // see unfold into the panel and retract back into the band,
                // so it stays fully opaque the whole way — no hand-off fade,
                // no double-blend shortcut.
                visible: topRow.chromeVisible || controlCard.shown
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                id: centerRow
                anchors.horizontalCenter: parent.horizontalCenter
                // Pinned to the wall with the band's own height: the bump is
                // as tall as the open panel while it cross-fades, and a
                // centred row would drag the bandwidth/clock text down the
                // middle of the panel.
                height: Theme.barContentHeight
                y: (centerPill.collapsedHeight - height) / 2
                spacing: Theme.spacing / 2
                // Swapped out for the card (cross-fade, see topRow).
                visible: topRow.chromeVisible
                opacity: topRow.chromeOpacity
                // Equal-width side cells so the control button stays
                // dead-center relative to the whole bar even when
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
                            text: ""
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
                            text: ""
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
                    icon: "\uf303"
                    pixelSize: Theme.fontSize + 1
                    // The row is hidden while the panel is open, so the
                    // checked highlight only ever shows for a frame at
                    // close; kept so the toggle reflects the state.
                    toggle: true
                    checked: BarState.stateFor(root.monitorName) === "control"
                    tooltipText: "Quick settings"
                    onClicked: {
                        // Toggle the control card. Wallpaper sits above
                        // control (priority), so yield it first — otherwise
                        // opening control while the wallpaper island is up
                        // looks dead.
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

            // Quick settings — the pill's own content while open. The card is
            // full panel size; this wrapper is clipped to the center pill's
            // real box, so the content is revealed by that box growing (the
            // pill's own geometry), not by an inner iris animation.
            Item {
                id: panelClip
                width: centerPill.width
                height: centerPill.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: Settings.barOrientation ? parent.top : undefined
                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                clip: true
                // The card sits above the band row, so an opaque card would
                // hide the chrome fading in underneath it for the whole
                // retract. Fading the content with the same driver as the
                // box makes the close a real cross-fade; opening keeps it
                // fully opaque (the growing box is the reveal there).
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

        // left zone — fixed sideWidth (mirrors the wider right zone so the
        // center pill stays centered with clearance). The title occupies
        // only its natural slot here; the rest of the zone stays empty and
        // no title length can widen the bar. (Weather lives outside this
        // bar as its own pill.)
        Item {
            id: leftZone
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: topRow.sideWidth
            height: parent.height
            // Cross-fades out while the panel opens (see topRow): the bar
            // narrows to the panel's width, so these would otherwise be
            // clipped off in one frame.
            visible: topRow.chromeVisible
            opacity: topRow.chromeOpacity

            // Plain Row (not RowLayout): RowLayout distributed the zone's
            // mirror-slack around the title (measured title.x 75..88
            // instead of 40), while a Row packs left with exact spacing.
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
                    icon: "\uf002"
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
                    // Natural size (never stretches into the slack), capped
                    // so a long title elides instead of spilling past the
                    // zone into the center pill. An explicit width (not a
                    // layout cap) — it never feeds implicitWidth, so it
                    // can't loop back into sideWidth. textMaxWidth carries
                    // the same bound minus pill chrome (margins + icon +
                    // spacing) so the text elides at the true available
                    // width at any bar size.
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
            // Cross-fades out while the panel opens (see topRow): the bar
            // narrows to the panel's width, so these would otherwise be
            // clipped off in one frame.
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
