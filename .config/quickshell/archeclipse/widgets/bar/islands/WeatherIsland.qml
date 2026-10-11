import QtQuick
import qs.widgets.weather
import qs.widgets.bar.islands

Item {
    id: root

    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    // Flush inside the pill: the bar's Theme.islandPad is the only inset.
    implicitWidth: card.implicitWidth
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: card.implicitHeight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        WeatherCard {
            id: card
            anchors.top: parent.top
            width: parent.width
            showForecast: true
        }
    }
    IslandHoverPin {
        stateName: "weather"
    }
}
