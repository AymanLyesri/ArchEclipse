import QtQuick
import qs.theme

// Shared category navigation for panel widgets (Settings, Key Binds, …).
//
// Owns the active/focus state, the animated centering scroll and the
// programmatic-vs-manual scroll distinction. A host supplies the Flickable,
// its content Column and the category model; every section item declares a
// `categoryIndex` and is a direct child of that Column, so targets are
// derived from live geometry instead of hardcoded offsets.
//
// Manual scrolling clears the focus effect; the host wires its ScrollBar's
// pressed signal to cancel() (wheel/drag are handled here via the
// Flickable's own signals).
QtObject {
    id: root

    // Category entries: strings or { title } objects (CategoryRail renders
    // either; titleFor() normalizes them).
    property var categories: []
    property Flickable flickable: null
    // The scrolling Column. Its direct children are the category sections.
    property Item content: null

    // activeIndex: rail highlight (set immediately on select()).
    // focusIndex/focusActive: the distance fade, applied only when the
    // scroll settles so it never jumps mid-flight.
    // navInProgress: true while the animation owns contentY, so the
    // manual-scroll handler ignores its own writes.
    // navToken: only the newest navigation may announce completion.
    property int activeIndex: 0
    property int focusIndex: 0
    property bool focusActive: false
    property bool navInProgress: false
    property int navToken: 0
    property int navFocusIndex: -1

    // Distance falloff: restrained enough that neighbouring sections stay
    // readable; far ones recede but never disappear.
    readonly property real minimumOpacity: 0.58
    readonly property real opacityStep: 0.18

    function titleFor(index) {
        const entry = root.categories[index];
        if (entry === undefined || entry === null)
            return "";
        return typeof entry === "string" ? entry : (entry.title || "");
    }

    function opacityFor(index) {
        if (!root.focusActive)
            return 1;
        return Math.max(root.minimumOpacity, 1 - Math.abs(index - root.focusIndex) * root.opacityStep);
    }

    function sectionItem(index) {
        if (!root.content)
            return null;
        for (let i = 0; i < root.content.children.length; i++) {
            const child = root.content.children[i];
            if (child.categoryIndex === index)
                return child;
        }
        return null;
    }

    function indexForY(y) {
        if (!root.content)
            return 0;
        for (let i = 0; i < root.content.children.length; i++) {
            const child = root.content.children[i];
            if (child.categoryIndex === undefined)
                continue;
            if (y < child.y + child.height)
                return child.categoryIndex;
        }
        return Math.max(0, root.categories.length - 1);
    }

    function targetFor(index) {
        const item = root.sectionItem(index);
        if (!item || !root.flickable)
            return 0;
        const viewport = root.flickable.height;
        // A section taller than the viewport cannot be centred without
        // pushing its header off-screen; pin its top just below the edge.
        const target = item.height >= viewport ? item.y - Theme.pad : item.y + item.height / 2 - viewport / 2;
        const maxY = Math.max(0, root.flickable.contentHeight - viewport);
        return Math.min(Math.max(target, 0), maxY);
    }

    function select(index) {
        if (index < 0 || index >= root.categories.length)
            return;
        root.activeIndex = index;
        root.scrollToY(root.targetFor(index), index);
    }

    // One animated scroll path for rail clicks and deep links.
    // `focusIndex < 0` navigates without applying the focus pattern.
    function scrollToY(targetY, focusIndex) {
        root.navToken++;
        const token = root.navToken;
        root.navFocusIndex = focusIndex;
        root.navInProgress = true;
        // stop() + retarget + start(): a newer selection always wins the
        // same animation, so rapid clicks never queue or race.
        root.scrollAnimation.stop();
        if (!root.flickable) {
            root.finish(token);
            return;
        }
        const maxY = Math.max(0, root.flickable.contentHeight - root.flickable.height);
        const target = Math.min(Math.max(targetY, 0), maxY);
        if (Math.abs(target - root.flickable.contentY) < 1) {
            root.finish(token);
            return;
        }
        root.scrollAnimation.to = target;
        root.scrollAnimation.start();
    }

    function finish(token) {
        if (token !== root.navToken)
            return;
        root.navInProgress = false;
        if (root.navFocusIndex >= 0) {
            root.focusIndex = root.navFocusIndex;
            root.focusActive = true;
        }
        root.navFocusIndex = -1;
    }

    // A real gesture cancels an in-flight programmatic scroll so it wins.
    function cancel() {
        if (!root.navInProgress)
            return;
        root.navToken++;
        root.navInProgress = false;
        root.navFocusIndex = -1;
        root.scrollAnimation.stop();
    }

    function clearFocus() {
        root.focusActive = false;
        root.cancel();
    }

    // Model reloads shift indices (Key Binds parses its categories from
    // files); keep the rail in range and drop a stale focus pattern.
    function resetForModelChange() {
        root.cancel();
        root.focusActive = false;
        root.focusIndex = 0;
        root.activeIndex = Math.max(0, Math.min(root.activeIndex, root.categories.length - 1));
    }

    onCategoriesChanged: root.resetForModelChange()

    // Deferred completion check: restart() stops then starts in the same
    // tick, so a stop handler must not finalize the previous target. The
    // token also rejects every superseded navigation.
    property NumberAnimation scrollAnimation: NumberAnimation {
        target: root.flickable
        property: "contentY"
        duration: Theme.anim.defaultSpatial
        easing.type: Easing.OutCubic
        onRunningChanged: {
            if (running)
                return;
            const token = root.navToken;
            Qt.callLater(() => {
                if (token !== root.navToken || root.scrollAnimation.running)
                    return;
                root.finish(token);
            });
        }
    }

    property Connections scrollHooks: Connections {
        target: root.flickable
        // Manual scroll = any contentY change that isn't ours. navInProgress
        // is still true for the final animation frame, so the automatic
        // scroll can't clear its own focus.
        function onContentYChanged() {
            if (root.navInProgress)
                return;
            if (root.focusActive)
                root.focusActive = false;
        }
        function onMovementStarted() {
            root.cancel();
        }
        function onFlickStarted() {
            root.cancel();
        }
    }
}
