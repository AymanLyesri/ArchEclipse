import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets.shared
import qs.widgets.leftPanel

// Welcome screen — first-run tour for the ArchEclipse dotfiles.
Scope {
    id: root

    property bool shown: false
    property bool completed: false
    property bool neverShow: false
    property int page: 0
    readonly property int pageCount: 9
    property var targetScreen: null
    readonly property string monitorName: root.targetScreen
        ? (Hyprland.monitorFor(root.targetScreen)?.name ?? root.targetScreen.name ?? "") : ""
    property bool _autoChecked: false

    // ---- persistence ----
    FileView {
        id: stateFile
        path: `${Quickshell.env("HOME")}/.cache/quickshell/settings/welcome.json`
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const v = JSON.parse(text());
                root.completed = !!(v && v.completed);
            } catch (e) {
                root.completed = false;
            }
            root._decide();
        }
        onLoadFailed: {
            root.completed = false;
            root._decide();
        }
    }

    function save(done) {
        root.completed = done;
        stateFile.setText(JSON.stringify({
            completed: done,
            version: 1
        }));
    }

    function _decide() {
        if (root._autoChecked)
            return;
        root._autoChecked = true;
        if (!root.completed)
            autoOpenTimer.start();
    }

    Timer {
        id: autoOpenTimer
        interval: 2000
        repeat: false
        onTriggered: root.open(true, "")
    }

    // ---- open / close ----
    function screenForMonitor(monitorName) {
        const wanted = String(monitorName || "");
        if (wanted !== "") {
            for (const screen of Quickshell.screens) {
                if ((Hyprland.monitorFor(screen)?.name ?? screen.name ?? "") === wanted)
                    return screen;
            }
            return null;
        }

        const focused = Hyprland.focusedMonitor;
        if (focused) {
            for (const screen of Quickshell.screens) {
                if ((Hyprland.monitorFor(screen)?.name ?? screen.name ?? "") === focused.name)
                    return screen;
            }
        }
        return Quickshell.screens[0] ?? null;
    }

    function open(auto, requestedMonitor) {
        autoOpenTimer.stop();
        if (root.shown)
            root.close();

        const screen = root.screenForMonitor(requestedMonitor);
        if (!screen)
            return false;
        root.targetScreen = screen;
        const monitor = Hyprland.monitorFor(screen)?.name ?? screen.name ?? "";
        if (!monitor)
            return false;

        const active = BarState.activeStatesFor(monitor) || {};
        root._savedTourStates = [];
        for (const name of root._stepStates.slice(1)) {
            if (name in active)
                root._savedTourStates.push(name);
        }
        const searchOwner = BarState.searchMonitor || "";
        const searchWasOpen = searchOwner !== "" && BarState.isOpenFor("search", searchOwner);
        root._savedSearchMonitor = searchWasOpen && searchOwner !== monitor
            ? searchOwner : "";
        root._savedSearchQuery = searchWasOpen ? Launcher.lastQuery : "";
        root._savedLeftWidget = "";
        root._savedLeftWidgetHadOverride = false;

        root.stepCloseAll();
        root.page = 0;
        root.neverShow = root.completed;
        if (auto)
            Hyprland.dispatch("hl.dsp.focus({workspace = 1})");
        root.shown = true;
        return true;
    }

    function close() {
        autoOpenTimer.stop();
        if (!root.shown)
            return;
        const monitor = root.monitorName;
        root.stepCloseAll();
        if (root._savedTourStates.includes("search") || root._savedSearchMonitor !== "")
            Launcher.pendingQuery = root._savedSearchQuery;
        for (const name of root._savedTourStates)
            BarState.activate(name, 0, monitor);
        root._savedTourStates = [];
        if (root._savedSearchMonitor !== "")
            BarState.activate("search", 0, root._savedSearchMonitor);
        root._savedSearchMonitor = "";
        root._savedSearchQuery = "";
        root._restore();
        if (root.neverShow !== root.completed)
            root.save(root.neverShow);
        root.shown = false;
    }

    function finish() {
        root.neverShow = true;
        root.close();
    }

    function next() {
        if (root.page >= root.pageCount - 1)
            root.finish();
        else
            root.goToPage(root.page + 1);
    }

    function prev() {
        if (root.page > 0)
            root.goToPage(root.page - 1);
    }

    function goToPage(nextPage) {
        const page = Math.max(0, Math.min(root.pageCount - 1, nextPage));
        if (page === root.page)
            return;

        root.stepCloseAll();
        root.page = page;
        if (root.shown && page >= 1 && page <= 5)
            root.stepOpen(page);
    }

    // ---- interactive steps (pages 1-5) ----
    readonly property bool isLive: root.page >= 1 && root.page <= 5
    readonly property string cardSide: root.page === 2 ? "right" : (root.page === 3 ? "left" : (root.isLive ? "bottom" : ""))
    readonly property var _stepStates: ["", "search", "left", "right", "wallpaper", "control"]
    readonly property var _leftWidgetTour: [
        {
            tab: "UserProfile",
            title: "User profile",
            description: "Sign in with a magic link to link your account. View your profile and sync shell settings between installs."
        },
        {
            tab: "BooruViewer",
            title: "Booru viewer",
            description: "Search Danbooru, Gelbooru, or Safebooru with tags and browse the result grid. Open a post for details, then favorite, download, or pin it to a workspace."
        },
        {
            tab: "ChatBot",
            title: "Chat bot",
            description: "Choose a provider and model, then chat in separate saved sessions. Optional context can include workspace and active-file details."
        },
        {
            tab: "MangaViewer",
            title: "Manga reader",
            description: "Search MangaDex or MangaLib, open a title to see its chapters, then open a chapter in the reader. Use page and chapter navigation to continue reading."
        },
        {
            tab: "SettingsWidget",
            title: "Settings",
            description: "Adjust appearance, bar and panel behavior, hot zones, and enabled widgets. Most controls save automatically as you change them."
        },
        {
            tab: "CustomScripts",
            title: "Custom scripts",
            description: "Run shortcuts such as screenshots, recording, and system tools from the list. Entries show app requirements; reset asks before changing settings."
        },
        {
            tab: "KeyBinds",
            title: "Key binds",
            description: "Browse Hyprland shortcuts by category and compare each action with its key combination. Use this tab as a quick reference."
        },
        {
            tab: "Donations",
            title: "Support the project",
            description: "Check whether your account is linked and supporter status is active. The tab also links to sign-in and optional support methods."
        }
    ]
    readonly property var _rightWidgetDescriptions: ({
        Waifu: {
            title: "Waifu media",
            description: "Shows the image or video selected in Booru Viewer. Use the overlay actions to bookmark, open the media, pin supported images, copy the post ID, or upload your own image."
        },
        Media: {
            title: "Media player",
            description: "Control the active player: play or pause, skip tracks, seek, and follow synced lyrics when the player provides them."
        },
        NotificationHistory: {
            title: "Notification history",
            description: "Review recent notifications and filter by app or text. Click an entry to copy it, right-click to dismiss it, or clear the full history."
        },
        Calendar: {
            title: "Calendar",
            description: "Browse months and years, select a date, or jump back to today. The current day stays marked while you browse."
        },
        SystemResources: {
            title: "System resources",
            description: "Watch live CPU and memory usage, plus detected GPU load, memory, and temperature."
        }
    })
    readonly property var _rightWidgetTour: (Settings.rightPanelWidgets || []).map(widget => {
        const details = root._rightWidgetDescriptions[widget.name];
        return details ? ({
            name: widget.name,
            title: details.title,
            description: details.description
        }) : null;
    }).filter(widget => widget !== null)
    property int leftWidgetIndex: 0
    property int rightWidgetIndex: 0
    readonly property bool leftWidgetTourIsOpen: BarState.isOpenFor("left", root.monitorName)
        && Settings.leftPanelWidgetFor(root.monitorName) === root._leftWidgetTour[root.leftWidgetIndex].tab
    readonly property bool rightWidgetTourIsOpen: BarState.isOpenFor("right", root.monitorName)
    property var _savedTourStates: []
    property string _savedLeftWidget: ""
    property bool _savedLeftWidgetHadOverride: false
    property string _savedSearchMonitor: ""
    property string _savedSearchQuery: ""

    // Reliably closes all interactive tour states.
    function stepCloseAll() {
        for (let i = 1; i <= 5; i++) {
            BarState.deactivate(root._stepStates[i], root.monitorName);
        }
    }

    // Keep only the target monitor's live tour panel from auto-closing.
    Binding {
        target: BarState
        property: "tourHoldMonitor"
        value: root.shown && root.isLive ? root.monitorName : ""
    }

    Binding {
        target: BarState
        property: "tourHighlightTab"
        value: {
            if (!root.shown)
                return "";
            if (root.page === 2)
                return root._leftWidgetTour[root.leftWidgetIndex].tab;
            if (root.page === 3)
                return root._rightWidgetTour[root.rightWidgetIndex].name;
            return "";
        }
    }

    Binding {
        target: BarState
        property: "tourHighlightMonitor"
        value: root.shown && (root.page === 2 || root.page === 3) && root.targetScreen ? (Hyprland.monitorFor(root.targetScreen)?.name ?? root.targetScreen.name) : ""
    }

    Binding {
        target: BarState
        property: "tourRightWidget"
        value: root.shown && root.page === 3 ? root._rightWidgetTour[root.rightWidgetIndex].name : ""
    }

    Connections {
        target: Settings
        function onLeftPanelWidgetChanged() {
            root.syncLeftWidgetTourIndex();
        }
        function onLeftPanelByMonitorChanged() {
            root.syncLeftWidgetTourIndex();
        }
    }

    function syncLeftWidgetTourIndex() {
        if (root.page !== 2)
            return;
        const selected = Settings.leftPanelWidgetFor(root.monitorName);
        const index = root._leftWidgetTour.findIndex(widget => widget.tab === selected);
        if (index >= 0)
            root.leftWidgetIndex = index;
    }

    function moveLeftWidgetTour(direction) {
        root.leftWidgetIndex = Math.max(0, Math.min(root._leftWidgetTour.length - 1, root.leftWidgetIndex + direction));
        root.openLeftWidgetTour();
    }

    function openLeftWidgetTour() {
        const widget = root._leftWidgetTour[root.leftWidgetIndex];
        Registry.selectLeftTab(widget.tab, undefined, root.monitorName);
    }

    function moveRightWidgetTour(direction) {
        root.rightWidgetIndex = Math.max(0, Math.min(root._rightWidgetTour.length - 1, root.rightWidgetIndex + direction));
    }

    function openRightWidgetTour() {
        if (!BarState.isOpenFor("right", root.monitorName))
            root.stepOpen(3);
    }

    function stepActive(i) {
        switch (i) {
        case 1:
            return BarState.isOpenFor("search", root.monitorName);
        case 2:
            return BarState.isOpenFor("left", root.monitorName);
        case 3:
            return BarState.isOpenFor("right", root.monitorName);
        case 4:
            return BarState.isOpenFor("wallpaper", root.monitorName);
        case 5:
            return BarState.isOpenFor("control", root.monitorName);
        }
        return false;
    }

    function stepOpen(i) {
        switch (i) {
        case 1:
            Launcher.pendingQuery = "";
            BarState.activate("search", 0, root.monitorName);
            break;
        case 2:
            if (root._savedLeftWidget === "") {
                const override = (Settings.leftPanelByMonitor || {})[root.monitorName];
                root._savedLeftWidgetHadOverride = !!override && override.widget !== undefined;
                root._savedLeftWidget = Settings.leftPanelWidgetFor(root.monitorName);
            }
            const widgetIndex = root._leftWidgetTour.findIndex(widget => widget.tab === Settings.leftPanelWidgetFor(root.monitorName));
            if (widgetIndex >= 0)
                root.leftWidgetIndex = widgetIndex;
            BarState.activate("left", 0, root.monitorName);
            break;
        case 3:
            BarState.activate("right", 0, root.monitorName);
            break;
        case 4:
            BarState.activate("wallpaper", 0, root.monitorName);
            break;
        case 5:
            BarState.activate("control", 0, root.monitorName);
            break;
        }
    }

    function stepToggle(i) {
        if (root.stepActive(i))
            root.stepCloseAll();
        else {
            root.stepCloseAll();
            root.stepOpen(i);
        }
    }

    function _restore() {
        if (root._savedLeftWidget !== "") {
            if (root._savedLeftWidgetHadOverride)
                Settings.setLeftPanelWidgetFor(root.monitorName, root._savedLeftWidget);
            else
                Settings.clearPanelOverride("left", root.monitorName, "widget");
            root._savedLeftWidget = "";
            root._savedLeftWidgetHadOverride = false;
        }
    }

    IpcHandler {
        target: "welcome"

        function open(): string {
            root.open(false, "");
            return "welcome open";
        }
        function openOn(monitor: string): string {
            if (!root.screenForMonitor(monitor))
                return `unknown monitor: ${monitor}`;
            root.open(false, monitor);
            return `welcome open on ${monitor}`;
        }
        function close(): string {
            root.close();
            return "welcome closed";
        }
        function closeOn(monitor: string): string {
            if (root.shown && root.monitorName === monitor) {
                root.close();
                return `welcome closed on ${monitor}`;
            }
            return `welcome is not open on ${monitor}`;
        }
        function toggle(): string {
            if (root.shown) {
                root.close();
                return "welcome closed";
            }
            root.open(false, "");
            return "welcome open";
        }
        function toggleOn(monitor: string): string {
            if (root.shown && root.monitorName === monitor) {
                root.close();
                return `welcome closed on ${monitor}`;
            }
            if (!root.screenForMonitor(monitor))
                return `unknown monitor: ${monitor}`;
            root.open(false, monitor);
            return `welcome open on ${monitor}`;
        }
        function reset(): string {
            root.save(false);
            return "welcome will show again on next start";
        }
    }

    // ---- small reusable pieces ----
    component PageTitle: Label {
        Layout.fillWidth: true
        font.pixelSize: Theme.fontSize + 8
        font.bold: true
        font.family: Theme.fontFamily
        color: Theme.fg
        wrapMode: Text.WordWrap
    }
    component BodyText: Label {
        Layout.fillWidth: true
        font.pixelSize: Theme.fontSize + 1
        font.family: Theme.fontFamily
        color: Theme.muted
        wrapMode: Text.WordWrap
        textFormat: Text.RichText
    }
    component LiveStep: ColumnLayout {
        id: ls
        property string title: ""
        property string text: ""
        property var keys: []
        property bool active: false
        signal toggleRequested
        spacing: 12
        PageTitle {
            text: ls.title
        }
        BodyText {
            text: ls.text
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: ls.active ? Theme.accent : Theme.border
            }
            Label {
                text: ls.active ? "Open now" : "Closed"
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                color: ls.active ? Theme.fg : Theme.fgDim
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
                visible: ls.keys.length > 0
                text: "Try it yourself:"
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                color: Theme.muted
            }
            AppKeybind {
                keys: ls.keys
                Layout.alignment: Qt.AlignVCenter
            }
            Item {
                Layout.fillWidth: true
            }
            AppButton {
                text: ls.active ? "Close it" : "Open it for me"
                cornerRadius: Theme.chipRadius
                outlined: true
                onClicked: ls.toggleRequested()
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
    component TipRow: RowLayout {
        id: tr
        property string glyph: ""
        property string title: ""
        property string text: ""
        Layout.fillWidth: true
        spacing: 12
        Label {
            text: tr.glyph
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSize + 8
            font.family: Theme.fontFamily
            color: Theme.accent
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: tr.title
                Layout.fillWidth: true
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                font.family: Theme.fontFamily
                color: Theme.fg
            }
            Label {
                text: tr.text
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSize
                font.family: Theme.fontFamily
                color: Theme.muted
            }
        }
    }

    // ---- the window ----
    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win
            screen: root.targetScreen
            visible: true
            color: "transparent"
            implicitWidth: 780
            implicitHeight: root.page >= 2 && root.page <= 4 ? 440 : (root.isLive ? 360 : 560)
            anchors {
                left: root.cardSide === "left"
                right: root.cardSide === "right"
                bottom: root.cardSide === "bottom"
            }
            margins {
                left: 24
                right: 24
                bottom: 32
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "archeclipse-welcome"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                id: card
                anchors.fill: parent
                radius: Theme.radius + 4
                color: Theme.bg
                border.color: Theme.border
                border.width: 1
                clip: true

                property real t: 0
                opacity: t
                scale: 0.96 + 0.04 * t
                Behavior on t {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
                Component.onCompleted: card.t = 1

                focus: true
                Keys.onEscapePressed: root.close()
                Keys.onLeftPressed: root.prev()
                Keys.onRightPressed: root.next()
                Keys.onReturnPressed: root.next()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    // header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Label {
                            text: "ArchEclipse"
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            font.family: Theme.fontFamily
                            color: Theme.accent
                            Layout.fillWidth: true
                        }
                        Label {
                            text: (root.page + 1) + " / " + root.pageCount
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.fgDim
                        }
                        AppButton {
                            icon: ""
                            implicitWidth: 34
                            cornerRadius: Theme.chipRadius
                            tooltipText: "Close"
                            onClicked: root.close()
                        }
                    }

                    // pages
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        Layout.preferredHeight: 0
                        clip: true
                        currentIndex: root.page

                        // 0 — welcome
                        ColumnLayout {
                            spacing: 14
                            Item {
                                Layout.fillHeight: true
                            }
                            PageTitle {
                                text: "Welcome to ArchEclipse"
                                font.pixelSize: Theme.fontSize + 14
                            }
                            BodyText {
                                text: "ArchEclipse combines Arch Linux, Hyprland, and a custom Quickshell interface into one cohesive desktop: a configurable bar, launcher, side panels, and widgets. Set wallpapers per workspace and, with dynamic theming enabled, let their colors update the shell."
                            }
                            BodyText {
                                text: "Explore the main controls and widgets in both side panels. “Open it for me” previews a widget; your panel state returns when you close the tour."
                            }
                            Item {
                                Layout.fillHeight: true
                            }
                        }

                        // 1 — search
                        LiveStep {
                            title: "Search & launcher"
                            text: "Launch apps, run commands, find emoji, do quick math or translate — all from one box in the bar."
                            keys: ["SUPER", "SUPER_L"]
                            active: root.stepActive(1)
                            onToggleRequested: root.stepToggle(1)
                        }

                        // 2 — left panel widget walkthrough
                        ColumnLayout {
                            spacing: 8

                            PageTitle {
                                text: "Explore the left panel"
                            }
                            BodyText {
                                text: "Browse the widgets one by one. The outlined sidebar icon marks the widget being described."
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cardRadius
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            text: "Widget " + (root.leftWidgetIndex + 1) + " of " + root._leftWidgetTour.length
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: Theme.fgDim
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            text: "Open panel:"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: Theme.muted
                                        }
                                        AppKeybind {
                                            keys: ["SUPER", "L"]
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    PageTitle {
                                        text: root._leftWidgetTour[root.leftWidgetIndex].title
                                        font.pixelSize: Theme.fontSize + 4
                                        Layout.bottomMargin: 4
                                    }

                                    BodyText {
                                        text: root._leftWidgetTour[root.leftWidgetIndex].description
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 8
                                        spacing: 8
                                        Rectangle {
                                            width: 9
                                            height: 9
                                            radius: 5
                                            color: root.leftWidgetTourIsOpen ? Theme.accent : Theme.border
                                        }
                                        Label {
                                            text: root.leftWidgetTourIsOpen ? "Showing in the left panel" : "Ready to open"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: root.leftWidgetTourIsOpen ? Theme.fg : Theme.fgDim
                                            Layout.fillWidth: true
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        AppButton {
                                            text: "Previous"
                                            outlined: true
                                            enabled: root.leftWidgetIndex > 0
                                            onClicked: root.moveLeftWidgetTour(-1)
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        AppButton {
                                            text: root.leftWidgetTourIsOpen ? "Open now" : "Open it for me"
                                            toggle: true
                                            checked: root.leftWidgetTourIsOpen
                                            onClicked: root.openLeftWidgetTour()
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        AppButton {
                                            text: "Next"
                                            outlined: true
                                            enabled: root.leftWidgetIndex < root._leftWidgetTour.length - 1
                                            onClicked: root.moveLeftWidgetTour(1)
                                        }
                                    }
                                }
                            }
                        }

                        // 3 — right-panel widget walkthrough
                        ColumnLayout {
                            spacing: 8

                            PageTitle {
                                text: "Explore the right panel"
                            }
                            BodyText {
                                text: "Browse each widget one by one. The highlighted rail icon marks the current preview; your saved widget order and enabled settings stay intact."
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cardRadius
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            text: "Widget " + (root.rightWidgetIndex + 1) + " of " + root._rightWidgetTour.length
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: Theme.fgDim
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            text: "Open panel:"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: Theme.muted
                                        }
                                        AppKeybind {
                                            keys: ["SUPER", "R"]
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    PageTitle {
                                        text: root._rightWidgetTour[root.rightWidgetIndex].title
                                        font.pixelSize: Theme.fontSize + 4
                                        Layout.bottomMargin: 4
                                    }

                                    BodyText {
                                        text: root._rightWidgetTour[root.rightWidgetIndex].description
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 8
                                        spacing: 8
                                        Rectangle {
                                            width: 9
                                            height: 9
                                            radius: 5
                                            color: root.rightWidgetTourIsOpen ? Theme.accent : Theme.border
                                        }
                                        Label {
                                            text: root.rightWidgetTourIsOpen ? "Showing in the right panel" : "Ready to open"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.family: Theme.fontFamily
                                            color: root.rightWidgetTourIsOpen ? Theme.fg : Theme.fgDim
                                            Layout.fillWidth: true
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        AppButton {
                                            text: "Previous"
                                            outlined: true
                                            enabled: root.rightWidgetIndex > 0
                                            onClicked: root.moveRightWidgetTour(-1)
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        AppButton {
                                            text: root.rightWidgetTourIsOpen ? "Open now" : "Open it for me"
                                            toggle: true
                                            checked: root.rightWidgetTourIsOpen
                                            onClicked: root.openRightWidgetTour()
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        AppButton {
                                            text: "Next"
                                            outlined: true
                                            enabled: root.rightWidgetIndex < root._rightWidgetTour.length - 1
                                            onClicked: root.moveRightWidgetTour(1)
                                        }
                                    }
                                }
                            }
                        }

                        // 4 — wallpaper
                        LiveStep {
                            title: "Wallpaper switcher"
                            text: "Choose static or video wallpapers (MP4, WebM, MKV, MOV) per workspace. Switch to Wallhaven to search and download images. Select the lock tile to set a picture for the custom ArcheEclipse Greeter on greetd; the image is copied to its system directory, while sync-greeter.sh mirrors the greeter files with rsync."
                            keys: ["SUPER", "W"]
                            active: root.stepActive(4)
                            onToggleRequested: root.stepToggle(4)
                        }

                        // 5 — quick settings
                        LiveStep {
                            title: "Quick settings"
                            text: "Theme, Do Not Disturb, Game Mode, Blue Light Filter, brightness and the power profile. Hover the bar to reach it any time."
                            keys: []
                            active: root.stepActive(5)
                            onToggleRequested: root.stepToggle(5)
                        }

                        // 6 — tips
                        ColumnLayout {
                            spacing: 14
                            PageTitle {
                                text: "Good to know"
                            }
                            TipRow {
                                glyph: ""
                                title: "Hover and click the bar"
                                text: "Weather, network, volume, brightness and system resources unfold as small islands. Move to the screen edge to reveal an auto-hidden bar."
                            }
                            TipRow {
                                glyph: ""
                                title: "Quick settings"
                                text: "The control panel has theme, Do Not Disturb, Game Mode, Blue Light Filter, brightness and the power profile."
                            }
                            TipRow {
                                glyph: ""
                                title: "System tray"
                                text: "Drag tray icons to reorder them, or onto the “...” button to move them into the overflow menu."
                            }
                            TipRow {
                                glyph: ""
                                title: "All options in one place"
                                text: "Open the left panel (SUPER + L) and pick the Settings tab to tune the bar, panels and widgets."
                            }
                            Item {
                                Layout.fillHeight: true
                            }
                        }

                        // 7 — key binds
                        Item {
                            KeyBindsWidget {
                                anchors.fill: parent
                            }
                        }

                        // 8 — done
                        ColumnLayout {
                            spacing: 14
                            Item {
                                Layout.fillHeight: true
                            }
                            PageTitle {
                                text: "You're all set"
                                font.pixelSize: Theme.fontSize + 14
                            }
                            BodyText {
                                text: "Press <b>Get started</b> and the tour won't open again on startup."
                            }
                            BodyText {
                                text: "To see it again at any time, press:"
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                AppKeybind {
                                    keys: ["SUPER", "F1"]
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                            }
                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }

                    // footer
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        AppCheckBox {
                            text: "Don't show again at startup"
                            checked: root.neverShow
                            onToggled: root.neverShow = checked
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Row {
                            spacing: 6
                            Layout.alignment: Qt.AlignVCenter
                            Repeater {
                                model: root.pageCount
                                delegate: Item {
                                    required property int index
                                    width: 24
                                    height: 24

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: index === root.page ? 18 : 6
                                        height: 6
                                        radius: 3
                                        color: index === root.page ? Theme.accent : (pageMouse.containsMouse ? Theme.fgDim : Theme.border)
                                        Behavior on width {
                                            Anim {
                                                type: Anim.FastSpatial
                                            }
                                        }
                                        Behavior on color {
                                            CAnim {}
                                        }
                                    }

                                    MouseArea {
                                        id: pageMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.goToPage(index)
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        AppButton {
                            text: "Back"
                            visible: root.page > 0
                            cornerRadius: Theme.chipRadius
                            outlined: true
                            onClicked: root.prev()
                        }
                        AppButton {
                            text: root.page >= root.pageCount - 1 ? "Get started" : "Next"
                            cornerRadius: Theme.chipRadius
                            toggle: true
                            checked: true
                            onClicked: root.next()
                        }
                    }
                }
            }
        }
    }
}
