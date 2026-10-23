import QtQuick
import QtQuick.Controls
import qs.services
import qs.theme
import qs.widgets.shared

// Supporter status card with upsell CTA.
Rectangle {
    id: root
    required property var store
    property string monitorName: ""
    width: parent.width
    implicitHeight: supporterCol.implicitHeight + 20
    visible: !!store.profile && store.profile.is_supporter !== null && store.profile.is_supporter !== undefined
    color: Theme.bg
    radius: Theme.radius
    Column {
        id: supporterCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: Theme.spacing
        Label {
            text: store.profile?.is_supporter === true ? "Supporter active" : "Member"
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            color: Theme.fg
        }
        Label {
            width: parent.width
            text: store.profile?.is_supporter === true ? ("Since " + store.formatTs(store.supporterSince)) : "Support the project to unlock Supporter status"
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fgDim
            wrapMode: Text.WordWrap
        }
        AppButton {
            width: parent.width
            tooltipText: "Open the Donations tab"
            text: store.profile?.is_supporter === true ? "View Donations" : "Become supporter"
            onClicked: Registry.selectLeftTab("Donations", undefined, root.monitorName)
        }
    }
}
