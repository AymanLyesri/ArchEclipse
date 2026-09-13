import QtQuick
import qs.widgets.bar.islands
import qs.widgets.media

// Player island now shows the full MediaWidget (cover art, track info,
// controls, seek bar) instead of the old title-only ticker.
// Size derives from the MediaWidget's implicit size — no hardcoded
// width/height here.
Item {
    id: root
    property int islandMargins: 4

    implicitWidth: media.implicitWidth + islandMargins * 2
    implicitHeight: media.implicitHeight + islandMargins * 2
    width: implicitWidth
    height: implicitHeight

    MediaWidget {
        id: media
        anchors.fill: parent
        anchors.margins: root.islandMargins
    }

    // Pin while hovered so the 2.5s pulse doesn't close it mid-interaction.
    // (The pin self-arms its leave timer at creation.)
    IslandHoverPin {
        stateName: "player"
    }
}
