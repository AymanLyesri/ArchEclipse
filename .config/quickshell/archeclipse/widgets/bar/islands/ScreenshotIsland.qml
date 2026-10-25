import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.shared

// Screenshot island — idle-only stadium mirroring the record pill (width
// hugs its content): screenshot indicator on the left, fullscreen / area
// buttons after it.
// Every click spawns ~/.config/hypr/scripts/screenshot.sh detached
// (CustomScriptsWidget precedent). Deliberately: no hover-driven width
// animation, no hover machinery, no hover-toggled visuals — hover-coupled
// resizes churn hover re-evaluation and flap the reveal (probe-proven on
// the record pill; see RecordingIsland).
//
// Launcher expansion (Bar.qml binds `expanded` to the monitor's search
// state, weather-pill recipe): the pill grows vertically off the band and
// the two modes re-represent as labeled IslandActionRow rows on one
// shared surface sheet stacked
// outside the stadium — the compact band parks down to just the camera
// indicator while the rows are shown. Same actions, new representation.
Item {
    id: root
    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    property string monitorName: ""

    // ---- launcher expansion stem (cf. RecordingIsland) ----
    property bool expanded: false
    // bottom-oriented bars grow upward instead of off-screen
    readonly property bool growUp: !Settings.barOrientation
    readonly property real extraGap: Theme.spacing / 2
    property real extraT: root.expanded ? 1 : 0
    Behavior on extraT {
        Anim {}
    }
    // band offset while grown: clears the stacked rows above/below
    readonly property real extraH: root.extraT * (root.extraGap + expandedRows.implicitHeight)
    implicitHeight: clip.height + root.extraH
    height: implicitHeight
    // width hugs the wider of stadium / row block; the row-block term
    // releases at the state flip (not after the fade) so fold-in wide →
    // band width glides concurrently with the row fade instead of after it
    width: Math.max(root.pillW, root.expanded ? expandedRows.implicitWidth : 0)
    Behavior on width {
        Anim {
            duration: Theme.anim.fastSpatial
        }
    }

    // pill hugs its content: camera cell + two 20px buttons + 16px gutters
    // (expanded parks the mode buttons, leaving just the camera cell)
    readonly property real idleW: idleRow.implicitWidth + 16
    property real pillW: idleW
    Behavior on pillW {
        Anim {
            duration: Theme.anim.fastSpatial
        }
    }

    // spawn via the Screenshot service, never a Process owned here: this
    // island is destroyed when the hover reveal folds (~1s after the pointer
    // leaves the bar), which kills any child Process mid-slurp — the area
    // selection then never reaches grim. See services/Screenshot.qml.
    function shoot(mode) {
        Screenshot.capture(mode, root.monitorName);
    }

    // padding click (outside the mode buttons) takes a fullscreen shot
    MouseArea {
        anchors.fill: parent
        onClicked: root.shoot("now")
    }

    IslandExpandClip {
        id: clip
        // pinned to the band edge: grown rows stack ABOVE the band on
        // bottom-oriented bars (below on top bars — see expandedRows)
        y: root.growUp ? root.extraH : 0
        expand: root.expand
        contentHeight: Theme.sidePillHeight

        Rectangle {
            width: root.pillW
            height: Theme.sidePillHeight
            radius: height / 2
            color: Theme.surface

            // camera + buttons content — the camera is a fixed 20px cell
            // (same grid as the buttons), Row centered in the hugging pill
            Row {
                id: idleRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    width: 20
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "\u{F030}"   // nf-fa-camera — screenshot indicator
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                ModeButton {
                    glyph: "\u{F03E}"  // nf-fa-image — fullscreen shot
                    // park while the launcher expansion re-represents the
                    // modes as rows; return at the flip, not at the end of
                    // the geometry unwind — a late return reads as the pill
                    // clipping to the camera-cell width and then popping back
                    visible: !root.expanded
                    tooltipText: "Screenshot workspace · <b>SUPER+SHIFT+S</b>"
                    onClicked: root.shoot("now")
                }
                ModeButton {
                    glyph: "\u{F125}"  // nf-fa-crop — area shot
                    visible: !root.expanded
                    tooltipText: "Screenshot area · <b>SUPER+CTRL+SHIFT+S</b>"
                    onClicked: root.shoot("area")
                }
            }
        }
    }

    // ---- launcher-expanded rows: modes re-represented as rows on a shared
    // sheet ----
    // Hang off the band, away from the screen edge (weather-pill recipe).
    // Reveal rides extraT (FastEffects fade, like the weather stats rows);
    // rows stay laid out while extraT > 0 so the width/height stems glide
    // through fade-out. Handlers are the SAME actions the stadium buttons
    // run — representation only, no new actions.
    //
    // The sheet owns the only background: rows are background-less
    // (see IslandActionRow) so the expanded stack reads as one surface,
    // not a stack of separated pill cards.
    Rectangle {
        id: expandedRows
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.growUp ? 0 : Theme.sidePillHeight + root.extraGap
        visible: root.extraT > 0
        // fade rides its OWN fast stem (like the weather stats rows), never
        // the spatial extraT curve — opacity tracking the geometry animation
        // gates the rows on the pill's full growth and reads as a delay
        opacity: root.expanded ? 1 : 0
        Behavior on opacity {
            Anim { type: Anim.FastEffects }
        }
        radius: Theme.radius
        color: Theme.surface
        implicitWidth: rows.implicitWidth + 16
        implicitHeight: rows.implicitHeight + 8
        width: implicitWidth
        height: implicitHeight

        Column {
            id: rows
            anchors.centerIn: parent
            spacing: root.extraGap

            IslandActionRow {
                glyph: "\u{F03E}"   // nf-fa-image — fullscreen shot
                label: "Fullscreen"
                tooltipText: "Screenshot workspace · <b>SUPER+SHIFT+S</b>"
                onActivated: root.shoot("now")
            }
            IslandActionRow {
                glyph: "\u{F125}"   // nf-fa-crop — area shot
                label: "Area"
                tooltipText: "Screenshot area · <b>SUPER+CTRL+SHIFT+S</b>"
                onActivated: root.shoot("area")
            }
        }
    }
}
