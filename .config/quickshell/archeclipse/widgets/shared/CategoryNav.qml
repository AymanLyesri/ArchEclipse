import QtQuick
import qs.theme

// Shared category navigation (Settings, Key Binds): hosts pass the Flickable,
// its content Column and the model; rail clicks and scrolls drive the selection.
QtObject {
    id: root

    // Category entries: strings or { title } objects (CategoryRail renders
    // either; titleFor() normalizes them).
    property var categories: []
    property Flickable flickable: null
    // The scrolling Column. Its direct children are the category sections.
    property Item content: null

    // activeIndex: rail pill, re-derived on scroll. focusIndex: fade anchor.
    // navInProgress/navToken: an in-flight animation owns contentY.
    property int activeIndex: 0
    property int focusIndex: 0
    property bool navInProgress: false
    property int navToken: 0
    property int navFocusIndex: -1
    // Card hover anchor. Any scroll clears it, so the scroll fade always re-wins after a gesture.
    property int hoverIndex: -1

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

    // One falloff for every host: the fading sections anchor on focusIndex, a rail hover
    // anchors on its own entry, so both read identically.
    function falloffFor(index, anchor) {
        if (anchor === undefined || anchor < 0)
            return 1;
        return Math.max(root.minimumOpacity, 1 - Math.abs(index - anchor) * root.opacityStep);
    }

    function opacityFor(index) {
        return root.falloffFor(index, root.hoverIndex >= 0 ? root.hoverIndex : root.focusIndex);
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

    // Selection anchor: viewport centre, squashed to the content edges over the
    // first/last half viewport — the scroll range is a viewport shorter.
    function anchorY() {
        const f = root.flickable;
        const half = f.height / 2;
        const maxY = Math.max(0, f.contentHeight - f.height);
        const y = f.contentY;
        if (maxY <= 0)
            return f.contentHeight / 2;
        if (y <= 0)
            return 0;
        if (y >= maxY)
            return f.contentHeight;
        // Half a viewport, or half the scroll range when the content is
        // barely taller than the viewport (the two zones then meet).
        const zone = Math.min(half, maxY / 2);
        if (y < zone)
            return y * (zone + half) / zone;
        if (y > maxY - zone)
            return f.contentHeight - (maxY - y) * (zone + half) / zone;
        return y + half;
    }

    // Contains wins over nearest midpoint: a section taller than the viewport
    // can't be centred (targetFor pins its top), so it must still own the anchor.
    function centeredIndex() {
        if (!root.content || !root.flickable)
            return root.activeIndex;
        const anchor = root.anchorY();
        let nearest = -1;
        let nearestDistance = Infinity;
        for (let i = 0; i < root.content.children.length; i++) {
            const child = root.content.children[i];
            // Zero-height children are unbuilt or hidden; they own no pixels
            // and must not win the nearest-midpoint fallback.
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
        return nearest >= 0 ? nearest : root.activeIndex;
    }

    // Manual scroll path: rail pill and fade both follow the centred
    // category live, mid-gesture, so neither is ever dropped.
    function syncFromScroll() {
        // Pre-layout every section sits at y=0 and the viewport is 0-sized;
        // deriving from that parks the selection on an arbitrary index.
        if (!root.flickable || root.flickable.height <= 0 || root.flickable.contentHeight <= 0)
            return;
        const index = root.centeredIndex();
        if (index < 0)
            return;
        root.hoverIndex = -1;
        root.activeIndex = index;
        root.focusIndex = index;
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
        if (root.navFocusIndex >= 0)
            root.focusIndex = root.navFocusIndex;
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

    // Hosts call this on close/reset: stop an in-flight animation and re-anchor
    // on what is centred (the fade is permanent now).
    function clearFocus() {
        root.cancel();
        root.syncFromScroll();
    }

    // Key Binds reloads shift indices: keep the rail in range, re-anchor once
    // the new sections are laid out.
    function resetForModelChange() {
        root.cancel();
        root.hoverIndex = -1;
        root.activeIndex = Math.max(0, Math.min(root.activeIndex, root.categories.length - 1));
        root.focusIndex = root.activeIndex;
        Qt.callLater(() => root.syncFromScroll());
    }

    onCategoriesChanged: root.resetForModelChange()

    // restart() stops then starts in one tick, so completion is deferred: only
    // the newest token may finalize.
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
        // Manual scroll = any contentY change that isn't ours (navInProgress is
        // still true on the final animation frame).
        function onContentYChanged() {
            if (root.navInProgress)
                return;
            root.syncFromScroll();
        }
        // Geometry can shift under a still contentY (dynamic rows, reveal
        // layout, resize): re-anchor so the rail never points elsewhere.
        function onContentHeightChanged() {
            if (root.navInProgress)
                return;
            root.syncFromScroll();
        }
        function onHeightChanged() {
            if (root.navInProgress)
                return;
            root.syncFromScroll();
        }
        function onMovementStarted() {
            root.cancel();
        }
        function onFlickStarted() {
            root.cancel();
        }
    }
}
