import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.shared
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
                        AppButton {
                            anchors.fill: parent
                            icon: modelData.icon
                            toggle: true
                            checked: root.selectedWidget === modelData.name
                            // AGS: .widget-actions .Donations special red color
                            // to nudge users toward the support widget.
                            idleBg: modelData.name === "Donations" ? "#f96854" : "transparent"
                            idleFg: modelData.name === "Donations" ? "#052d49" : Theme.fg
                            borderColor: modelData.name === "Donations" ? "#f96854" : Theme.accent
                            tooltipText: modelData.name === "Donations"
                                ? "Click to open Donations\n<b>＼(o￣∇￣)／</b> — Support the project"
                                : "Click to open " + modelData.name
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
                    AppButton {
                        width: parent.width
                        icon: "\u{F067}"
                        pixelSize: 14
                        cornerRadius: 6
                        hoverBg: Theme.moduleBg
                        hoverFg: Theme.accent
                        tooltipText: "Expand panel"
                        // implicitWidth tracks Settings via binding — only
                        // write the setting (AGS setGlobalSetting + queueResize).
                        onClicked: Settings.leftPanelWidth = Math.min(1500, Settings.leftPanelWidth + 50)
                    }
                    // Shrink (−50 to min 400, AGS LeftPanel minPanelWidth={400})
                    AppButton {
                        width: parent.width
                        icon: "\u{F068}"
                        pixelSize: 14
                        cornerRadius: 6
                        hoverBg: Theme.moduleBg
                        hoverFg: Theme.accent
                        tooltipText: "Shrink panel"
                        onClicked: Settings.leftPanelWidth = Math.max(400, Settings.leftPanelWidth - 50)
                    }
                    // Exclusivity (AGS: active = non-exclusive, inverted)
                    AppButton {
                        width: parent.width
                        icon: "\u{F2D2}"
                        pixelSize: 14
                        cornerRadius: 6
                        toggle: true
                        checked: !Settings.leftPanelExclusivity
                        hoverBg: Theme.moduleBg
                        tooltipText: Settings.leftPanelExclusivity ? "Exclusive zone: on" : "Exclusive zone: off"
                        // checked is the inverse of the setting: writing it
                        // back as-is toggles exclusivity.
                        onClicked: Settings.leftPanelExclusivity = checked
                    }
                    // Lock (AGS FA lock F023 / unlock F2FC)
                    AppButton {
                        width: parent.width
                        icon: Settings.leftPanelLock ? "\u{F023}" : "\u{F2FC}"
                        pixelSize: 14
                        cornerRadius: 6
                        toggle: true
                        checked: Settings.leftPanelLock
                        hoverBg: Theme.moduleBg
                        tooltipText: Settings.leftPanelLock ? "Unlock panel" : "Lock panel"
                        onClicked: Settings.leftPanelLock = !checked
                    }
                    // Close (AGS WindowActions close F00D)
                    AppButton {
                        width: parent.width
                        icon: "\u{F00D}"
                        pixelSize: 14
                        cornerRadius: 6
                        hoverBg: Theme.moduleBg
                        hoverFg: Theme.danger
                        tooltipText: "Close panel"
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
