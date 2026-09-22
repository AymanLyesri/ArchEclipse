import QtQuick
import QtQuick.Controls
import qs.theme

ComboBox {
    id: root

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    contentItem: Text {
        leftPadding: 8
        rightPadding: root.indicator.width + root.spacing
        text: root.displayText
        font: root.font
        color: Theme.fg
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 28
        color: Theme.surface
        border.color: root.activeFocus || root.popup.visible ? Theme.accent : Theme.border
        border.width: 1
        radius: 6
    }

    indicator: Text {
        x: root.width - width - 8
        y: root.topPadding + (root.availableHeight - height) / 2
        text: root.popup.visible ? "▲" : "▼"
        font.pixelSize: Theme.fontSizeCaption
        font.family: Theme.fontFamily
        color: Theme.fg
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: contentItem.implicitHeight
        padding: 4
        background: Rectangle {
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            radius: 6
        }
        contentItem: SmoothListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }

    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: root.width - 8
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: typeof modelData === "string" ? modelData : (modelData?.display ?? modelData?.name ?? "")
            font: root.font
            color: parent.highlighted ? Theme.accent : Theme.fg
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 4
            color: parent.highlighted ? Theme.surfaceActive : "transparent"
            border.color: parent.highlighted ? Theme.border : "transparent"
            border.width: 1
        }
    }
}
