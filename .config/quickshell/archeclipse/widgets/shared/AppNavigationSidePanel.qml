import QtQuick
import QtQuick.Controls
import qs.theme

// Shared left navigation panel: tab-mode controls below the rail, or a full section
// layout (rail + scrolling section cards) that the panel builds from a sections model.
// Width is draggable on the right edge and persists via Settings.leftNavPanelWidth.
Item {
    id: root

    // Writable on purpose: the drag handle rewrites it; Settings persists on release.
    property int panelWidth: (typeof Settings !== "undefined") ? Settings.leftNavPanelWidth : 128
    readonly property int minWidth: 96

    property var navModel: []
    property int navCurrentIndex: 0
    signal navSelected(int index)

    // Section mode: the panel owns the Flickable, the section cards, selection,
    // centred scrolling and the distance fade. `sections` holds one body Component
    // per navModel entry (aligned by index); a body may declare `property string
    // category` and the panel fills it with the entry title (Key Binds).
    property bool sectionMode: false
    property var sections: []
    readonly property QtObject nav: navController
    readonly property alias flickable: sectionScroll
    readonly property alias sectionColumn: sectionCol

    function titleFor(index) {
        const entry = root.navModel[index];
        if (entry === undefined || entry === null)
            return "";
        return typeof entry === "string" ? entry : (entry.title || "");
    }

    function findItemByObjectName(name) {
        return root.findIn(sectionCol, name);
    }

    function findIn(item, name) {
        if (!item)
            return null;
        const kids = item.children || [];
        for (let i = 0; i < kids.length; i++) {
            const child = kids[i];
            if (child.objectName === name)
                return child;
            const hit = root.findIn(child, name);
            if (hit)
                return hit;
        }
        return null;
    }

    // Navigation controller: selection, centred scroll and the distance fade shared
    // by every section host. In tab mode it stays idle (categories empty).
    QtObject {
        id: navController

        property var categories: root.sectionMode ? root.navModel : []
        property Flickable flickable: root.sectionMode ? sectionScroll : null
        property Item content: root.sectionMode ? sectionCol : null

        property int activeIndex: 0
        property int focusIndex: 0
        property bool navInProgress: false
        property int navToken: 0
        property int navFocusIndex: -1
        property int hoverIndex: -1

        readonly property real minimumOpacity: 0.58
        readonly property real opacityStep: 0.18

        function falloffFor(index, anchor) {
            if (anchor === undefined || anchor < 0)
                return 1;
            return Math.max(navController.minimumOpacity, 1 - Math.abs(index - anchor) * navController.opacityStep);
        }

        function opacityFor(index) {
            return navController.falloffFor(index, navController.hoverIndex >= 0 ? navController.hoverIndex : navController.focusIndex);
        }

        function sectionItem(index) {
            if (!navController.content)
                return null;
            for (let i = 0; i < navController.content.children.length; i++) {
                const child = navController.content.children[i];
                if (child.categoryIndex === index)
                    return child;
            }
            return null;
        }

        function indexForY(y) {
            if (!navController.content)
                return 0;
            for (let i = 0; i < navController.content.children.length; i++) {
                const child = navController.content.children[i];
                if (child.categoryIndex === undefined)
                    continue;
                if (y < child.y + child.height)
                    return child.categoryIndex;
            }
            return Math.max(0, navController.categories.length - 1);
        }

        function anchorY() {
            const f = navController.flickable;
            const half = f.height / 2;
            const maxY = Math.max(0, f.contentHeight - f.height);
            const y = f.contentY;
            if (maxY <= 0)
                return f.contentHeight / 2;
            if (y <= 0)
                return 0;
            if (y >= maxY)
                return f.contentHeight;
            const zone = Math.min(half, maxY / 2);
            if (y < zone)
                return y * (zone + half) / zone;
            if (y > maxY - zone)
                return f.contentHeight - (maxY - y) * (zone + half) / zone;
            return y + half;
        }

        function centeredIndex() {
            if (!navController.content || !navController.flickable)
                return navController.activeIndex;
            const anchor = navController.anchorY();
            let nearest = -1;
            let nearestDistance = Infinity;
            for (let i = 0; i < navController.content.children.length; i++) {
                const child = navController.content.children[i];
                if (child.categoryIndex === undefined || child.height <= 0)
                    continue;
                if (anchor >= child.y && anchor < child.y + child.height)
                    return child.categoryIndex;
                const distance = Math.abs(child.y + child.height / 2 - anchor);
                if (distance < nearestDistance) {
                    nearestDistance = distance;
                    nearest = child.categoryIndex;
                }
            }
            return nearest >= 0 ? nearest : navController.activeIndex;
        }

        function syncFromScroll() {
            if (!navController.flickable || navController.flickable.height <= 0 || navController.flickable.contentHeight <= 0)
                return;
            const index = navController.centeredIndex();
            if (index < 0)
                return;
            navController.hoverIndex = -1;
            navController.activeIndex = index;
            navController.focusIndex = index;
        }

        function targetFor(index) {
            const item = navController.sectionItem(index);
            if (!item || !navController.flickable)
                return 0;
            const viewport = navController.flickable.height;
            const target = item.height >= viewport ? item.y - Theme.pad : item.y + item.height / 2 - viewport / 2;
            const maxY = Math.max(0, navController.flickable.contentHeight - viewport);
            return Math.min(Math.max(target, 0), maxY);
        }

        function select(index) {
            if (index < 0 || index >= navController.categories.length)
                return;
            navController.activeIndex = index;
            navController.scrollToY(navController.targetFor(index), index);
        }

        function scrollToY(targetY, focusIndex) {
            navController.navToken++;
            const token = navController.navToken;
            navController.navFocusIndex = focusIndex;
            navController.navInProgress = true;
            navController.scrollAnimation.stop();
            if (!navController.flickable) {
                navController.finish(token);
                return;
            }
            const maxY = Math.max(0, navController.flickable.contentHeight - navController.flickable.height);
            const target = Math.min(Math.max(targetY, 0), maxY);
            if (Math.abs(target - navController.flickable.contentY) < 1) {
                navController.finish(token);
                return;
            }
            navController.scrollAnimation.to = target;
            navController.scrollAnimation.start();
        }

        function finish(token) {
            if (token !== navController.navToken)
                return;
            navController.navInProgress = false;
            if (navController.navFocusIndex >= 0)
                navController.focusIndex = navController.navFocusIndex;
            navController.navFocusIndex = -1;
        }

        function cancel() {
            if (!navController.navInProgress)
                return;
            navController.navToken++;
            navController.navInProgress = false;
            navController.navFocusIndex = -1;
            navController.scrollAnimation.stop();
        }

        function clearFocus() {
            navController.cancel();
            navController.syncFromScroll();
        }

        function resetForModelChange() {
            navController.cancel();
            navController.hoverIndex = -1;
            navController.activeIndex = Math.max(0, Math.min(navController.activeIndex, navController.categories.length - 1));
            navController.focusIndex = navController.activeIndex;
            Qt.callLater(() => navController.syncFromScroll());
        }

        onCategoriesChanged: navController.resetForModelChange()

        property NumberAnimation scrollAnimation: NumberAnimation {
            target: navController.flickable
            property: "contentY"
            duration: Theme.anim.defaultSpatial
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (running)
                    return;
                const token = navController.navToken;
                Qt.callLater(() => {
                    if (token !== navController.navToken || navController.scrollAnimation.running)
                        return;
                    navController.finish(token);
                });
            }
        }

        property Connections scrollHooks: Connections {
            target: navController.flickable
            function onContentYChanged() {
                if (navController.navInProgress)
                    return;
                navController.syncFromScroll();
            }
            function onContentHeightChanged() {
                if (navController.navInProgress)
                    return;
                navController.syncFromScroll();
            }
            function onHeightChanged() {
                if (navController.navInProgress)
                    return;
                navController.syncFromScroll();
            }
            function onMovementStarted() {
                navController.cancel();
            }
            function onFlickStarted() {
                navController.cancel();
            }
        }
    }

    default property alias content: body.data

    Row {
        width: parent.width
        height: parent.height
        spacing: Theme.spacing

        Item {
            id: navColumn

            width: root.panelWidth
            height: parent.height

            Column {
                id: colPanel

                width: parent.width - 8
                height: parent.height
                spacing: Theme.spacing

                Rectangle {
                    id: navBar

                    width: parent.width
                    property var model: root.navModel
                    property int currentIndex: root.sectionMode ? navController.activeIndex : root.navCurrentIndex
                    property QtObject nav: root.sectionMode ? navController : null
                    property int hoveredIndex: -1

                    readonly property int inset: Theme.pad
                    readonly property int entryHeight: Math.max(28, Theme.fontSize + 16)
                    readonly property int entrySpacing: 2
                    readonly property int rowWidth: Math.max(0, width - inset * 2)

                    color: Theme.surface
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1
                    clip: true
                    implicitHeight: entries.implicitHeight + inset * 2

                    onVisibleChanged: if (!navBar.visible)
                        navBar.hoveredIndex = -1
                    onModelChanged: navBar.hoveredIndex = -1

                    function labelAt(index) {
                        const entry = navBar.model[index];
                        if (entry === undefined || entry === null)
                            return "";
                        return typeof entry === "string" ? entry : (entry.title || "");
                    }

                    function entryEnabledAt(index) {
                        const entry = navBar.model[index];
                        if (entry === undefined || entry === null)
                            return true;
                        return typeof entry === "string" ? true : entry.enabled !== false;
                    }

                    Rectangle {
                        id: highlight

                        visible: navBar.model.length > 0
                        x: navBar.inset
                        y: navBar.inset + Math.max(0, Math.min(navBar.currentIndex, navBar.model.length - 1)) * (navBar.entryHeight + navBar.entrySpacing)
                        width: navBar.rowWidth
                        height: navBar.entryHeight
                        radius: Math.max(4, Theme.radius - 4)
                        color: Theme.surfaceActive
                        Behavior on y {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                        Behavior on height {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                        Behavior on color {
                            CAnim {}
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: Math.min(parent.height - 10, 16)
                            radius: 1
                            color: Theme.accent
                        }
                    }

                    Column {
                        id: entries

                        x: navBar.inset
                        y: navBar.inset
                        width: navBar.rowWidth
                        spacing: navBar.entrySpacing

                        Repeater {
                            model: navBar.model

                            delegate: Item {
                                id: cell

                                required property var modelData
                                required property int index
                                readonly property bool active: index === navBar.currentIndex
                                readonly property bool cellEnabled: navBar.entryEnabledAt(index)

                                width: entries.width
                                height: navBar.entryHeight
                                opacity: (cell.cellEnabled ? 1 : 0.45) * (navBar.nav ? navBar.nav.falloffFor(index, navBar.hoveredIndex) : 1)
                                Behavior on opacity {
                                    Anim {
                                        type: Anim.DefaultEffects
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.max(4, Theme.radius - 4)
                                    color: cell.active ? "transparent" : (hover.hovered ? Theme.rgba(Theme.fg, 0.06) : "transparent")
                                    Behavior on color {
                                        CAnim {}
                                    }
                                }

                                Text {
                                    id: label

                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navBar.labelAt(cell.index)
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: cell.active
                                    color: cell.cellEnabled ? (cell.active ? Theme.accent : (hover.hovered ? Theme.fg : Theme.fgDim)) : Theme.muted
                                    Behavior on color {
                                        CAnim {}
                                    }
                                }

                                AppTooltip {
                                    visible: hover.containsMouse && label.truncated
                                    text: label.text
                                }

                                MouseArea {
                                    id: hover

                                    anchors.fill: parent
                                    enabled: cell.cellEnabled
                                    hoverEnabled: true
                                    cursorShape: cell.cellEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (cell.cellEnabled) {
                                        if (root.sectionMode)
                                            navController.select(cell.index);
                                        else
                                            root.navSelected(cell.index);
                                    }
                                    onEntered: navBar.hoveredIndex = cell.index
                                    onExited: if (navBar.hoveredIndex === cell.index)
                                        navBar.hoveredIndex = -1
                                }
                            }
                        }
                    }
                }

                Item {
                    id: body

                    width: parent.width
                    height: Math.max(0, colPanel.height - navBar.height - colPanel.spacing)
                    clip: true
                }
            }
        }

        SmoothFlickable {
            id: sectionScroll

            visible: root.sectionMode
            width: Math.max(0, root.width - root.panelWidth - Theme.spacing)
            height: parent.height
            clip: true
            contentWidth: width
            contentHeight: sectionCol.height
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                onPressedChanged: {
                    if (pressed)
                        navController.cancel();
                }
            }

            Column {
                id: sectionCol

                width: sectionScroll.width
                spacing: Theme.spacing

                Repeater {
                    model: root.sectionMode ? root.navModel : []

                    delegate: Rectangle {
                        id: sectionCard

                        required property int index
                        property int categoryIndex: index
                        property string title: root.titleFor(index)

                        onTitleChanged: {
                            if (bodyLoader.item && "category" in bodyLoader.item)
                                bodyLoader.item.category = sectionCard.title;
                        }

                        width: sectionCol.width
                        implicitHeight: cardBody.implicitHeight + Theme.pad * 2 + 8
                        radius: Theme.radius
                        color: Theme.surface
                        border.color: Theme.border
                        border.width: 1

                        opacity: navController.opacityFor(sectionCard.categoryIndex)
                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered)
                                    navController.hoverIndex = sectionCard.categoryIndex;
                                else if (navController.hoverIndex === sectionCard.categoryIndex)
                                    navController.hoverIndex = -1;
                            }
                        }

                        Column {
                            id: cardBody

                            anchors.fill: parent
                            anchors.margins: Theme.pad
                            spacing: Theme.spacing

                            Label {
                                width: parent.width
                                topPadding: Theme.pad / 2
                                text: sectionCard.title
                                font.pixelSize: Theme.fontSize + 2
                                font.bold: true
                                color: Theme.accent
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Loader {
                                id: bodyLoader

                                width: parent.width
                                // Loaded bodies are positioner roots: height stays 0,
                                // only implicitHeight carries their size.
                                height: bodyLoader.item ? bodyLoader.item.implicitHeight : 0
                                sourceComponent: root.sections[sectionCard.index] || null
                                onLoaded: {
                                    if (bodyLoader.item && "category" in bodyLoader.item)
                                        bodyLoader.item.category = sectionCard.title;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Resize line: one full-height Rectangle, so the line cannot run short on either side of
    // the grip, and the grip is centred on it by construction rather than by font metrics.
    readonly property color gripTone: gripArea.containsMouse || gripArea.pressed ? Theme.accent : Theme.border

    Rectangle {
        x: root.panelWidth - 1
        y: 0
        width: 1
        height: root.height
        color: root.gripTone

        // Centred on paintedWidth/Height, not painted box centre: the glyph's ink is not
        // symmetric inside its advance, and this line is only 1 px wide.
        Text {
            x: Math.round((parent.width - paintedWidth) / 2)
            y: Math.round((parent.height - paintedHeight) / 2)
            text: Icons.dragVertical
            textFormat: Text.PlainText
            font.family: Theme.fontFamily * 1.5
            font.pixelSize: Theme.fontSize
            color: root.gripTone
        }
    }

    MouseArea {
        id: gripArea

        x: root.panelWidth - 4
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor

        property int _startGlobal: 0
        property int _startWidth: 0

        onPressed: {
            _startGlobal = root.panelWidth - 4 + mouseX;
            _startWidth = root.panelWidth;
        }
        onPositionChanged: {
            if (!pressed)
                return;
            const global = root.panelWidth - 4 + mouseX;
            const maxW = Math.max(root.minWidth, (root.parent ? root.parent.width : 0) - 240);
            root.panelWidth = Math.min(maxW, Math.max(root.minWidth, Math.round(_startWidth + (global - _startGlobal))));
        }
        onReleased: if (typeof Settings !== "undefined")
            Settings.leftNavPanelWidth = root.panelWidth
    }
}
