import QtQuick
import qs.theme

// Shared left navigation panel for Booru/Manga/ChatBot: CategoryRail entries on top and
// a widget-owned controls area below. Hosts own the model/selection and the controls.
// Width is draggable on the right edge and persists via Settings.leftNavPanelWidth.
Item {
    id: root

    // Writable on purpose: the drag handle rewrites it; Settings persists on release.
    property int panelWidth: (typeof Settings !== "undefined") ? Settings.leftNavPanelWidth : 128
    readonly property int minWidth: 96

    property var navModel: []
    property int navCurrentIndex: 0
    signal navSelected(int index)

    default property alias content: body.data

    width: root.panelWidth

    Column {
        id: colPanel

        // Narrower than the panel: leaves a gap before the grip line on the right edge.
        width: parent.width - 8
        height: parent.height
        spacing: Theme.spacing

        CategoryRail {
            id: navBar

            width: parent.width
            model: root.navModel
            currentIndex: root.navCurrentIndex
            onSelected: index => root.navSelected(index)
        }

        Item {
            id: body

            width: parent.width
            height: Math.max(0, colPanel.height - navBar.height - colPanel.spacing)
            clip: true
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: gripArea.containsMouse || gripArea.pressed ? Theme.accent : Theme.border
        Behavior on color {
            CAnim {}
        }
    }

    // Drag handle on the panel's right edge. Lives outside the Column: a positioner
    // would lay it out and ignore its anchors.
    MouseArea {
        id: gripArea

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor

        property int _startGlobal: 0
        property int _startWidth: 0

        onPressed: {
            _startGlobal = root.width - width + mouseX;
            _startWidth = root.panelWidth;
        }
        onPositionChanged: {
            if (!pressed)
                return;
            const global = root.width - width + mouseX;
            // The cap is the widget's own width (the island body), not the panel's —
            // `parent` here is the panel itself, so parent.width - 240 is nonsense.
            const maxW = Math.max(root.minWidth, (root.parent ? root.parent.width : 0) - 240);
            root.panelWidth = Math.min(maxW, Math.max(root.minWidth, Math.round(_startWidth + (global - _startGlobal))));
        }
        onReleased: if (typeof Settings !== "undefined")
            Settings.leftNavPanelWidth = root.panelWidth
    }
}
