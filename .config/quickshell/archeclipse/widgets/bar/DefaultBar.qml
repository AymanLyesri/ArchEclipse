import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar

// Center section (ex-Information) is inlined here directly:
// launcher + focused window title on the left; center rectangle with
// bandwidth | control panel | clock; resource bars + battery/brightness/
// volume/tray on the right. The title never contributes to the bar's
// width (see topRow.leftMinWidth) — it fills only its own natural slot.
// Weather and media live outside this bar as their own standalone pills
// (Bar.qml, recording-pill pattern).
// Top row holds all content; the workspace strip sits at the very bottom,
// stretched across the full bar width.
Column {
    id: root
    spacing: 4

    // Injected by Bar.qml (currentPageLoader.onLoaded) — the stack that owns
    // the pill width. The volume/brightness sliders animate their own width,
    // and while they do the pill must track them rigidly instead of easing
    // toward a target that moves every frame (see stack.rigidWidth in Bar.qml).
    property var barStack: null
    readonly property bool contentGliding: volumeWidget.revealing || brightnessWidget.revealing
    onContentGlidingChanged: root.setContentGliding(root.contentGliding)
    // Workspace-strip icon reveal glides the strip's OWN height, so the pill
    // must track it per-frame (rigidHeight) instead of easing after it — the
    // same deal as the slider reveals above, on the vertical axis.
    readonly property bool stripGliding: workspaces.revealing
    onStripGlidingChanged: root.setStripGliding(root.stripGliding)
    onBarStackChanged: {
        root.setContentGliding(root.contentGliding);
        root.setStripGliding(root.stripGliding);
    }
    Component.onDestruction: {
        root.setContentGliding(false);
        root.setStripGliding(false);
    }
    function setContentGliding(on) {
        if (root.barStack)
            root.barStack.rigidWidth = on;
    }
    function setStripGliding(on) {
        if (root.barStack)
            root.barStack.rigidHeight = on;
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
        implicitWidth: 2 * sideWidth + centerPill.width + Theme.spacing * 2
        width: implicitWidth
        height: Theme.barContentHeight

        // Center rectangle — bandwidth on the left, control panel
        // button dead-center, clock on the right.
        Rectangle {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: centerRow.implicitWidth + 20
            height: Theme.barContentHeight
            radius: Theme.radius
            color: Theme.surfaceActive

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: Theme.spacing
                height: parent.height
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
                        spacing: 4
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

                // control panel toggle — center
                ControlPanelButton {
                    id: centerButton
                    anchors.verticalCenter: parent.verticalCenter
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

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing

                LauncherButton {
                    id: launcherButton
                }
                WindowTitle {
                    id: windowTitleButton
                    // Natural size (never stretches into the slack), capped
                    // so a long title elides instead of spilling past the
                    // zone into the center pill. maximumWidth only caps the
                    // layout's assignment — it never feeds WindowTitle's
                    // implicitWidth, so it can't loop back into sideWidth.
                    // textMaxWidth carries the same bound minus pill chrome
                    // (margins + icon + spacing) so the text elides at the
                    // true available width at any bar size.
                    Layout.maximumWidth: topRow.titleCap
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

            Row {
                id: utilities
                spacing: Theme.spacing
                height: parent.height
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

      ResourceMonitor {
                    id: resourceMonitor
                }
                Battery {}
                Brightness {
                    id: brightnessWidget
                }
                Volume {
                    id: volumeWidget
                }
                Tray {}
            }
        }
    } // topRow

    // bottom workspace strip — full width of the bar content
    Workspaces {
        id: workspaces
        width: topRow.implicitWidth
    }
}
