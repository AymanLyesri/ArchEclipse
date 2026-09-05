import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar

// Port of barStates/ExpandedBar.tsx — centerbox: workspaces | information | utilities,
// each section toggleable via settings bar.layout[].enabled.
Row {
    id: root
    spacing: Theme.sectionSpacing

    Item {
        visible: Settings.barLayout.workspaces ?? false
        width: visible ? childrenRect.width : 0
        height: 24
        Workspaces { compact: false; height: 24 }
    }
    Information {
        visible: Settings.barLayout.information ?? false
        anchors.verticalCenter: parent.verticalCenter
    }
    Row {
        id: utilities
        visible: Settings.barLayout.utilities ?? false
        spacing: Theme.spacing

        Battery {}
        Brightness {}
        Volume {}
        Tray {}
        ResourceMonitor {}
        ControlPanelButton {}
    }
}
