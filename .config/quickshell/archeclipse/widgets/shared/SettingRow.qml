import QtQuick
import QtQuick.Layouts
import qs.theme

// One unified settings row: tooltip label left, control(s) right via the default property, fixed
// height so rows align; labelWidth makes the control span the leftover space.
Item {
    id: root

    property alias text: label.text
    property alias tip: label.tip
    // -1 = label fills all spare width; >0 = fixed label width in px.
    property real labelWidth: -1
    default property alias content: layout.data

    width: parent.width
    height: 30

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacing

        SettingLabel {
            id: label
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: root.labelWidth < 0
            // Fixed labels shrink in narrow hosts (the column shares width with the category rail)
            // instead of starving the control; the label still elides with a full-text tooltip.
            Layout.preferredWidth: root.labelWidth < 0 ? 0 : Math.min(root.labelWidth, Math.max(64, root.width * 0.4))
        }
    }
}
