import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.controlPanel

// Quick-settings body that lives INSIDE DefaultBar's center pill. Clicking
// the gear swaps the band row (bandwidth | gear | clock) for this card: the
// panel opens out of the center pill's own footprint (iris, see below) and
// the bar pill grows around it, so it reads as the center pill opening rather
// than a card hanging off the bar. Replaces the old ControlIsland page: the
// pill height, the left/right zones and the workspace strip all stay where
// they are (the bar collapses to the panel's width and the strip is pushed
// below it).
//
// Nothing paints here — while open the surface is the bar pill itself
// (DefaultBar hides the bump's PillBackground so the panel doesn't
// double-blend over it). This item owns the unfold clip, the hover pin and
// Esc only.
Item {
    id: root

    property string monitorName: ""

    // Driven by DefaultBar: BarState.stateFor(monitor) === "control".
    property bool open: false
    // Resting width of the bar's band row (the center pill's collapsed
    // width), handed down by DefaultBar. The unfold seeds its iris from this
    // rect so the panel grows out of the center pill instead of fading in at
    // full width. 0 (bar not laid out yet) falls back to the full card so an
    // early open still animates instead of starting invisible.
    property real fromWidth: 0
    // Cursor is on the bar band (i.e. on the gear that opened us). Holds the
    // hover pin so the open-grace can't shut the card while the pointer sits
    // on the button.
    property bool bandHovered: false

    // Fold driver: `shown` keeps the body (and the clip) alive through the
    // close fold; `openT` is what IslandExpandClip animates.
    property bool shown: false
    property real openT: 0
    // Remembered across the body's destruction so a reopen animates from the
    // body's real height even before the Loader finishes.
    property real bodyHeight: 0

    readonly property real cardWidth: (bodyLoader.item ? bodyLoader.item.width : 680) + Theme.islandPad * 2
    // Visible extent right now (0 while closed). DefaultBar sizes the center
    // pill and the bar's height from this, which is what pushes the
    // workspace strip down as the panel opens.
    readonly property real cardHang: root.shown ? root.height : 0

    width: cardWidth
    height: cardClip.height

    onOpenChanged: root.syncOpen()
    Component.onCompleted: root.syncOpen()
    function syncOpen() {
        if (root.open) {
            closeTimer.stop();
            root.shown = true;
            // Fresh open-grace on every open (the pin outlives closes).
            // While the band is hovered the pin is held instead — leaving the
            // band then arms it, so no timer needs to run now.
            if (!root.bandHovered)
                hoverPin.arm();
            // Body already alive (reopen mid-fold): unfold straight away.
            // First open: bodyLoader.onLoaded unfolds once it is measured.
            if (bodyLoader.item)
                root.openT = 1;
        } else {
            if (!root.shown)
                return;
            root.openT = 0;
            closeTimer.restart();
        }
    }
    Timer {
        id: closeTimer
        interval: cardClip.expandDuration
        onTriggered: root.shown = false
    }

    // Hover pin: the card (or the band) holds control pinned; leaving both
    // arms the reveal-out timer. Sliders/ComboBox popups need the explicit
    // hold — HoverHandler.hovered drops while a button is pressed, and the
    // popup renders outside these bounds.
    IslandHoverPin {
        id: hoverPin
        stateName: "control"
        monitorName: root.monitorName
        // The card (and its pin) live as long as the bar page does, so the
        // creation arm is off — syncOpen() arms a fresh grace per open.
        armOnCreation: false
        holdOpen: root.bandHovered || (bodyLoader.item ? (bodyLoader.item.adjusting || bodyLoader.item.popupOpen) : false)
    }

    // Esc dismiss only while the card exists: an always-present grabber
    // would keep a focused 1x1 item on the bar page for its whole lifetime
    // (every other island ships its grabber with the island's lifetime).
    Loader {
        active: root.shown
        sourceComponent: escPage
        Component {
            id: escPage
            IslandEscClose {
                states: ["control"]
                monitorName: root.monitorName
            }
        }
    }

    IslandExpandClip {
        id: cardClip
        // Anchored to the bump's wall edge: down for a top bar, up for a
        // bottom bar — and centred, so the iris opens symmetrically instead
        // of growing off one side.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: Settings.barOrientation ? parent.top : undefined
        anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
        expand: root.openT
        contentHeight: root.bodyHeight + Theme.islandPad * 2
        // Iris: the clip opens from the center pill's resting rect (same
        // width as the band row, one band tall) to the panel's full size.
        // The island opacity ramp is kept on purpose: the pill and the body
        // cross-fade in while the window grows, exactly like an island
        // unfold, instead of the panel snapping to full strength.
        startWidth: root.fromWidth > 0 ? root.fromWidth : root.cardWidth
        startHeight: Theme.barContentHeight

        // Content wrapper: glued to the wall edge so the unfold reveals the
        // panel outward from the bar (mirrored for a bottom bar), and
        // centred on the clip so the iris reveals it symmetrically instead
        // of sliding it in from one side while the clip is still narrow.
        Item {
            id: cardSurface
            width: root.width
            height: cardClip.contentHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: Settings.barOrientation ? parent.top : undefined
            anchors.bottom: Settings.barOrientation ? undefined : parent.bottom

            Loader {
                id: bodyLoader
                x: Theme.islandPad
                y: Theme.islandPad
                active: root.shown
                asynchronous: false
                sourceComponent: bodyPage
                onLoaded: {
                    if (item && item["monitorName"] !== undefined)
                        item.monitorName = root.monitorName;
                    root.bodyHeight = item ? item.height : 0;
                    if (root.open)
                        root.openT = 1;
                }
            }

            // The body is not a fixed size: expanding the volume section
            // grows VolumeSection (its own height Behavior), which grows
            // ControlPanelBody. Track it live — reading the height once on
            // load left the clip (and the pill, and the strip below it)
            // stuck at the collapsed size, so the section opened into a
            // clipped box.
            Connections {
                target: bodyLoader.item
                ignoreUnknownSignals: true
                function onHeightChanged() {
                    if (bodyLoader.item)
                        root.bodyHeight = bodyLoader.item.height;
                }
            }

            Component {
                id: bodyPage
                ControlPanelBody {}
            }
        }
    }
}
