import QtQuick
import qs.theme
import qs.widgets.bar.islands

// Labeled action row for the expanded side-pill layouts (record /
// screenshot launcher expansion): a pill-card with the shared inert
// ModeButton cell plus a text label, re-representing a compact-stadium
// mode button as its own row (no new actions — same handlers). Row cards
// live OUTSIDE the stadium clip as siblings, styled by Theme like
// everything else.
Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property string tooltipText: ""
    signal activated()

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 22
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: Theme.surface

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        ModeButton {
            glyph: root.glyph
            tooltipText: root.tooltipText
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
