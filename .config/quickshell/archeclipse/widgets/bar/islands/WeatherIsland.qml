import QtQuick
import qs.widgets.weather
import qs.widgets.bar.islands

Item {
    id: root
    property int islandMargins: 5
    implicitWidth: card.implicitWidth + islandMargins * 2
    implicitHeight: card.implicitHeight + islandMargins * 2
    width: implicitWidth
    height: implicitHeight
    WeatherCard {
        id: card
        anchors.fill: parent
        anchors.margins: root.islandMargins
        showForecast: true
    }
    IslandHoverPin {
        stateName: "weather"
    }
}
