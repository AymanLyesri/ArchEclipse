import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.bar
import QtQuick.Controls
import QtQuick.Layouts

// Port of widgets/leftPanel/LeftPanel.tsx — side panel on the left edge.
// Anchored TOP | LEFT | BOTTOM, exclusive when enabled, hidden by default.
// Opened via HotZone dwell, SUPER+L keybind, or IPC togglePanel.
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen)
        return hmon ? hmon.name : screen.name
    }

    // Window geometry / layer
    anchors { left: true; top: true; bottom: true }
    implicitWidth: Settings.leftPanelWidth
    color: "transparent"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: Settings.leftPanelExclusivity ? width : -1
    WlrLayershell.layer: WlrLayer.Top

    // Selected widget state
    property string selectedWidget: "UserProfile"
    // Expose the StackLayout's current child so IPC can poke into the live
    // widget (loadBookmarks/pagedSlice/etc) without traversing the tree.
    // StackLayout has no currentItem property, only currentIndex + itemAt().
    readonly property var activeWidget: widgetStack.itemAt(widgetStack.currentIndex)

    // Map a tab name (matching the launcher's quick-app selectors) to a widget.
    function selectTab(name) {
        root.selectedWidget = name
    }

    // Register with Registry for IPC togglePanel
    Component.onCompleted: {
        Registry.register(`left-panel-${root.monitorName}`, root)
        visible = false
    }
    Component.onDestruction: {
        Registry.unregister(`left-panel-${root.monitorName}`)
    }

    // Idle hide timer (AGS: 0ms = next tick; matches Astal's "timeout 0")
    Timer {
        id: hideTimer
        interval: 0
        onTriggered: {
            if (!Settings.leftPanelLock) root.visible = false
        }
    }

    // Popup-open guard: any child of root that owns a visible Popup/PopupWindow
    // keeps the panel open even if the mouse leaves (AGS does this with
    // `popupIsOpen()` walking Astal's popup tree). root.children is sometimes
    // undefined on PanelWindow, so guard the iteration.
    property bool popupOpen: {
        const kids = root.children
        if (!kids || typeof kids.length !== "number") return false
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i]
            if (c && c.visible && c.activeFocus) return true
        }
        return false
    }

    // Hover handling — keep open while mouse is over panel or any child popup
    // is open (AGS guards on `popupIsOpen()` to avoid hiding under a menu).
    HoverHandler {
        id: panelHover
        enabled: true
        onHoveredChanged: {
            if (hovered) hideTimer.stop()
            else if (!Settings.leftPanelLock && !root.popupOpen) hideTimer.restart()
        }
    }

    // Main panel content
    Rectangle {
        id: panelBg
        anchors.fill: parent
        color: Theme.moduleBg
        radius: Theme.radius

        // Left sidebar with widget selectors
        Rectangle {
            id: sidebar
            width: 48
            height: parent.height
            color: Theme.bg
            radius: Theme.radius
            clip: true
            border.width: 1
            border.color: Theme.border

            // Widget selector buttons
            Column {
                id: selectorColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 8

                Repeater {
                    model: [
                        { name: "UserProfile",     icon: "\u{F007}" },
                        { name: "BooruViewer",     icon: "\u{F03E}" },
                        { name: "ChatBot",         icon: "\u{F4B8}" },
                        { name: "CustomScripts",   icon: "\u{F121}" },
                        { name: "Donations",       icon: "\u{2764}" },
                        { name: "KeyBinds",        icon: "\u{F11C}" },
                        { name: "MangaViewer",     icon: "\u{F02D}" },
                        { name: "SettingsWidget",  icon: "\u{F013}" }
                    ]
                    delegate: Button {
                        id: selectorBtn
                        checkable: true
                        checked: root.selectedWidget === modelData.name
                        padding: 10
                        contentItem: Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 20
                            font.family: "Font Awesome 6 Free"
                            // AGS: Donations not(:checked) text is dark blue on red bg
                            color: {
                                if (selectorBtn.checked) return Theme.accent
                                if (modelData.name === "Donations") return "#052d49"
                                return Theme.fg
                            }
                        }
                        background: Rectangle {
                            anchors.fill: parent
                            // AGS: .widget-actions .Donations:not(:checked) special red color
                            // to nudge users toward the support widget.
                            color: {
                                if (selectorBtn.checked) return Theme.accentBg
                                if (modelData.name === "Donations") return "#f96854"
                                return "transparent"
                            }
                            radius: 8
                            border.width: selectorBtn.checked ? 1 : 0
                            border.color: selectorBtn.checked ? Theme.accent
                                : (modelData.name === "Donations" ? "#f96854" : Theme.border)
                        }
                        ToolTip.visible: selectorBtn.hovered && selectorBtn.enabled
                        ToolTip.text: {
                            if (modelData.name === "Donations")
                                return "Click to open Donations\n<b>＼(o￣∇￣)／</b> — Support the project"
                            return "Click to open " + modelData.name
                        }
                        ToolTip.delay: 600
                        onClicked: {
                            root.selectedWidget = modelData.name
                        }
                    }
                }
            }

            // ── WindowActions — bottom cluster (AGS valign END, like RightPanel) ──
            Column {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                width: parent.width
                spacing: 4
                    Item { width: 1; height: 8 } // spacer
                    // Expand (+50 to max 1500)
                    Button {
                        width: parent.width
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: "󰽔"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: "Expand panel"; ToolTip.delay: 600
                        onClicked: { const v = Math.min(1500, Settings.leftPanelWidth + 50); Settings.leftPanelWidth = v; root.implicitWidth = v; }
                    }
                    // Shrink (−50 to min 250)
                    Button {
                        width: parent.width
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: "󰽕"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: "Shrink panel"; ToolTip.delay: 600
                        onClicked: { const v = Math.max(400, Settings.leftPanelWidth - 50); Settings.leftPanelWidth = v; root.implicitWidth = v; }
                    }
                    // Exclusivity (AGS: active = non-exclusive, inverted)
                    Button {
                        id: exclBtn
                        width: parent.width
                        checkable: true
                        checked: !Settings.leftPanelExclusivity
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: "\u{F2E0}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: exclBtn.checked ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: exclBtn.hovered ? Theme.moduleBg : (exclBtn.checked ? Theme.accentBg : "transparent"); radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: Settings.leftPanelExclusivity ? "Exclusive zone: on" : "Exclusive zone: off"; ToolTip.delay: 600
                        onToggled: Settings.leftPanelExclusivity = !checked
                    }
                    // Lock
                    Button {
                        id: lockBtn
                        width: parent.width
                        checkable: true
                        checked: Settings.leftPanelLock
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: lockBtn.checked ? "\u{F033E}" : "\u{F033F}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: lockBtn.checked ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: lockBtn.hovered ? Theme.moduleBg : (lockBtn.checked ? Theme.accentBg : "transparent"); radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: Settings.leftPanelLock ? "Unlock panel" : "Lock panel"; ToolTip.delay: 600
                        onToggled: Settings.leftPanelLock = checked
                    }
                    // Close
                    Button {
                        width: parent.width
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: ""; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.danger : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: "Close panel"; ToolTip.delay: 600
                        onClicked: root.visible = false
                    }
                } // WindowActions (bottom-pinned)
        }

        // Main content area
        Item {
            id: contentArea
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 8

            // Widget stack — StackLayout keeps all instantiated widgets alive
            // (AGS Gtk.Stack equivalent) so tab switches preserve scroll/page/
            // chat/booru state. Only the current one is visible; the others
            // exist in memory but don't paint, saving cost vs Loader recreate.
            StackLayout {
                id: widgetStack
                anchors.fill: parent
                currentIndex: {
                    switch (root.selectedWidget) {
                    case "UserProfile":     return 0
                    case "BooruViewer":     return 1
                    case "ChatBot":         return 2
                    case "CustomScripts":   return 3
                    case "Donations":       return 4
                    case "KeyBinds":        return 5
                    case "MangaViewer":     return 6
                    case "SettingsWidget":  return 7
                    default: return 0
                    }
                }
                UserProfileWidget {}
                BooruViewerWidget {}
                ChatBotWidget {}
                CustomScriptsWidget {}
                DonationsWidget {}
                KeyBindsWidget {}
                MangaViewerWidget {}
                SettingsWidget {}
            }

            // Default placeholder shown when currentIndex is invalid (AGS shows
            // an empty state when no tab is selected).
            Component {
                id: defaultWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text {
                        text: "Left Panel"
                        font.pixelSize: 24
                        color: Theme.fg
                    }
                    Text {
                        text: "Select a widget from the sidebar"
                        color: Theme.fgDim
                    }
                }
            }
        }
    }

    // Escape key closes panel
    Item {
        id: keyHandler
        focus: true
        Keys.onEscapePressed: {
            if (root.visible) {
                root.visible = false
                event.accepted = true
            }
        }
    }
}
