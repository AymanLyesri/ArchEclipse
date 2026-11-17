import QtQuick
import QtQuick.Controls
import qs.services
import qs.theme

// Supporter perk gate: greys the wrapped setting out and puts the donate nudge underneath.
// "No thanks" clears every gate until the next shell reload - a speed bump, not DRM.
Item {
    id: root

    // What the perk unlocks, read by the donate button's tooltip.
    property string perk: "this option"
    property string monitorName: ""
    readonly property bool locked: !Settings.supporterActive && !Settings.supporterGateWaived

    default property alias content: holder.data

    width: parent ? parent.width : 0
    implicitHeight: holder.implicitHeight + (root.locked ? actions.implicitHeight + Theme.spaceSm : 0)

    // Dimmed and inert, never hidden: the row still shows what a supporter would get back.
    Column {
        id: holder
        width: root.width
        enabled: !root.locked
        opacity: root.locked ? 0.4 : 1
        Behavior on opacity {
            Anim {}
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        y: holder.height + Theme.spaceSm
        visible: root.locked
        spacing: Theme.spaceSm

        AppButton {
            tooltipText: "Support the project to unlock " + root.perk
            icon: Icons.donate
            text: "Donate"
            pixelSize: Theme.fontSize - 1
            hPadding: Theme.spaceSm
            vPadding: Theme.spaceXs
            minHeight: 20
            onClicked: Registry.selectLeftTab("Donations", undefined, root.monitorName)
        }
        AppButton {
            tooltipText: "Unlock every gated setting until the next shell reload"
            text: "No thanks"
            pixelSize: Theme.fontSize - 1
            hPadding: Theme.spaceSm
            vPadding: Theme.spaceXs
            minHeight: 20
            onClicked: Settings.supporterGateWaived = true
        }
    }
}
