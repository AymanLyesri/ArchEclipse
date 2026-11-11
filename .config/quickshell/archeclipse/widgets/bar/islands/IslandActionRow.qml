import QtQuick
import qs.theme
import qs.widgets.bar.islands

// Labeled action row for the expanded side-pill layouts: a background-less ModeButton cell
// plus a label, running the same handlers. Rows paint nothing — the island card is the surface.
Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string tooltipText: ""
    signal activated()

    implicitWidth: row.implicitWidth
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spaceXs + 2

        ModeButton {
            glyph: root.glyph
            tooltipText: root.tooltipText
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeLabel
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
