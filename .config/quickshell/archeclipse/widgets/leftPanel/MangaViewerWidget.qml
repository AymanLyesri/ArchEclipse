import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services

// Manga Viewer widget.
// Backend: scripts/manga.py (mangadex CLI provider, JSON output)
// Tabs: Manga (list/search) -> Chapters -> Pages (reader with prev/next)
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/manga.py"

    // Provider state — supported backends: MangaDex + MangaLib
    property string provider: "mangadex"
    readonly property var providers: [
        {
            label: "MangaDex",
            id: "mangadex"
        },
        {
            label: "MangaLib",
            id: "mangalib"
        }
    ]

    // State
    property var mangaList: []
    property var selectedManga: null
    property var chapters: []
    property var selectedChapter: null
    property var pages: []
    property var pageCache: ({})
    property int currentPageIndex: 0
    property string currentTab: "Manga"
    property string progressStatus: "idle"
    property string searchQuery: ""
    property bool bottomRevealed: false
    property var mainFlickable: null   // set by Pages Flickable, for scroll reset

    Component.onCompleted: fetchPopular()

    function toFileUrl(path) {
        if (!path)
            return "";
        return /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(path) ? path : "file://" + path;
    }

    // ===== API CALLS =====
    function fetchPopular() {
        root.progressStatus = "loading";
        const p = _runScript.createObject(root);
        p.command = ["python3", scriptPath, "--provider", provider, "--popular", "--limit", "10"];
        p.onJson = function (data) {
            root.mangaList = data;
            root.progressStatus = "success";
        };
        p.running = true;
    }

    function searchManga(query) {
        root.progressStatus = "loading";
        if (!query.trim()) {
            fetchPopular();
            return;
        }
        const p = _runScript.createObject(root);
        p.command = ["python3", scriptPath, "--provider", provider, "--search", query.trim(), "--limit", "10"];
        p.onJson = function (data) {
            root.mangaList = data;
            root.progressStatus = "success";
        };
        p.running = true;
    }

    function fetchChapters(mangaId) {
        root.progressStatus = "loading";
        const p = _runScript.createObject(root);
        p.command = ["python3", scriptPath, "--provider", provider, "--chapters", "--manga-id", mangaId];
        p.onJson = function (data) {
            root.chapters = sortChapters(data);
            root.currentTab = "Chapters";
            root.progressStatus = "success";
        };
        p.running = true;
    }

    function fetchPages(chapterId) {
        root.progressStatus = "loading";
        const p = _runScript.createObject(root);
        p.command = ["python3", scriptPath, "--provider", provider, "--pages", "--chapter-id", chapterId];
        p.onJson = function (data) {
            root.pages = data;
            root.pageCache = ({});
            root.currentPageIndex = 0;
            root.currentTab = "Pages";
            root.progressStatus = "success";
            if (data && data.length > 0)
                loadPageAt(0);
        };
        p.running = true;
    }

    function loadPageAt(index) {
        if (index < 0 || index >= root.pages.length)
            return;
        if (root.pageCache[index]?.path)
            return;
        const page = root.pages[index];
        const p = _runScript.createObject(root);
        p.command = ["python3", scriptPath, "--provider", provider, "--page", page.url];
        p.onJson = function (data) {
            if (data?.path) {
                root.pageCache = Object.assign({}, root.pageCache, { [index]: data });
            }
        };
        p.running = true;
    }

    function navigatePage(dir) {
        const target = dir === "next" ? root.currentPageIndex + 1 : root.currentPageIndex - 1;
        if (target < 0 || target >= root.pages.length)
            return;
        root.currentPageIndex = target;
        if (!root.pageCache[target]?.path)
            loadPageAt(target);
        if (target + 1 < root.pages.length)
            loadPageAt(target + 1);
        if (target - 1 >= 0)
            loadPageAt(target - 1);
        if (root.mainFlickable)
            root.mainFlickable.contentY = 0;   // scroll to top on page change
    }

    // Move to the adjacent chapter in the sorted list
    function goToChapter(dir) {
        const current = root.selectedChapter;
        if (!current)
            return;
        const list = root.sortChapters(root.chapters);
        const index = list.findIndex(c => c.id === current.id);
        if (index === -1)
            return;
        const targetIndex = dir === "prev" ? index + 1 : index - 1;   // list is reverse-sorted (newest first)
        if (targetIndex < 0 || targetIndex >= list.length)
            return;
        const target = list[targetIndex];
        root.selectedChapter = target;
        root.fetchPages(target.id);
    }

    // Switch provider — reset all selection state and reload popular
    function switchProvider(id) {
        if (root.provider === id)
            return;
        root.provider = id;
        root.selectedManga = null;
        root.selectedChapter = null;
        root.chapters = [];
        root.pages = [];
        root.pageCache = ({});
        root.currentPageIndex = 0;
        root.currentTab = "Manga";
        root.fetchPopular();
    }

    // Build a real browser URL for the current manga/chapter
    function buildUrl(api, manga, chapter) {
        if (api === "mangadex") {
            if (chapter)
                return "https://mangadex.org/chapter/" + chapter.id;
            if (manga) {
                const slug = (manga.title || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
                return "https://mangadex.org/title/" + manga.id + "/" + slug;
            }
            return "https://mangadex.org";
        }
        if (api === "mangalib") {
            if (chapter) {
                const parts = (chapter.id || "").split("/");
                let mangaSlug = parts[0] || "";
                if (mangaSlug.includes("--"))
                    mangaSlug = mangaSlug.split("--")[1];
                const rawVol = chapter.volume || (parts[1] ? parts[1].replace("v", "") : "1");
                const rawCh = chapter.chapter || (parts[2] ? parts[2].replace("c", "") : "0");
                return "https://mangalib.org/ru/" + mangaSlug + "/read/v" + rawVol + "/c" + rawCh;
            }
            if (manga)
                return "https://mangalib.org/ru/manga/" + manga.id;
            return "https://mangalib.org";
        }
        return "";
    }

    function getUrl() {
        try {
            return root.buildUrl(root.provider, root.selectedManga, root.selectedChapter);
        } catch (e) {
            return "";
        }
    }

    function formatChapterLabel(ch, isAttachment) {
        const num = ch.chapter;
        const vol = ch.volume ? "Vol. " + ch.volume + " " : "";
        const title = (ch.title || "").trim();
        if (isAttachment) {
            if (!title || title === "Chapter " + num || title === "Глава " + num)
                return "\u21B3 Alternative version";
            return "\u21B3 " + title;
        }
        if (!num)
            return title || "Unknown Chapter";
        if (!title || title === "Chapter " + num || title === "Глава " + num)
            return vol + "Chapter " + num;
        if (title.includes("Chapter " + num) || title.includes("Глава " + num))
            return vol + title;
        return vol + "Chapter " + num + ": " + title;
    }

    function sortChapters(chList) {
        return chList.slice().sort((a, b) => {
            const volA = parseFloat(a.volume || "0"), volB = parseFloat(b.volume || "0");
            const isA = !isNaN(volA), isB = !isNaN(volB);
            if (isA && isB && volA !== volB)
                return volB - volA;
            const numA = parseFloat(a.chapter || "0"), numB = parseFloat(b.chapter || "0");
            const nA = !isNaN(numA), nB = !isNaN(numB);
            if (nA && nB && numA !== numB)
                return numB - numA;
            const titleA = a.title || "", titleB = b.title || "";
            const gA = !titleA || titleA === "Глава " + numA || titleA === "Chapter " + numA;
            const gB = !titleB || titleB === "Глава " + numB || titleB === "Chapter " + numB;
            if (!gA && gB)
                return -1;
            if (gA && !gB)
                return 1;
            if (a.publish_date && b.publish_date)
                return new Date(b.publish_date) - new Date(a.publish_date);
            return 0;
        }).map((ch, i, arr) => {
            const isAttachment = i > 0 && arr[i - 1].chapter === ch.chapter && arr[i - 1].volume === ch.volume && ch.chapter !== "";
            return {
                id: ch.id,
                title: ch.title,
                chapter: ch.chapter,
                volume: ch.volume,
                pages: ch.pages,
                publish_date: ch.publish_date,
                isAttachment: isAttachment
            };
        });
    }

    // Generic script runner that parses JSON and calls onJson
    Component {
        id: _runScript
        Process {
            property var onJson: null
            stdout: StdioCollector {
                onStreamFinished: {
                    if (onJson) {
                        try {
                            onJson(JSON.parse(text));
                        } catch (e) {
                            root.progressStatus = "error";
                            Notifications.notify({
                                summary: "Error",
                                body: String(e)
                            });
                        }
                    } else {
                        root.progressStatus = "error";
                        Notifications.notify({
                            summary: "Error",
                            body: "Manga script returned no handler"
                        });
                    }
                }
            }
            onExited: function (code) {
                if (code !== 0) {
                    root.progressStatus = "error";
                    Notifications.notify({
                        summary: "Error",
                        body: "manga.py exited with code " + code
                    });
                }
            }
        }
    }

    // ===== UI (ColumnLayout: children size via Layout.*, no fragile
    // parent.height - N math; the content rect takes leftover space) =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Content area (fills leftover space)
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            // ===== MANGA TAB =====
            SmoothFlickable {
                id: mangaFlick
                anchors.fill: parent
                visible: root.currentTab === "Manga"
                clip: true
                contentWidth: mangaFlick.width
                contentHeight: mangaCol.implicitHeight
                ScrollBar.vertical: ScrollBar {}

                Column {
                    id: mangaCol
                    width: mangaFlick.width
                    spacing: 10

                    // Progress
                    AppProgress {
                        width: parent.width
                        // Plain Column ignores implicitHeight — bind it explicitly.
                        height: implicitHeight
                        status: root.progressStatus
                        variant: "inline"
                        loadingText: "Loading..."
                        idleText: root.mangaList.length === 0 ? "No manga found" : ""
                        showIdle: true
                    }

                    Repeater {
                        model: root.mangaList
                        delegate: Rectangle {
                            width: mangaCol.width
                            // Grows with content (cover + 3 labels), not a
                            // fixed 210px that tall covers would overflow.
                            implicitHeight: mangaCardCol.implicitHeight + 20
                            color: Theme.surface
                            radius: 8
                            clip: true

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedManga = modelData;
                                    root.fetchChapters(modelData.id);
                                }
                                cursorShape: Qt.PointingHandCursor
                            }

                            Column {
                                id: mangaCardCol
                                anchors.fill: parent
                                spacing: 6
                                anchors.margins: 10

                                AppImage {
                                    width: parent.width
                                    // Aspect-aware height: (h/w) * panelWidth, fallback panelWidth
                                    height: (modelData.cover_width && modelData.cover_height) ? (modelData.cover_height / modelData.cover_width) * width : Settings.leftPanelWidth
                                    source: root.toFileUrl(modelData.cover_path)
                                    sourceWidth: Math.round(width)

                                    clip: true
                                }

                                Label {
                                    text: modelData.title
                                    font.pixelSize: Theme.fontSize + 1
                                    font.bold: true
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Label {
                                    text: modelData.description ? modelData.description.substring(0, 100) + "..." : "No description"
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.fgDim
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: "Tags: " + (modelData.tags ? modelData.tags.slice(0, 3).join(", ") : "N/A")
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.accent
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            // ===== CHAPTERS TAB =====
            SmoothFlickable {
                id: chapFlick
                anchors.fill: parent
                visible: root.currentTab === "Chapters"
                clip: true
                contentWidth: chapFlick.width
                contentHeight: chapCol.implicitHeight
                ScrollBar.vertical: ScrollBar {}

                Column {
                    id: chapCol
                    width: chapFlick.width
                    spacing: 6

                    Label {
                        width: parent.width
                        text: root.selectedManga ? "Chapters for: " + root.selectedManga.title : "Chapters"
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        color: Theme.fg
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.chapters
                        delegate: Rectangle {
                            width: chapCol.width
                            implicitHeight: 36
                            color: Theme.bg
                            radius: 6

                            AppButton {
                                anchors.fill: parent
                                anchors.leftMargin: modelData.isAttachment ? 25 : 0
                                text: root.formatChapterLabel(modelData, modelData.isAttachment)
                                onClicked: {
                                    root.selectedChapter = modelData;
                                    root.fetchPages(modelData.id);
                                }
                            }
                        }
                    }
                }
            }

            // ===== PAGES TAB (ColumnLayout: reader takes leftover space) =====
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentTab === "Pages"
                spacing: 8

                SmoothFlickable {
                    id: pagesFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: pagesFlickable.width
                    contentHeight: Math.max(pageImg.height, height)
                    ScrollBar.vertical: ScrollBar {}
                    Component.onCompleted: root.mainFlickable = pagesFlickable

                    AppImage {
                        id: pageImg
                        width: pagesFlickable.width
                        height: {
                            const p = root.pageCache[root.currentPageIndex];
                            if (p?.width > 0 && p?.height > 0)
                                return width * p.height / p.width;
                            if (implicitImageWidth > 0 && implicitImageHeight > 0)
                                return width * implicitImageHeight / implicitImageWidth;
                            return 0;
                        }
                        source: root.toFileUrl(root.pageCache[root.currentPageIndex]?.path)
                        sourceWidth: Math.round(width)
                        fillMode: Image.PreserveAspectFit
                        animated: true
                        clip: true
                    }

                    AppProgress {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.pageCache[root.currentPageIndex]?.path ? pageImg.height + 8 : 0
                        width: implicitWidth
                        height: implicitHeight
                        status: root.progressStatus
                        variant: "inline"
                        loadingText: "Loading page..."
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    AppButton {
                        Layout.fillWidth: true
                        text: "\u25C0 Previous Page"
                        enabled: root.currentPageIndex > 0
                        onClicked: root.navigatePage("prev")
                    }
                    AppButton {
                        Layout.fillWidth: true
                        text: "Next Page \u25B6"
                        enabled: root.pages.length > 0 && root.currentPageIndex < root.pages.length - 1
                        onClicked: root.navigatePage("next")
                    }
                }

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pages.length > 0 ? "Page " + (root.currentPageIndex + 1) + " / " + root.pages.length : "No pages"
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
            }
        }

        // ===== Bottom action bar (actions / page + chapter navigation / URL bar / sections / tabs) =====

        // Reveal button
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            AppButton {
                Layout.fillWidth: true
                text: root.bottomRevealed ? "\u{F07E}" : "\u{F07C}"
                onClicked: root.bottomRevealed = !root.bottomRevealed
            }
        }

        // Revealable search actions
        Column {
            Layout.fillWidth: true
            spacing: 8
            visible: root.bottomRevealed
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
            opacity: root.bottomRevealed ? 1 : 0

            AppTextField {
                width: parent.width
                placeholderText: "Search manga..."
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
                onAccepted: root.searchManga(text)
            }
            RowLayout {
                width: parent.width
                spacing: 8
                AppButton {
                    Layout.fillWidth: true
                    text: "\u{F0580} Search"
                    onClicked: root.searchManga(root.searchQuery)
                }
                AppButton {
                    Layout.fillWidth: true
                    text: "\u{F0580} Popular"
                    onClicked: root.fetchPopular()
                }
            }
        }

        // Chapter navigation — always visible
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            AppButton {
                Layout.fillWidth: true
                text: "\u25C0 Previous Chapter"
                enabled: (root.selectedChapter !== null) && (root.selectedChapter !== undefined)
                onClicked: root.goToChapter("prev")
            }
            AppButton {
                Layout.fillWidth: true
                text: "Next Chapter \u25B6"
                enabled: (root.selectedChapter !== null) && (root.selectedChapter !== undefined)
                onClicked: root.goToChapter("next")
            }
        }
        Label {
            Layout.fillWidth: true
            // Show "No chapter selected" (grayed) when nothing is chosen
            opacity: (root.selectedChapter !== null && root.selectedChapter !== undefined) ? 1 : 0.4
            text: {
                const ch = root.selectedChapter;
                if (!ch)
                    return "<b>No chapter selected</b>";
                const vol = ch.volume ? "Vol. " + ch.volume + " " : "";
                const num = ch.chapter || "?";
                const title = (ch.title || "").trim();
                if (!title || title === "Chapter " + num || title === "Volume " + num)
                    return "<b>" + vol + "Chapter " + num + "</b>";
                return "<b>" + vol + "Chapter " + num + ": " + title + "</b>";
            }
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        // URL bar — visible complexity low, always rendered
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: Theme.bg
                radius: 4

                Label {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.getUrl()
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
            AppButton {
                text: "\u{F07B7} Copy"
                onClicked: {
                    const url = root.getUrl();
                    console.log("[Manga] copy url:", url);
                    Quickshell.execDetached(["bash", "-c", "echo -n '" + url + "' | wl-copy 2>/dev/null || echo -n '" + url + "' | xclip -selection clipboard"]);
                }
            }
        }

        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            Layout.fillWidth: true
            spacing: 4
            AppSegmentedControl {
                // Per-tab availability rides in the model (Chapters needs a
                // manga, Pages a chapter) — disabled cells don't activate.
                model: [
                    {
                        value: "Manga",
                        label: "Manga",
                        enabled: true
                    },
                    {
                        value: "Chapters",
                        label: "Chapters",
                        enabled: (root.selectedManga !== null) && (root.selectedManga !== undefined)
                    },
                    {
                        value: "Pages",
                        label: "Pages",
                        enabled: (root.selectedChapter !== null) && (root.selectedChapter !== undefined)
                    }
                ]
                currentIndex: ["Manga", "Chapters", "Pages"].indexOf(root.currentTab)
                onActivated: (i, v) => root.currentTab = v
            }
        }

        // Provider tabs
        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            Layout.fillWidth: true
            spacing: 4
            AppSegmentedControl {
                Layout.alignment: Qt.AlignHCenter
                model: root.providers.map(p => ({
                            value: p.id,
                            label: p.label
                        }))
                currentIndex: root.providers.findIndex(p => p.id === root.provider)
                onActivated: (i, v) => root.switchProvider(v)
            }
        }

        // Keyboard navigation (Left/Right page, Up/Down reveal)
        // NOTE: Item lives OUTSIDE the ColumnLayout above (positioners ignore
        // anchors, which would collapse it to 0x0) — anchored to root instead.
    }
    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: {
            if (root.currentTab === "Pages") {
                root.navigatePage("prev");
                event.accepted = true;
            }
        }
        Keys.onRightPressed: {
            if (root.currentTab === "Pages") {
                root.navigatePage("next");
                event.accepted = true;
            }
        }
        Keys.onUpPressed: {
            if (!root.bottomRevealed) {
                root.bottomRevealed = true;
                event.accepted = true;
            }
        }
        Keys.onDownPressed: {
            if (root.bottomRevealed) {
                root.bottomRevealed = false;
                event.accepted = true;
            }
        }
    }
}
