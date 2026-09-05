import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets.bar

// Port of barStates/CompactBar.tsx — [workspaces-compact | information | battery | volume]
Row {
    id: root
    spacing: Theme.sectionSpacing
    anchors.centerIn: parent

    Workspaces { compact: true; height: 24 }
    Information {}
    Battery {}
    Volume {}
}
