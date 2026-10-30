import QtQuick
import Quickshell.Hyprland
import qs.services
import qs.theme

// Focused window title button — icon + active window title, elided.
// Click toggles the overview island.
Rectangle {
    id: root

    property string monitorName: ""

    height: Theme.barContentHeight
    implicitWidth: content.implicitWidth + 16
    // Width is assigned by the parent layout (capped at the use site); implicitWidth carries
    // the natural size so no width binding fights the layout.
    radius: Theme.radius
    color: titleHover.hovered ? Theme.surfaceHover : "transparent"

    readonly property var active: Hyprland.activeToplevel ?? null
    readonly property string winClass: {
        Hyprland.toplevels.values;
        const t = Hyprland.activeToplevel;
        if (!t)
            return "";
        try {
            return WorkspaceIcons.classForToplevel(t);
        } catch (e) {
            return "";
        }
    }
    readonly property string winTitle: {
        Hyprland.toplevels.values;
        const t = Hyprland.activeToplevel;
        if (!t)
            return "Desktop";
        const title = ((t.title ?? "") + "").trim();
        if (title !== "")
            return title;
        try {
            const ipc = ((t.lastIpcObject?.title ?? "") + "").trim();
            if (ipc !== "")
                return ipc;
        } catch (e) {}
        const cls = root.winClass.trim();
        return cls !== "" ? cls : "Desktop";
    }
    readonly property string winIcon: root.winClass !== "" ? WorkspaceIcons.forClientClass(root.winClass) : Icons.windowIcon
    // Elide bound from the bar (layout cap minus pill chrome). Upstream-only on purpose —
    // deriving it from the Row width collapses to a 0-width fixed point.
    property real textMaxWidth: 190

    Row {
        id: content
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing
        width: Math.max(0, Math.min(implicitWidth, parent.width - 16))

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.winIcon
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            text: root.winTitle
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            clip: true
            width: Math.min(implicitWidth, root.textMaxWidth)
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }


    HoverHandler {
        id: titleHover
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (BarState.isOpenFor("overview", root.monitorName))
                BarState.deactivate("overview", root.monitorName);
            else
                BarState.activate("overview", 0, root.monitorName);
        }
    }
}
