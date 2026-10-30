import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.controlPanel
import qs.widgets.shared

// Quick-settings body inside DefaultBar's center pill: `openT` drives the pill's real
// width/height, so the surface expands out of the band footprint with no iris animation.
Item {
    id: root

    property string monitorName: ""

    // Driven by DefaultBar: BarState.stateFor(monitor) === "control".
    property bool open: false
    // Only the unfold lifetime exists on screen: hiding the card while folded also disables
    // its hover pin, so brushing the band bump can never open quick settings.
    visible: root.shown
    // Cursor on the bar band (the gear that opened us): holds the hover pin so the
    // open-grace cannot shut the card under the pointer.
    property bool bandHovered: false

    // Unfold driver: 0 = band footprint, 1 = full panel — the only animation source for
    // DefaultBar's center-pill width/height.
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
    // True through the unfold/retract: DefaultBar then tracks the moving box rigidly (a
    // Behavior chasing a per-frame target never catches up).
    property bool gliding: false
    // Remembered across the body's destruction so a reopen animates from the
    // body's real height even before the Loader finishes.
    property real bodyHeight: 0

    readonly property real cardWidth: (bodyLoader.item ? bodyLoader.item.width : 680) + Theme.islandPad * 2
    // Full unfolded extent: DefaultBar interpolates to it with `openT`, then tracks it live
    // while open (the volume section grows after the unfold).
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
            // Fresh open-grace on every open (the pin outlives closes); while the band is
            // hovered the pin is held instead, and leaving it arms the timer.
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
    // Explicit glide window (the Behavior has no `running`): one unfold duration per
    // assignment; a finished retract drops the body so the closing pill stays filled.
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

    // Hover pin: the card or the band holds control pinned; leaving both arms the
    // reveal-out timer. Sliders need the hold — hovered drops while a button is pressed.
    IslandHoverPin {
        id: hoverPin
        stateName: "control"
        monitorName: root.monitorName
        // The card (and its pin) live as long as the bar page does, so the
        // creation arm is off — syncOpen() arms a fresh grace per open.
        armOnCreation: false
        holdOpen: root.bandHovered || (bodyLoader.item ? (bodyLoader.item.adjusting || bodyLoader.item.popupOpen) : false)
    }

    // Esc dismiss only while the card exists: an always-present grabber would keep a
    // focused 1x1 item on the bar page for its whole lifetime.
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

    // The body is not fixed size: expanding volume grows VolumeSection and ControlPanelBody.
    // Track it live — reading the height once left pill and strip stuck collapsed.
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
