import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.widgets.shared
import qs.theme

// Stacked page grid: one masonry block per loaded page with a full-width divider. Owns the
// edge prefetch, scroll-spy and capture/restore compensation; page state stays in the viewer.
SmoothFlickable {
    id: gridScroll

    property var viewer
    // Blocks mirror viewer.loadedPages. A ListModel keeps a pure append incremental: a JS
    // array model resets the Repeater and every card would be re-instantiated.
    readonly property var pages: viewer && viewer.loadedPages ? viewer.loadedPages : []
    property real _lastCheckY: -1
    property bool _edgeAgain: false
    property int _scrollTarget: 0
    property var _restoreCap: null
    property double _capStamp: 0
    property bool _zoneBelow: false
    property bool _zoneAbove: false
    property double _edgeStamp: 0
    // Flickable exposes no velocity and assigning contentY ends its coast, so the correction has
    // to hand the remaining momentum back itself or the scroll stops dead on every prepend.
    property real _velY: 0
    property double _velT: 0
    property real _velPrevY: 0

    signal needPageAbove
    signal needPageBelow
    signal pageBecameVisible(int page)

    // Always full width: the detail is a root-level overlay, so the grid
    // never surrenders space or relayouts when it opens.
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    contentWidth: width
    contentHeight: pageColumn.implicitHeight
    // Booru pins the fling speed lower than the shared default.
    maximumFlickVelocity: 1000

    function slideFrom(x) {
        slideAnim.stop();
        pageColumn.x = x;
        slideAnim.start();
    }

    function scrollToTop() {
        gridScroll._scrollTarget = 0;
        gridScroll._restoreCap = null;
        gridScroll._zoneBelow = false;
        gridScroll._zoneAbove = false;
        cancelFlick();
        contentY = 0;
        gridScroll._lastCheckY = 0;
    }

    function scrollToPage(pageNo) {
        gridScroll._scrollTarget = pageNo;
        gridScroll._capStamp = Date.now();
    }

    function clampY(y) {
        return Math.max(0, Math.min(Math.max(0, contentHeight - height), y));
    }

    function blockForPage(pageNo) {
        for (let i = 0; i < pageRepeater.count; i++) {
            const it = pageRepeater.itemAt(i);
            if (it && it.pageNo === pageNo)
                return it;
        }
        return null;
    }

    function imagesFor(pageNo) {
        const e = gridScroll.viewer ? gridScroll.viewer.pageEntry(pageNo) : null;
        return e && e.images ? e.images : [];
    }

    // Anchor = the page block under the viewport probe plus its y now. Corrections use how far
    // that y moves, not an absolute offset: between capture and layout the flick keeps scrolling,
    // and restoring the old offset snapped the view back instead of keeping the coast.
    function captureViewport() {
        const probe = contentY + height * 0.35;
        let near = null;
        for (let i = 0; i < pages.length; i++) {
            const it = pageRepeater.itemAt(i);
            if (!it)
                continue;
            if (probe >= it.y && probe < it.y + it.height)
                return {
                    "page": it.pageNo,
                    "appliedY": it.y
                };
            const dist = Math.abs(probe - it.y);
            if (!near || dist < near.dist)
                near = {
                    "page": it.pageNo,
                    "appliedY": it.y,
                    "dist": dist
                };
        }
        return near ? {
            "page": near.page,
            "appliedY": near.appliedY
        } : null;
    }

    // Keep a coast alive across a viewport write: `flick()` restarts the momentum the assignment
    // killed; idle corrections have nothing to carry.
    function setContentYKeepFlick(y) {
        const wasFlicking = flicking;
        const v = gridScroll._velY;
        cancelFlick();
        contentY = clampY(y);
        if (wasFlicking && Math.abs(v) > 60) {
            flick(0, v);
            gridScroll._velPrevY = contentY;
            gridScroll._velT = Date.now();
        }
    }

    // Arms the anchor correction. It cannot run here: at model-change time no block has moved yet,
    // so the delta is taken on the next layout tick instead.
    function restoreViewport(cap) {
        if (!cap)
            return;
        gridScroll._scrollTarget = 0;
        gridScroll._restoreCap = cap;
        gridScroll._capStamp = Date.now();
    }

    // A page jump needs the block's final y (positioningComplete), while a capture only moves by the
    // anchor's delta, so it is applied on every tick and again while its 400 ms window stays open.
    function applyPendingViewport(settled) {
        const fresh = Date.now() - gridScroll._capStamp < 400;
        if (gridScroll._scrollTarget > 0) {
            const block = blockForPage(gridScroll._scrollTarget);
            // Landing a page is not a scroll: leftover flick momentum would drift the viewport
            // straight back into the prefetch margin and request the page just inserted.
            if (block) {
                cancelFlick();
                contentY = clampY(block.y);
                gridScroll._lastCheckY = contentY;
            }
            gridScroll._restoreCap = null;
            if (settled || !fresh)
                gridScroll._scrollTarget = 0;
            return;
        }
        const cap = gridScroll._restoreCap;
        if (!cap)
            return;
        const block = blockForPage(cap.page);
        // Only the growth since the last apply is compensated, so a correction that lands mid-flick
        // keeps whatever the user scrolled in the meantime and only undoes the layout shift.
        if (block && block.y !== cap.appliedY) {
            setContentYKeepFlick(contentY + (block.y - cap.appliedY));
            cap.appliedY = block.y;
            gridScroll._lastCheckY = contentY;
        }
        if (!fresh)
            gridScroll._restoreCap = null;
        spy();
    }

    // Mirror loadedPages row by row: insert/remove keep the surviving delegates, because a
    // clear() rebuild on prepend re-creates every card and the whole grid flashes its images.
    function syncPages() {
        const list = gridScroll.pages;
        for (let i = pageModel.count - 1; i >= 0; i--) {
            const pageNo = pageModel.get(i).pageNo;
            let keep = false;
            for (let j = 0; j < list.length && !keep; j++)
                keep = list[j].page === pageNo;
            if (!keep)
                pageModel.remove(i);
        }
        for (let i = 0; i < list.length; i++) {
            if (i >= pageModel.count || pageModel.get(i).pageNo !== list[i].page) {
                pageModel.insert(i, {
                    "pageNo": list[i].page,
                    "loading": !!list[i].loading,
                    "error": list[i].error || ""
                });
                continue;
            }
            const row = pageModel.get(i);
            if (row.loading !== !!list[i].loading)
                pageModel.setProperty(i, "loading", !!list[i].loading);
            if ((row.error || "") !== (list[i].error || ""))
                pageModel.setProperty(i, "error", list[i].error || "");
            const block = gridScroll.blockForPage(list[i].page);
            if (block && block.imgs !== list[i].images)
                block.imgs = list[i].images;
        }
    }

    function requestBelow() {
        if (!viewer || pages.length === 0 || viewer.endBelow || viewer.loadingBelow)
            return;
        const next = viewer.maxLoadedPage() + 1;
        if (next < 1 || viewer.hasPage(next))
            return;
        needPageBelow();
    }

    function requestAbove() {
        if (!viewer || pages.length === 0 || viewer.endAbove || viewer.loadingAbove)
            return;
        const prev = viewer.minLoadedPage() - 1;
        if (prev < 1 || viewer.hasPage(prev))
            return;
        needPageAbove();
    }

    // Short content cannot be scrolled, so nothing would ever ask for the next page: fill
    // forward one block at a time (never backwards).
    function maybeAutoFill() {
        if (viewer && pages.length > 0)
            autoFillTimer.restart();
    }

    // Checked only after the layout settles: a just-created block is 0-high for a frame, which
    // reads as "shorter than the viewport" and used to chain pages on every open.
    function autoFill() {
        if (!viewer || pages.length === 0 || viewer.endBelow || viewer.loadingBelow || contentHeight > height)
            return;
        const last = pages[pages.length - 1];
        if (last.loading || last.error || viewer.hasPage(last.page + 1))
            return;
        needPageBelow();
    }

    function checkEdges() {
        if (!viewer)
            return;
        const y = contentY;
        const dir = _lastCheckY < 0 ? 0 : (y > _lastCheckY ? 1 : (y < _lastCheckY ? -1 : 0));
        _lastCheckY = y;
        // Two pages per gesture is never right: a gesture reversing inside the margin used to
        // fire both sides back to back while the other page was still loading.
        if (Date.now() - _edgeStamp < 900)
            return;
        // A quarter of the scroll range, capped at 1.5 viewports: SmoothWheelHandler refuses wheel
        // input at the hard edge, so the band must start early. A band wider than a quarter of a
        // short stack covers the middle too, and one gesture then fetches both neighbours.
        const band = Math.min(height * 1.5, Math.max(0, contentHeight - height) * 0.25);
        if (contentHeight > height) {
            const nearBelow = y + height >= contentHeight - band;
            const nearAbove = y <= band;
            // One request per zone visit: the loading placeholder is only 44px tall, so a
            // per-tick edge check would queue every remaining page in one scroll gesture.
            if (!nearBelow)
                _zoneBelow = false;
            if (!nearAbove)
                _zoneAbove = false;
            if (nearBelow && !_zoneBelow && dir > 0) {
                _zoneBelow = true;
                _edgeStamp = Date.now();
                requestBelow();
            }
            if (nearAbove && !_zoneAbove && dir < 0) {
                _zoneAbove = true;
                _edgeStamp = Date.now();
                requestAbove();
            }
        }
        maybeAutoFill();
    }

    function spy() {
        if (!viewer)
            return;
        const probe = contentY + height * 0.35;
        for (let i = 0; i < pageRepeater.count; i++) {
            const it = pageRepeater.itemAt(i);
            if (!it)
                continue;
            if (probe >= it.y && probe < it.y + it.height) {
                pageBecameVisible(it.pageNo);
                return;
            }
        }
    }

    // Follow tick: the card glides inside the static popup, so scrolling only retargets a local
    // y binding plus the cheap dismiss check — no window reposition, no stutter.
    onContentYChanged: {
        if (viewer && viewer.dialogImage !== null)
            viewer.refreshDialogTop(-1);
        // Velocity for the flick hand-back. Bounds rebounds invert the delta, so a sample outside
        // the scroll range is dropped instead of restarting the coast in the wrong direction.
        if (flicking) {
            const t = Date.now();
            const dt = t - gridScroll._velT;
            const maxY = Math.max(0, contentHeight - height);
            if (gridScroll._velT > 0 && dt > 0 && dt < 200)
                gridScroll._velY = contentY >= 0 && contentY <= maxY ? -(contentY - gridScroll._velPrevY) / dt * 1000 : 0;
            gridScroll._velPrevY = contentY;
            gridScroll._velT = t;
        }
        _edgeAgain = true;
        if (!edgeTimer.running)
            edgeTimer.start();
        if (!spyTimer.running)
            spyTimer.start();
    }
    onHeightChanged: {
        if (viewer && viewer.dialogImage !== null)
            viewer.refreshDialogTop(-1);
        maybeAutoFill();
    }
    onMovementEnded: {
        checkEdges();
        spy();
    }
    onContentHeightChanged: maybeAutoFill()

    Connections {
        target: gridScroll.viewer
        function onLoadedPagesChanged() {
            gridScroll.syncPages();
            Qt.callLater(gridScroll.spy);
        }
    }

    Component {
        id: cardComp

        Item {
            // NOTE: plain (not required) modelData — a Loader cannot supply required props at
            // creation; BooruImage has required props, so guard undefined until it arrives.
            property var modelData
            width: parent.width
            height: cardLoader.item ? cardLoader.item.height : 0

            Loader {
                id: cardLoader

                width: parent.width
                active: parent.modelData !== undefined
                sourceComponent: booruCardComp
                property var image: parent.modelData
                property var viewer: gridScroll.viewer
            }
        }
    }

    Component {
        id: booruCardComp

        BooruImage {
            width: parent.width
            viewer: parent.viewer
            image: parent.image
        }
    }

    Column {
        id: pageColumn

        width: gridScroll.width
        spacing: 0
        onPositioningComplete: gridScroll.applyPendingViewport(true)

        Repeater {
            id: pageRepeater
            model: ListModel {
                id: pageModel
            }

            delegate: Column {
                id: pageBlock
                required property int pageNo
                required property int index
                required property bool loading
                required property string error
                // Pushed by syncPages()/creation: never bound, so unrelated page changes cannot
                // restart this block's masonry delegates.
                property var imgs: []

                width: pageColumn.width
                height: implicitHeight
                spacing: Theme.spacing

                Component.onCompleted: pageBlock.imgs = gridScroll.imagesFor(pageBlock.pageNo)

                // Divider: full-width rule with a centred page label (none above the first block).
                Item {
                    width: pageBlock.width
                    height: pageBlock.index > 0 ? 26 : 0
                    visible: pageBlock.index > 0

                    Row {
                        id: ruleRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.max(14, ruleLabel.implicitHeight)
                        spacing: Theme.spacing

                        Rectangle {
                            width: Math.max(0, (ruleRow.width - ruleLabel.implicitWidth - ruleRow.spacing * 2) / 2)
                            height: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.border
                        }
                        Text {
                            id: ruleLabel

                            anchors.verticalCenter: parent.verticalCenter
                            text: "Page " + pageBlock.pageNo
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                        }
                        Rectangle {
                            width: Math.max(0, (ruleRow.width - ruleLabel.implicitWidth - ruleRow.spacing * 2) / 2)
                            height: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.border
                        }
                    }
                }

                // Shared masonry: shortest-column by aspect ratio, per page block.
                AppMasonry {
                    width: pageBlock.width
                    height: implicitHeight
                    columns: gridScroll.viewer ? gridScroll.viewer.columns : 3
                    model: pageBlock.imgs
                    aspectRatio: function (img) {
                        return (img && img.width && img.height) ? img.height / img.width : 1;
                    }
                    delegate: cardComp
                }

                // Edge request state stays inline: page buttons and loaded pages are untouched.
                Row {
                    width: pageBlock.width
                    height: visible ? 44 : 0
                    visible: pageBlock.loading || pageBlock.error !== ""
                    spacing: Theme.spacing

                    AppProgress {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        variant: "spinner"
                        status: pageBlock.error !== "" ? "error" : "loading"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, pageBlock.width - 140)
                        text: pageBlock.error !== "" ? "Could not load page " + pageBlock.pageNo + " — " + pageBlock.error : "Loading page " + pageBlock.pageNo + "…"
                        elide: Text.ElideRight
                        color: pageBlock.error !== "" ? Theme.danger : Theme.muted
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }
                    AppButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pageBlock.error !== ""
                        height: 22
                        pixelSize: Theme.fontSizeSmall
                        text: "Retry"
                        tooltipText: "Retry page " + pageBlock.pageNo
                        onClicked: {
                            if (gridScroll.viewer)
                                gridScroll.viewer.retryPage(pageBlock.pageNo);
                        }
                    }
                }
            }
        }

        // Subtle end note: an edge request came back empty, so that side stops for good.
        Item {
            width: pageColumn.width
            height: visible ? 44 : 0
            visible: gridScroll.viewer && gridScroll.viewer.endBelow

            Text {
                anchors.centerIn: parent
                text: "No more results"
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }
        }
    }

    // Throttled edge sampler: coalesces per-frame contentY changes into one check.
    Timer {
        id: edgeTimer

        interval: 120
        repeat: false
        onTriggered: {
            gridScroll._edgeAgain = false;
            gridScroll.checkEdges();
            if (gridScroll._edgeAgain)
                edgeTimer.restart();
        }
    }

    Timer {
        id: spyTimer

        interval: 140
        repeat: false
        onTriggered: gridScroll.spy()
    }

    Timer {
        id: autoFillTimer

        interval: 260
        repeat: false
        onTriggered: gridScroll.autoFill()
    }

    // Retries a pending scroll/restore when no reposition happens; stops once applied or stale.
    // One frame, not 60 ms: the compensation is a delta and idempotent, so landing it in the same
    // frame as the layout hides the shift that used to read as a pop.
    Timer {
        id: layoutFallback

        interval: 16
        repeat: true
        running: gridScroll._restoreCap !== null || gridScroll._scrollTarget > 0
        onTriggered: gridScroll.applyPendingViewport(false)
    }

    // Slide transition on a full replace (jump / new search).
    NumberAnimation {
        id: slideAnim

        target: pageColumn
        property: "x"
        duration: Theme.anim.small
        to: 0
    }

    ScrollBar.vertical: ScrollBar {
    }
}
