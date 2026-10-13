import QtQuick
import qs.services
import qs.theme

// App launcher button — Arch glyph, toggles the search/launcher island.
Rectangle {
    id: root

    width: 32
    implicitWidth: 32
    height: Theme.barContentHeight
    radius: Theme.radius
    color: searchHover.hovered ? Theme.surfaceHover : "transparent"

    Text {
        anchors.centerIn: parent
        text: "\uf002"
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 3
    }

    HoverHandler {
        id: searchHover
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (BarState.state === "search")
                BarState.deactivate("search");
            else {
                Launcher.pendingQuery = "";
                BarState.activate("search", 0);
            }
        }
    }
}
