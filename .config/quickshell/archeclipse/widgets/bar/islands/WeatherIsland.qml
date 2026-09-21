import QtQuick
import qs.widgets.weather
import qs.widgets.bar.islands

Item {
    id: root
    property int islandMargins: 5

    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    implicitWidth: card.implicitWidth + islandMargins * 2
    implicitHeight: clip.height + islandMargins * 2
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: card.implicitHeight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.islandMargins
        anchors.leftMargin: root.islandMargins
        anchors.rightMargin: root.islandMargins

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
