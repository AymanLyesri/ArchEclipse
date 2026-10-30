import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.leftPanel

// LeftIsland: the former LeftPanel body in the left side pill, scoped to its monitor; same
// expand-driver unfold as SearchIsland, tabs built on first select and kept alive after.
Item {
    id: root
    width: Settings.panelWidthFor("left", root.monitorName)
    // Explicit full height, NOT implicit: positioner implicit sizes freeze at completion time,
    // so an animated-only height never reached the pill; the Loader measures this one.
    height: bodyHeight

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""
    // Monitor screen object (ShellScreen) passed by the bar owner — handed
    // to the booru viewer for its full-screen float panel.
    property var screen: null

    // Full monitor height from the bar owner: side islands stretch the whole vertical screen
    // like the old edge panels (the pill adds 10px padding, leaving a 5px bottom margin).
    property int screenHeight: (screen && screen.height > 0) ? screen.height : 1080

    // Fixed dropdown height: the island is a floating card, each widget fills this viewport
    // and scrolls internally (like the search island's fixed body height).
    property int bodyHeight: Math.max(400, screenHeight - 15)

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    // Tab-name order for the rail index mapping; names keep the QS "Widget" suffix for IPC
    // showWidget/widgetState compat.
    readonly property var tabOrder: ["UserProfile", "BooruViewer", "ChatBot", "MangaViewer", "SettingsWidget", "CustomScripts", "KeyBinds", "Donations"]
    function tabIndex(name) {
        return Math.max(0, root.tabOrder.indexOf(name));
    }
    Component.onCompleted: {
        expand = 1;
        Registry.register(root.registryKey(), root);
        Registry.register("left-island", root);
        // Prime the initially-selected tab so its Loader activates below.
        // (The booru hostPanel back-reference is wired in its onLoaded.)
        var v = Object.assign({}, root._visited);
        v[root.selectedWidget] = true;
        root._visited = v;
    }
    onMonitorNameChanged: {
        if (root.monitorName !== "")
            Registry.register(root.registryKey(), root);
        root.syncSelectedWidget();
    }
    Component.onDestruction: {
        Registry.unregister("left-island");
        Registry.unregister(root.registryKey());
    }
    function registryKey() {
        return `left-island-${root.monitorName || Registry.monitorName}`;
    }

    // Per-monitor selected tab, with the persisted global tab as fallback
    // for monitors that do not have an override yet.
    property string selectedWidget: Settings.leftPanelWidgetFor(root.monitorName)
    property bool _restoringSelectedWidget: false
    function syncSelectedWidget() {
        const selected = Settings.leftPanelWidgetFor(root.monitorName);
        if (root.selectedWidget === selected)
            return;
        root._restoringSelectedWidget = true;
        root.selectedWidget = selected;
        root._restoringSelectedWidget = false;
    }
    // Tabs visited this session — a tab's Loader activates on first select
    // and stays active (object replaced, never mutated, for change notify).
    property var _visited: ({})
    function tabPrimed(name) {
        return root.selectedWidget === name || root._visited[name] === true;
    }
    onSelectedWidgetChanged: {
        if (!root._restoringSelectedWidget)
            Settings.setLeftPanelWidgetFor(root.monitorName, selectedWidget);
        if (root._visited[selectedWidget] !== true) {
            var v = Object.assign({}, root._visited);
            v[selectedWidget] = true;
            root._visited = v;
        }
        switchAnim.restart();
    }
    Connections {
        target: Settings
        function onLeftPanelWidgetChanged() {
            const entry = (Settings.leftPanelByMonitor || {})[root.monitorName];
            if (!entry || entry.widget === undefined)
                root.syncSelectedWidget();
        }
        function onLeftPanelByMonitorChanged() {
            root.syncSelectedWidget();
        }
    }
    // Expose the active tab's widget so IPC can poke the live widget without traversing the
    // tree; unvisited tabs have no item, and callers null-check.
    readonly property var activeWidget: {
        switch (widgetStack.currentIndex) {
        case 0:
            return userProfileLoader.item;
        case 1:
            return booruLoader.item;
        case 2:
            return chatBotLoader.item;
        case 3:
            return mangaLoader.item;
        case 4:
            return settingsLoader.item;
        case 5:
            return scriptsLoader.item;
        case 6:
            return keybindsLoader.item;
        case 7:
            return donationsLoader.item;
        default:
            return null;
        }
    }

    // Direct access to the booru viewer instance (null until primed).
    readonly property var booruView: booruLoader.item
    // Post waiting for the booru Loader: openDialog lands here when a
    // caller (e.g. waifu) floats a dialog before first instantiation.
    property var _pendingDialogImage: null

    // Opens a post in the floating detail window without opening the island. Primes the Booru
    // tab; if the viewer isn't instantiated this tick the post parks in _pendingDialogImage.
    function openBooruDialog(img) {
        if (!img)
            return false;
        root.primeTab("BooruViewer");
        const v = root.booruView;
        if (v && typeof v.openDialog === "function" && typeof v.detachDialog === "function") {
            v.openDialog(img, null);
            v.detachDialog();
        } else {
            root._pendingDialogImage = img;
        }
        return true;
    }

    // Build a tab's Loader without switching to it or opening the island
    // (primes on demand, e.g. floating a dialog from another widget).
    function primeTab(name) {
        if (root._visited[name] !== true) {
            var v = Object.assign({}, root._visited);
            v[name] = true;
            root._visited = v;
        }
    }

    // Hover tracking lives here (stable container — content never swaps under the cursor).
    // Leaving arms the close timer, which re-checks so a fast flick still closes.
    HoverHandler {
        id: islandHover
        onHoveredChanged: {
            if (islandHover.hovered) {
                leaveTimer.stop();
                // Pin hover-driven islands so a hold expiry can't close
                // the panel while it is being used.
                BarState.activate("left", 0, root.monitorName);
            } else {
                root.requestAutoHide();
            }
        }
    }
    function requestAutoHide() {
        if (BarState.tourHoldFor(root.monitorName))
            return;
        if (Settings.panelLockFor("left", root.monitorName))
            return;
        if (islandHover.hovered)
            return;
        if (root.activeWidget && root.activeWidget.popupHovered)
            return;
        leaveTimer.restart();
    }
    // Called by the bar owner on every (re)open: the island survives closes, so a leaveTimer
    // armed before the last close must not shut the fresh session after the reveal-out delay.
    function cancelPendingHide() {
        leaveTimer.stop();
    }
    Timer {
        id: leaveTimer
        interval: Settings.revealOutPressure
        onTriggered: {
            if (!BarState.tourHoldFor(root.monitorName) && !Settings.panelLockFor("left", root.monitorName) && !islandHover.hovered && !(root.activeWidget && root.activeWidget.popupHovered))
                BarState.deactivate("left", root.monitorName);
        }
    }

    // Esc dismiss once the surface has focus (click a control first).
    IslandEscClose {
        states: ["left"]
        monitorName: root.monitorName
    }

    IslandExpandClip {
        expand: root.expand
        contentHeight: bodyRow.height
        anchors.top: Settings.barOrientation ? parent.top : undefined
        anchors.bottom: Settings.barOrientation ? undefined : parent.bottom

        Row {
            id: bodyRow
            width: parent.width
            height: root.bodyHeight
            spacing: 0

            // Left sidebar with widget selectors
            Rectangle {
                id: sidebar
                width: 48
                height: parent.height
                color: Theme.bg
                // Square on the screen-edge side so the rail runs flush
                // into the panel's edge (mirrors bar orientation).
                topLeftRadius: Settings.barOrientation ? 0 : Theme.radius
                topRightRadius: Settings.barOrientation ? 0 : Theme.radius
                bottomLeftRadius: Settings.barOrientation ? Theme.radius : 0
                bottomRightRadius: Settings.barOrientation ? Theme.radius : 0
                clip: true

                // Widget selector rail (shared component: tab order,
                // icons, Donations highlight and tooltips preserved).
                IslandSideRail {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.pad
                    highlightedName: BarState.tourHighlightMonitor === root.monitorName ? BarState.tourHighlightTab : ""
                    // Tab order + icons: UserProfile, BooruViewer, ChatBot, MangaViewer,
                    // Settings, CustomScripts, KeyBinds, Donations ("Widget" suffix for IPC).
                    model: [
                        {
                            name: "UserProfile",
                            icon: ""
                        },
                        {
                            name: "BooruViewer",
                            icon: ""
                        },
                        {
                            name: "ChatBot",
                            icon: ""
                        },
                        {
                            name: "MangaViewer",
                            icon: ""
                        },
                        {
                            name: "SettingsWidget",
                            icon: ""
                        },
                        {
                            name: "CustomScripts",
                            icon: ""
                        },
                        {
                            name: "KeyBinds",
                            icon: ""
                        },
                        {
                            name: "Donations",
                            icon: ""
                        }
                    ]
                    currentIndex: root.tabIndex(root.selectedWidget)
                    onSelected: index => {
                        root.selectedWidget = root.tabOrder[index];
                    }
                }
                // WindowActions: bottom cluster (valign END, shared).
                IslandWindowActions {
                    side: "left"
                    monitorName: root.monitorName
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.pad
                }
            }

            // Main content area
            Item {
                id: contentArea
                width: parent.width - sidebar.width
                height: parent.height

                // Each tab activates on first select and stays alive, so switches preserve
                // scroll/page state; only the selected one instantiates. Order matches the rail.
                OpacityAnimator on opacity {
                    id: switchAnim
                    from: 0
                    to: 1
                    duration: Theme.anim.large
                    easing.type: Easing.OutCubic
                }
                StackLayout {
                    id: widgetStack
                    anchors.fill: parent
                    // Content inset owned by the panel (right-panel parity) — tab bodies stay
                    // flush and never add their own outer margin.
                    anchors.margins: Theme.pad
                    currentIndex: {
                        switch (root.selectedWidget) {
                        case "UserProfile":
                            return 0;
                        case "BooruViewer":
                            return 1;
                        case "ChatBot":
                            return 2;
                        case "MangaViewer":
                            return 3;
                        case "SettingsWidget":
                            return 4;
                        case "CustomScripts":
                            return 5;
                        case "KeyBinds":
                            return 6;
                        case "Donations":
                            return 7;
                        default:
                            return 0;
                        }
                    }
                    Loader {
                        id: userProfileLoader
                        active: root.tabPrimed("UserProfile")
                        sourceComponent: userProfileComp
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    Loader {
                        id: booruLoader
                        active: root.tabPrimed("BooruViewer")
                        sourceComponent: booruComp
                        // 1-2k-line tab: parse off the UI thread (first click hitch).
                        asynchronous: true
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onLoaded: {
                            // Back-reference for popup-unhover hides; bind hostScreen reactively off
                            // hostPanel.screen — a one-shot assign runs before the bar sets it.
                            if (item) {
                                item.hostPanel = root;
                                // Flush a dialog parked by openBooruDialog
                                // while this Loader was instantiating.
                                if (root._pendingDialogImage) {
                                    const p = root._pendingDialogImage;
                                    root._pendingDialogImage = null;
                                    item.openDialog(p, null);
                                    item.detachDialog();
                                }
                            }
                        }
                    }
                    Loader {
                        id: chatBotLoader
                        active: root.tabPrimed("ChatBot")
                        sourceComponent: chatBotComp
                        asynchronous: true
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    Loader {
                        id: mangaLoader
                        active: root.tabPrimed("MangaViewer")
                        sourceComponent: mangaComp
                        asynchronous: true
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    Loader {
                        id: settingsLoader
                        active: root.tabPrimed("SettingsWidget")
                        sourceComponent: settingsComp
                        asynchronous: true
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    Loader {
                        id: scriptsLoader
                        active: root.tabPrimed("CustomScripts")
                        sourceComponent: scriptsComp
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    Loader {
                        id: keybindsLoader
                        active: root.tabPrimed("KeyBinds")
                        sourceComponent: keybindsComp
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    Loader {
                        id: donationsLoader
                        active: root.tabPrimed("Donations")
                        sourceComponent: donationsComp
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
                Component {
                    id: userProfileComp
                    UserProfileWidget {
                        monitorName: root.monitorName
                    }
                }
                Component {
                    id: booruComp
                    BooruViewer {}
                }
                Component {
                    id: chatBotComp
                    ChatBotWidget {
                        monitorName: root.monitorName
                    }
                }
                Component {
                    id: mangaComp
                    MangaViewerWidget {
                        monitorName: root.monitorName
                    }
                }
                Component {
                    id: settingsComp
                    SettingsWidget {
                        monitorName: root.monitorName
                    }
                }
                Component {
                    id: scriptsComp
                    CustomScriptsWidget {
                        monitorName: root.monitorName
                    }
                }
                Component {
                    id: keybindsComp
                    KeyBindsWidget {}
                }
                Component {
                    id: donationsComp
                    DonationsWidget {
                        monitorName: root.monitorName
                    }
                }
            }
        }
    }
}
