import QtQuick
import QtQuick.Controls
import qs.services
import qs.theme

// Supporter perk gate: greys the wrapped setting out and puts the donate nudge underneath.
// "Donate" and "No thanks" both clear ONLY the gate they were pressed on, and only until the
// next shell reload - a speed bump, not DRM, and a deliberate one: every gated setting has to
// be dismissed on its own.
Item {
    id: root

    // What the perk unlocks, read by the donate button's tooltip. Also the waiver key, so two
    // gates wrapping the same perk share one decision.
    property string perk: "this option"
    property string monitorName: ""
    readonly property bool waived: Settings.supporterGateWaived[root.perk] === true
    readonly property bool locked: !Settings.supporterActive && !root.waived

    default property alias content: holder.data

    width: parent ? parent.width : 0
    implicitHeight: holder.implicitHeight + (root.locked ? actions.implicitHeight + Theme.spaceSm : 0)

    // The waiver lives in Settings (session-only) rather than on the gate: the settings page is
    // rebuilt on every panel open, so a local flag would re-lock what the user just dismissed.
    // A fresh object is assigned because mutating the map in place fires no change signal.
    function waive() {
        const map = Object.assign({}, Settings.supporterGateWaived || {});
        map[root.perk] = true;
        Settings.supporterGateWaived = map;
    }

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

        // Same plate as the Donations tab cell in the left rail: solid #f96854, dark ink at rest,
        // bold label, no border; on hover the plate hands over to the shared wash and the ink
        // goes white with it.
        AppButton {
            tooltipText: "Support the project to unlock " + root.perk
            icon: Icons.coffee
            text: "Donate"
            pixelSize: Theme.fontSize - 1
            hPadding: Theme.spaceSm
            vPadding: Theme.spaceXs
            minHeight: 20
            bold: true
            outlined: false
            idleBg: "#f96854"
            idleFg: "#052d49"
            hoverBg: Theme.surfaceHover
            hoverFg: "white"
            onClicked: {
                root.waive();
                Registry.selectLeftTab("Donations", undefined, root.monitorName);
            }
        }
        AppButton {
            tooltipText: "Unlock this setting until the next shell reload"
            text: "No thanks"
            pixelSize: Theme.fontSize - 1
            hPadding: Theme.spaceSm
            vPadding: Theme.spaceXs
            minHeight: 20
            onClicked: root.waive()
        }
    }
}
