import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.leftPanel

// LeftIsland: the former LeftPanel body (sidebar + widget stack) living
// in the left side pill beside the bar (BarState.leftOpen flag).
//
// Same unfold pattern as Search/ControlIsland — the pill grows
// (width via the pill transition, height snapped on the window) while this
// body unfolds via the expand driver (clip + opacity + scale only, so no
// expensive layout animates per-frame). Each tab is a Loader that builds
// on first select and stays alive, so switches preserve state exactly
// like the old panel while opening builds only one widget.
//
// Open: SUPER+L bind, left HotZone hover, launcher quick-app, IPC.
// Close: bind toggle, Esc, close button, or 1s after the cursor leaves
// (Settings.leftPanelLock pins it open). The booru detail popup is a
// separate surface: while it is hovered/open the island stays alive via
// the same popupHovered/hostPanel handoff the panel used.
Column {
    id: root
    width: Settings.leftPanelWidth
    // Explicit full height (NOT implicit): positioner implicit sizes freeze
    // at completion-time values in this engine, so a height driven only by
    // the expand animation would never reach the pill — the Loader measures
    // this explicit height and the pill snaps to it, exactly like the
    // static DefaultBar/PlayerIsland pages. The expand driver below still
    // unfolds the content inside the snapped pill (clip + opacity + scale).
    height: bodyHeight
    spacing: 0

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""
    // Monitor screen object (ShellScreen) passed by the bar owner — handed
    // to the booru viewer for its full-screen float panel.
    property var screen: null

    // Full monitor height, passed by the bar owner. Side islands stretch
    // the whole vertical screen like the old edge panels did (the pill
    // adds its 10px padding, leaving a 5px bottom margin).
    property int screenHeight: 1080

    // Fixed dropdown height (the old panel stretched full monitor height;
    // the island is a floating card — each widget fills this viewport and
    // scrolls internally, same as the search island's fixed body height).
    property int bodyHeight: Math.max(400, screenHeight - 15)

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    // Tab-name order for the selector-rail index mapping (the rail's
    // own model below carries the verbatim name+icon items; names keep
    // the QS "Widget" suffix for IPC showWidget/widgetState compat).
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
    }
    Component.onDestruction: {
        Registry.unregister("left-island");
        Registry.unregister(root.registryKey());
    }
    function registryKey() {
        return `left-island-${root.monitorName || Registry.monitorName}`;
    }

    // Selected widget — initialized from persisted Settings and written
    // back on change (same contract the panel had).
    property string selectedWidget: Settings.leftPanelWidget
    // Tabs visited this session — a tab's Loader activates on first select
    // and stays active (object replaced, never mutated, for change notify).
    property var _visited: ({})
    function tabPrimed(name) {
        return root.selectedWidget === name || root._visited[name] === true;
    }
    onSelectedWidgetChanged: {
        if (Settings.leftPanelWidget !== selectedWidget)
            Settings.leftPanelWidget = selectedWidget;
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
            if (root.selectedWidget !== Settings.leftPanelWidget)
                root.selectedWidget = Settings.leftPanelWidget;
        }
    }
    // Expose the active tab's widget so IPC can poke into the live
    // widget (loadBookmarks/pagedSlice/etc) without traversing the tree.
    // Each branch reads that tab Loader's item, so the binding tracks
    // loads and switches. Unvisited tabs have no item (lazy) — callers
    // already null-check (requestAutoHide/leaveTimer/widgetState).
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

    // Map a tab name (matching the launcher's quick-app selectors) to a widget.
    function selectTab(name) {
        root.selectedWidget = name;
    }

    // Direct access to the booru viewer instance (null until primed).
    readonly property var booruView: booruLoader.item
    // Post waiting for the booru Loader: openDialog lands here when a
    // caller (e.g. waifu) floats a dialog before first instantiation.
    property var _pendingDialogImage: null

    // Open a post in the floating detail window without opening the
    // island. Primes the Booru tab; if the viewer isn't instantiated
    // yet this tick (Loader activates on the next binding pass), the
    // post parks in _pendingDialogImage and booruLoader.onLoaded below
    // opens it. Returns false only when there is nothing to open.
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

    // Hover tracking lives here (stable container — content never swaps
    // under the cursor while open). Leaving arms the close timer; the
    // timer re-checks so a fast flick across still closes.
    HoverHandler {
        id: islandHover
        onHoveredChanged: {
            if (islandHover.hovered) {
                leaveTimer.stop();
                // Pin hover-driven islands so a hold expiry can't close
                // the panel while it is being used.
                BarState.activate("left", 0);
            } else {
                root.requestAutoHide();
            }
        }
    }
    function requestAutoHide() {
        if (Settings.leftPanelLock)
            return;
        if (islandHover.hovered)
            return;
        if (root.activeWidget && root.activeWidget.popupHovered)
            return;
        leaveTimer.restart();
    }
    // Called by the bar owner on every (re)open: the island now survives
    // closes, so a leaveTimer armed before the last close must not fire
    // into the fresh session and shut it after the reveal-out delay
    // with no hover-leave.
    function cancelPendingHide() {
        leaveTimer.stop();
    }
    Timer {
        id: leaveTimer
        interval: Settings.revealOutPressure
        onTriggered: {
            if (!Settings.leftPanelLock && !islandHover.hovered && !(root.activeWidget && root.activeWidget.popupHovered))
                BarState.deactivate("left");
        }
    }

    // Esc dismiss once the surface has focus (click a control first).
    IslandEscClose {
        states: ["left"]
    }

    IslandExpandClip {
        expand: root.expand
        contentHeight: bodyRow.height

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
                radius: Theme.radius
                clip: true

                // Widget selector rail (shared component: tab order,
                // icons, Donations highlight and tooltips preserved).
                IslandSideRail {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    // Tab order + icons: UserProfile, BooruViewer,
                    // ChatBot, MangaViewer, Settings, CustomScripts,
                    // KeyBinds, Donations. Names keep the QS "Widget"
                    // suffix (IPC showWidget/widgetState compat).
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
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                }
            }

            // Main content area
            Item {
                id: contentArea
                width: parent.width - sidebar.width
                height: parent.height

                // Widget stack — each tab is a Loader that activates on first
                // select and stays alive, so tab
                // switches preserve scroll/page/chat/booru state. Only the
                // selected tab instantiates: opening the island builds one
                // widget instead of all eight. Only the current one is
                // visible; loaded hidden tabs exist in memory but don't
                // paint. Order matches the tab rail above.
                // Fade-in on switch (opacity-in 0.6s).
                OpacityAnimator on opacity {
                    id: switchAnim
                    from: 0
                    to: 1
                    duration: 600
                    easing.type: Easing.OutCubic
                }
                StackLayout {
                    id: widgetStack
                    anchors.fill: parent
                    anchors.margins: 4
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
                    }
                    Loader {
                        id: booruLoader
                        active: root.tabPrimed("BooruViewer")
                        sourceComponent: booruComp
                        onLoaded: {
                            // Back-reference so the booru viewer can route
                            // its popup-unhover hide requests here (the
                            // popup is a separate window surface). The
                            // viewer binds hostScreen reactively off
                            // hostPanel.screen — no one-shot assign here
                            // (nested onLoaded can run before the bar sets
                            // the island's screen).
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
                    }
                    Loader {
                        id: mangaLoader
                        active: root.tabPrimed("MangaViewer")
                        sourceComponent: mangaComp
                    }
                    Loader {
                        id: settingsLoader
                        active: root.tabPrimed("SettingsWidget")
                        sourceComponent: settingsComp
                    }
                    Loader {
                        id: scriptsLoader
                        active: root.tabPrimed("CustomScripts")
                        sourceComponent: scriptsComp
                    }
                    Loader {
                        id: keybindsLoader
                        active: root.tabPrimed("KeyBinds")
                        sourceComponent: keybindsComp
                    }
                    Loader {
                        id: donationsLoader
                        active: root.tabPrimed("Donations")
                        sourceComponent: donationsComp
                    }
                }
                Component {
                    id: userProfileComp
                    UserProfileWidget {}
                }
                Component {
                    id: booruComp
                    BooruViewer {}
                }
                Component {
                    id: chatBotComp
                    ChatBotWidget {}
                }
                Component {
                    id: mangaComp
                    MangaViewerWidget {}
                }
                Component {
                    id: settingsComp
                    SettingsWidget {}
                }
                Component {
                    id: scriptsComp
                    CustomScriptsWidget {}
                }
                Component {
                    id: keybindsComp
                    KeyBindsWidget {}
                }
                Component {
                    id: donationsComp
                    DonationsWidget {}
                }
            }
        }
    }
}
