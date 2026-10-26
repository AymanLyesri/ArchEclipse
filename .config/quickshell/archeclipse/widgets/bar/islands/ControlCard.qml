import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.controlPanel
import qs.widgets.shared

// Quick-settings body that lives INSIDE DefaultBar's center pill. Clicking
// the gear swaps the band row (bandwidth | gear | clock) for this card and
// DefaultBar grows the center pill's own box around it: that box's real
// width/height are driven by `openT`, so the surface expands out of the band
// footprint and retracts back into it. There is no inner iris/clip animation
// faking the unfold — DefaultBar clips the card to the real pill box.
//
// Nothing paints here — while open the surface is the bar pill itself
// (DefaultBar hands the bump fill off to it). This item owns the unfold
// driver, the hover pin and Esc only.
Item {
    id: root

    property string monitorName: ""

    // Driven by DefaultBar: BarState.stateFor(monitor) === "control".
    property bool open: false
    // Only the unfold lifetime exists on screen: hiding the card while it is
    // folded also disables its hover pin, so brushing the band bump can never
    // open quick settings without a click.
    visible: root.shown
    // Cursor is on the bar band (i.e. on the gear that opened us). Holds the
    // hover pin so the open-grace can't shut the card while the pointer sits
    // on the button.
    property bool bandHovered: false

    // Unfold driver: 0 = band footprint, 1 = full panel. DefaultBar turns this
    // into the center pill's real width/height, so this is the only animation
    // source for the transition.
    property real openT: 0
    Behavior on openT {
        enabled: Settings.animationsEnabled
        Anim {
            type: {
                const s = Settings.islandAnimStyle;
                if (s === "Standard")
                    return Anim.Standard;
                if (s === "ExpressiveFast")
                    return Anim.FastSpatial;
                if (s === "ExpressiveDefault")
                    return Anim.DefaultSpatial;
                if (s === "ExpressiveSlow")
                    return Anim.SlowSpatial;
                return Anim.Emphasized;
            }
        }
    }

    // Fold driver: `shown` keeps the body alive through the close retract;
    // `openT` is the geometry DefaultBar animates.
    property bool shown: false
    // True for the length of the unfold/retract. DefaultBar uses it to make
    // the bar pill track the moving center-pill box rigidly (a Behavior chasing
    // a target that changes every frame never catches up).
    property bool gliding: false
    // Remembered across the body's destruction so a reopen animates from the
    // body's real height even before the Loader finishes.
    property real bodyHeight: 0

    readonly property real cardWidth: (bodyLoader.item ? bodyLoader.item.width : 680) + Theme.islandPad * 2
    // Full unfolded extent. DefaultBar interpolates from the band footprint
    // to this with `openT`, then tracks it live while open (the volume section
    // grows after the unfold).
    readonly property real cardHang: root.shown ? root.height : 0
    // Must match the duration of the Behavior above (close timers wait exactly
    // this long).
    readonly property int expandDuration: {
        if (!Settings.animationsEnabled)
            return 0;
        const s = Settings.islandAnimStyle;
        if (s === "ExpressiveFast")
            return Theme.anim.fastSpatial;
        if (s === "ExpressiveDefault")
            return Theme.anim.defaultSpatial;
        if (s === "ExpressiveSlow")
            return Theme.anim.slowSpatial;
        return Theme.anim.normal; // Standard + Emphasized both = normal
    }

    width: cardWidth
    height: root.bodyHeight + Theme.islandPad * 2

    onOpenChanged: root.syncOpen()
    Component.onCompleted: root.syncOpen()
    function syncOpen() {
        if (root.open) {
            root.shown = true;
            // Fresh open-grace on every open (the pin outlives closes).
            // While the band is hovered the pin is held instead — leaving the
            // band then arms it, so no timer needs to run now.
            if (!root.bandHovered)
                hoverPin.arm();
            // Body already alive (reopen mid-retract): unfold straight away.
            // First open: bodyLoader.onLoaded unfolds once it is measured.
            if (bodyLoader.item) {
                root.beginGlide();
                root.openT = 1;
            }
        } else {
            if (!root.shown)
                return;
            if (!Settings.animationsEnabled) {
                root.openT = 0;
                root.shown = false;
                root.gliding = false;
                return;
            }
            root.beginGlide();
            root.openT = 0;
        }
    }
    // Explicit glide window (the Behavior on openT has no `running` to read):
    // exactly one unfold duration, started on every openT assignment. When a
    // retract finishes it also drops the body — before then the card stays
    // alive so the closing pill never reveals an empty box.
    function beginGlide() {
        root.gliding = true;
        glideTimer.restart();
    }
    Timer {
        id: glideTimer
        interval: root.expandDuration
        onTriggered: {
            root.gliding = false;
            if (!root.open)
                root.shown = false;
        }
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
            if (root.open) {
                root.beginGlide();
                root.openT = 1;
            }
        }
    }

    // The body is not a fixed size: expanding the volume section grows
    // VolumeSection (its own height Behavior), which grows ControlPanelBody.
    // Track it live — reading the height once on load left the pill (and the
    // strip below it) stuck at the collapsed size.
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
