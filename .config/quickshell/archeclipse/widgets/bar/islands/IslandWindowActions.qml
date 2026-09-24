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
    spacing: 4
    readonly property bool isLeft: root.side === "left"
    readonly property int minWidth: root.isLeft ? 400 : 250

    Item {
        width: 1
        height: 8
    } // spacer

    // Expand (+50 to max 1500)
    AppButton {
        width: parent.width
        icon: "";
        pixelSize: 14
        cornerRadius: 6
        hoverBg: Theme.surface
        hoverFg: Theme.accent
        tooltipText: "Expand island"
        onClicked: {
            if (root.isLeft)
                Settings.leftPanelWidth = Math.min(1500, Settings.leftPanelWidth + 50);
            else
                Settings.rightPanelWidth = Math.min(1500, Settings.rightPanelWidth + 50);
        }
    }
    // Shrink (−50 to side min width)
    AppButton {
        width: parent.width
        icon: "";
        pixelSize: 14
        cornerRadius: 6
        hoverBg: Theme.surface
        hoverFg: Theme.accent
        tooltipText: "Shrink island"
        onClicked: {
            if (root.isLeft)
                Settings.leftPanelWidth = Math.max(400, Settings.leftPanelWidth - 50);
            else
                Settings.rightPanelWidth = Math.max(250, Settings.rightPanelWidth - 50);
        }
    }
    // Lock — pins the island open across hover-leave.
    AppButton {
        width: parent.width
        icon: (root.isLeft ? Settings.leftPanelLock : Settings.rightPanelLock) ? "" : "";
        pixelSize: 14
        cornerRadius: 6
        toggle: true
        checked: root.isLeft ? Settings.leftPanelLock : Settings.rightPanelLock
        hoverBg: Theme.surface
        tooltipText: (root.isLeft ? Settings.leftPanelLock : Settings.rightPanelLock) ? "Unlock island" : "Lock island"
        onClicked: {
            if (root.isLeft)
                Settings.leftPanelLock = !checked;
            else
                Settings.rightPanelLock = !checked;
        }
    }
    // Close
    AppButton {
        width: parent.width
        icon: "";
        pixelSize: 14
        cornerRadius: 6
        hoverBg: Theme.surface
        hoverFg: Theme.danger
        tooltipText: "Close island"
        onClicked: {
            if (root.isLeft)
                BarState.deactivate("left");
            else
                BarState.deactivate("right");
        }
    }
}
