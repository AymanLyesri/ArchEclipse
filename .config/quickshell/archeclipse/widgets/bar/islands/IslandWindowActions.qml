import QtQuick
import qs.theme
import qs.services
import qs.widgets.shared

// Shared bottom window-action cluster for the Left/Right side islands
// (valign END — the caller anchors this to the sidebar bottom).
//
// NOTE: the icon buttons + tooltips below are the existing user-visible
// strings, kept verbatim per side; only the layout and the left/right
// Settings keys are unified via `side`. (Settings.*Lock is a bool — the
// toggle writes the caller-driven `checked` value back exactly like the
// inline clusters this replaces.)
Column {
    id: root
    property string side: "left"  // "left" | "right"
    property string monitorName: ""
    spacing: 4
    readonly property bool isLeft: root.side === "left"
    readonly property int minWidth: root.isLeft ? 400 : 250
    readonly property bool locked: Settings.panelLockFor(root.side, root.monitorName)

    Item {
        width: 1
        height: 8
    } // spacer

    // Expand (+50 to max 1500)
    AppButton {
        width: parent.width
        icon: "";
        pixelSize: Theme.fontSizeLarge
        cornerRadius: Theme.chipRadius
        hoverBg: Theme.surface
        hoverFg: Theme.accent
        tooltipText: "Expand island"
        onClicked: {
            const width = Settings.panelWidthFor(root.side, root.monitorName);
            Settings.setPanelWidthFor(root.side, root.monitorName, width + 50);
        }
    }
    // Shrink (−50 to side min width)
    AppButton {
        width: parent.width
        icon: "";
        pixelSize: Theme.fontSizeLarge
        cornerRadius: Theme.chipRadius
        hoverBg: Theme.surface
        hoverFg: Theme.accent
        tooltipText: "Shrink island"
        onClicked: {
            const width = Settings.panelWidthFor(root.side, root.monitorName);
            Settings.setPanelWidthFor(root.side, root.monitorName, Math.max(root.minWidth, width - 50));
        }
    }
    // Lock — pins the island open across hover-leave.
    AppButton {
        width: parent.width
        icon: root.locked ? "" : "";
        pixelSize: Theme.fontSizeLarge
        cornerRadius: Theme.chipRadius
        toggle: true
        checked: root.locked
        hoverBg: Theme.surface
        tooltipText: root.locked ? "Unlock island" : "Lock island"
        onClicked: {
            Settings.setPanelLockFor(root.side, root.monitorName, !root.locked);
        }
    }
    // Close
    AppButton {
        width: parent.width
        icon: "";
        pixelSize: Theme.fontSizeLarge
        cornerRadius: Theme.chipRadius
        hoverBg: Theme.surface
        hoverFg: Theme.danger
        tooltipText: "Close island"
        onClicked: {
            if (root.isLeft)
                BarState.deactivate("left", root.monitorName);
            else
                BarState.deactivate("right", root.monitorName);
        }
    }
}
