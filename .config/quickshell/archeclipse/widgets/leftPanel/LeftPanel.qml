import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets.bar
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

    // Selected widget — initialized from persisted Settings (AGS restores
    // leftPanel.widget from settings.json) and written back on change.
    property string selectedWidget: Settings.leftPanelWidget
    onSelectedWidgetChanged: {
        if (Settings.leftPanelWidget !== selectedWidget)
            Settings.leftPanelWidget = selectedWidget
        switchAnim.restart()
    }
    Connections {
        target: Settings
        function onLeftPanelWidgetChanged() {
            if (root.selectedWidget !== Settings.leftPanelWidget)
                root.selectedWidget = Settings.leftPanelWidget
        }
    }
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

    // Main panel content (AGS marginTop/Bottom 5 + .left-panel margin-left 5px)
    Rectangle {
        id: panelBg
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.topMargin: 5
        anchors.bottomMargin: 5
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
                    // Order + icons mirror AGS leftPanelWidgetSelectors
                    // (widget.constants.ts): UserProfile, BooruViewer,
                    // ChatBot, MangaViewer, Settings, CustomScripts,
                    // KeyBinds, Donations. Names keep the QS "Widget"
                    // suffix (IPC showWidget/widgetState compat).
                    model: [
                        { name: "UserProfile",     icon: "\u{F007}" },
                        { name: "BooruViewer",     icon: "\u{F03E}" },
                        { name: "ChatBot",         icon: "\u{EE0D}" },
                        { name: "MangaViewer",     icon: "\u{EAA4}" },
                        { name: "SettingsWidget",  icon: "\u{F013}" },
                        { name: "CustomScripts",   icon: "\u{F120}" },
                        { name: "KeyBinds",        icon: "\u{F11C}" },
                        { name: "Donations",       icon: "\u{F0F4}" }
                    ]
                    // Same 40px cell structure as RightPanel's widget
                    // selectors: fixed-height full-width cell, icon centered.
                    delegate: Item {
                        required property var modelData
                        width: selectorColumn.width
                        height: 40
                        Button {
                            id: selectorBtn
                            anchors.fill: parent
                            checkable: true
                            checked: root.selectedWidget === modelData.name
                            contentItem: Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 20
                                font.family: "Font Awesome 6 Free"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
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
                    // Expand (+50 to max 1500, AGS WindowActions defaults)
                    Button {
                        width: parent.width
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: "\u{F067}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: "Expand panel"; ToolTip.delay: 600
                        // implicitWidth tracks Settings via binding — only
                        // write the setting (AGS setGlobalSetting + queueResize).
                        onClicked: Settings.leftPanelWidth = Math.min(1500, Settings.leftPanelWidth + 50)
                    }
                    // Shrink (−50 to min 400, AGS LeftPanel minPanelWidth={400})
                    Button {
                        width: parent.width
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: "\u{F068}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: "Shrink panel"; ToolTip.delay: 600
                        onClicked: Settings.leftPanelWidth = Math.max(400, Settings.leftPanelWidth - 50)
                    }
                    // Exclusivity (AGS: active = non-exclusive, inverted)
                    Button {
                        id: exclBtn
                        width: parent.width
                        checkable: true
                        checked: !Settings.leftPanelExclusivity
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: "\u{F2D2}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: exclBtn.checked ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: exclBtn.hovered ? Theme.moduleBg : (exclBtn.checked ? Theme.accentBg : "transparent"); radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: Settings.leftPanelExclusivity ? "Exclusive zone: on" : "Exclusive zone: off"; ToolTip.delay: 600
                        onToggled: Settings.leftPanelExclusivity = !checked
                    }
                    // Lock (AGS FA lock F023 / unlock F2FC)
                    Button {
                        id: lockBtn
                        width: parent.width
                        checkable: true
                        checked: Settings.leftPanelLock
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: lockBtn.checked ? "\u{F023}" : "\u{F2FC}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: lockBtn.checked ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { anchors.fill: parent; color: lockBtn.hovered ? Theme.moduleBg : (lockBtn.checked ? Theme.accentBg : "transparent"); radius: 6 }
                        ToolTip.visible: hovered; ToolTip.text: Settings.leftPanelLock ? "Unlock panel" : "Lock panel"; ToolTip.delay: 600
                        onToggled: Settings.leftPanelLock = checked
                    }
                    // Close (AGS WindowActions close F00D)
                    Button {
                        width: parent.width
                        padding: 8
                        contentItem: Text { anchors.centerIn: parent; text: "\u{F00D}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.danger : Theme.fg; horizontalAlignment: Text.AlignHCenter }
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
            // Order mirrors AGS leftPanelWidgetSelectors.
            // Fade-in on switch mirrors AGS `.main-content > *` opacity-in 0.6s.
            OpacityAnimator on opacity {
                id: switchAnim
                from: 0; to: 1
                duration: 600
                easing.type: Easing.OutCubic
            }
            StackLayout {
                id: widgetStack
                anchors.fill: parent
                currentIndex: {
                    switch (root.selectedWidget) {
                    case "UserProfile":     return 0
                    case "BooruViewer":     return 1
                    case "ChatBot":         return 2
                    case "MangaViewer":     return 3
                    case "SettingsWidget":  return 4
                    case "CustomScripts":   return 5
                    case "KeyBinds":        return 6
                    case "Donations":       return 7
                    default: return 0
                    }
                }
                UserProfileWidget {}
                BooruViewerWidget {}
                ChatBotWidget {}
                MangaViewerWidget {}
                SettingsWidget {}
                CustomScriptsWidget {}
                KeyBindsWidget {}
                DonationsWidget {}
            }
        }
    }

    // Escape key closes panel (regrab focus when shown so it works even
    // after interacting with a TextField inside a widget)
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
    onVisibleChanged: { if (visible) keyHandler.forceActiveFocus() }
}
