import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.shared

// Screenshot island: idle-only stadium mirroring the record pill, each click spawning
// screenshot.sh detached. No hover machinery — hover-driven resizes flap the reveal.
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
    // rows block that the card carries beyond the band: rows plus the
    // card's 4px outer padding (the band-side gap is extraGap)
    readonly property real rowsBlockW: shotRows.implicitWidth + 16
    readonly property real rowsBlockH: shotRows.implicitHeight + 4
    // band offset while grown: clears the stacked rows above/below
    readonly property real extraH: root.extraT * (root.extraGap + root.rowsBlockH)
    // the card IS the island: band + rows, one background
    implicitHeight: Theme.sidePillHeight + root.extraH
    height: implicitHeight
    width: Math.max(root.pillW, root.expanded ? root.rowsBlockW : 0)
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

    // Spawn via the Screenshot service, never a Process here: this island is destroyed when the
    // reveal folds, which kills a child Process mid-slurp and grim never gets the region.
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
        // opposite edge pinned to the band: the card wipes away from the
        // screen edge on bottom bars (opposite on top bars)
        y: root.growUp ? root.height - clip.height : 0
        expand: root.expand
        contentHeight: root.implicitHeight

        Item {
            id: body
            width: root.width
            height: root.implicitHeight
            // band stays parked at its edge while the card grows
            anchors.bottom: root.growUp ? parent.bottom : undefined
            anchors.top: root.growUp ? undefined : parent.top

            // ONE background for the whole island: band + rows share it, so
            // the expanded stack reads as one card, not a chip plus a sheet
            Rectangle {
                anchors.fill: parent
                // stadium only while a bare band; the grown card is rounded (radius never
                // height/2, which a tall card bows into a lozenge)
                radius: root.extraT > 0 ? Theme.radius : Theme.sidePillHeight / 2
                Behavior on radius {
                    Anim {
                        duration: Theme.anim.fastSpatial
                    }
                }
                color: Theme.surface
            }

            // band: camera cell + mode buttons (expanded parks the buttons)
            Item {
                id: band
                width: parent.width
                height: Theme.sidePillHeight
                y: root.growUp ? parent.height - height : 0

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
                        // park while the expansion re-represents the modes as rows; return at the
                        // flip, not the end of the unwind — late reads as clipping then popping
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

            // ---- launcher-expanded rows: modes re-represented on the SAME card as the band ----
            // Reveal rides extraT, rows stay laid out while extraT > 0; handlers unchanged.
            Column {
                id: shotRows
                x: (parent.width - width) / 2
                // away from the screen edge: above the band on bottom bars, below on top ones —
                // 4px card padding at the outer end, extraGap between rows and band
                y: root.growUp ? 4 : Theme.sidePillHeight + root.extraGap
                visible: root.extraT > 0
                // fade rides its OWN fast stem (like the weather stats rows), never extraT —
                // opacity tracking the geometry gates the rows and reads as a delay
                opacity: root.expanded ? 1 : 0
                Behavior on opacity {
                    Anim { type: Anim.FastEffects }
                }
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
}
