pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

// Shared booru post actions used by both the BooruViewer dialog and the
// WaifuWidget overlay. Single source of truth so bookmark/pin/waifu/
// browser/copy behave identically everywhere.
QtObject {
    id: root

    readonly property string booruBase: Quickshell.env("HOME") + "/.cache/quickshell/booru"
    readonly property string booruScript: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/booru.py"

    readonly property var booruApis: [
        { name: "Danbooru", value: "danbooru", url: "https://danbooru.donmai.us/", idSearchUrl: "https://danbooru.donmai.us/posts/" },
        { name: "Gelbooru", value: "gelbooru", url: "https://gelbooru.com/", idSearchUrl: "https://gelbooru.com/index.php?page=post&s=view&id=" },
        { name: "Safebooru", value: "safebooru", url: "https://safebooru.donmai.us/", idSearchUrl: "https://safebooru.donmai.us/posts/" }
    ]

    function apiOf(img) {
        return (img && img.api && img.api.value) || "";
    }

    function apiByValue(value) {
        return root.booruApis.find(a => a.value === value) || root.booruApis[0];
    }

    function isVideo(img) {
        if (!img)
            return false;
        return ["mp4", "webm", "mkv", "gif"].includes(((img.extension) || "").toLowerCase());
    }

    function isZip(img) {
        return ((img && img.extension) || "").toLowerCase() === "zip";
    }

    function isInArray(arr, img) {
        if (!img)
            return false;
        return (arr || []).some(x => x && String(x.id) === String(img.id) && root.apiOf(x) === root.apiOf(img));
    }

    function isBookmarked(img) {
        return root.isInArray((Settings.booru || {}).bookmarks, img);
    }

    function isPinned(img) {
        return root.isInArray((Settings.booru || {}).pins, img);
    }

    function isCurrentWaifu(img) {
        if (!img)
            return false;
        const w = Settings.waifu;
        return !!(w && String(w.id) === String(img.id));
    }

    function touchBooru() {
        // Nested assigns don't emit on their own — reassign a fresh clone.
        try {
            Settings.booru = Object.assign({}, Settings.booru);
        } catch (e) {}
    }

    // Bookmark via booru.py (validates payload, syncs shared settings.json).
    // after(bookmarked: bool) runs once Settings has been updated.
    function toggleBookmark(img, after) {
        if (!img || typeof img.id !== "number" || !root.apiOf(img)) {
            Notifications.notify({ summary: "Error updating bookmark", body: "Invalid image data." });
            return;
        }
        Settings.persist();
        const payload = JSON.stringify({ bookmark: img });
        const cmd = ["python", root.booruScript, "--action", "toggle-bookmark", "--payload-json", payload];
        const p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', p);
        p.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', p);
        p.command = cmd;
        p.exited.connect(function (code) {
            const out = p.stdout ? p.stdout.text : "";
            p.destroy();
            root._onBookmarkToggled(code === 0, out, after);
        });
        p.running = true;
    }

    function _onBookmarkToggled(exitOk, stdoutText, after) {
        if (!exitOk) {
            Notifications.notify({ summary: "Error updating bookmark", body: "Bookmark script failed." });
            return;
        }
        try {
            const parsed = JSON.parse((stdoutText || "").trim());
            const marked = parsed.bookmarked === true;
            if (Array.isArray(parsed.bookmarks)) {
                Settings.booru.bookmarks = parsed.bookmarks;
                root.touchBooru();
            } else {
                Settings.reload();
            }
            Notifications.notify({ summary: "Success", body: marked ? "Image bookmarked" : "Bookmark removed" });
            if (after)
                after(marked);
        } catch (e) {
            Settings.reload();
            Notifications.notify({ summary: "Error updating bookmark", body: "Invalid bookmark response." });
        }
    }

    // Pin/unpin for the fastfetch terminal sync. after(pinned: bool) optional.
    function togglePinned(img, after) {
        if (!img)
            return false;
        if (root.isVideo(img) || root.isZip(img)) {
            Notifications.notify({ summary: "Error pinning to terminal", body: "Cannot pin videos to terminal" });
            return false;
        }
        const arr = ((Settings.booru || {}).pins || []).slice();
        const i = arr.findIndex(x => x && String(x.id) === String(img.id) && root.apiOf(x) === root.apiOf(img));
        if (i >= 0) {
            arr.splice(i, 1);
            Settings.booru.pins = arr;
            root.touchBooru();
            Settings.schedulePersist();
            FastfetchPins.scheduleSync();
            Notifications.notify({ summary: "Waifu", body: "UN-Pinned from Terminal" });
            if (after)
                after(false);
            return false;
        }
        arr.push(img);
        Settings.booru.pins = arr;
        root.touchBooru();
        Settings.schedulePersist();
        FastfetchPins.scheduleSync();
        Notifications.notify({ summary: "Waifu", body: "Pinned To Terminal" });
        if (after)
            after(true);
        return true;
    }

    function setAsWaifu(img) {
        if (!img)
            return;
        Settings.waifu = img;
        Settings.schedulePersist();
        Notifications.notify({ summary: "Waifu", body: "Waifu updated" });
    }

    function openInBrowser(img) {
        if (!img)
            return;
        const base = (img.api && img.api.idSearchUrl) || "https://danbooru.donmai.us/posts/";
        Quickshell.execDetached(["xdg-open", base + img.id]);
    }

    // Local full-image path for a post (<api>/images/<id>.<ext>).
    function localImagePath(img) {
        if (!img || img.id === undefined || img.id === null)
            return "";
        const api = root.apiOf(img) || "danbooru";
        const ext = img.extension || "jpg";
        return `${root.booruBase}/${api}/images/${img.id}.${ext}`;
    }

    // Open the downloaded file in an external viewer (swayimg for images,
    // mpv for videos).
    function openInViewer(img) {
        if (!img)
            return;
        if (root.isZip(img)) {
            Notifications.notify({ summary: "Cannot open", body: "This file type cannot be previewed" });
            return;
        }
        const path = root.localImagePath(img);
        if (path === "")
            return;
        if (root.isVideo(img))
            Quickshell.execDetached(["mpv", "--force-window=immediate", "--no-terminal", `--title=${img.id}`, path]);
        else
            Quickshell.execDetached(["swayimg", "-w", "690,690", "--class", "preview-image", path]);
    }

    // Copy the downloaded full image into ~/.config/wallpapers/custom so
    // the Wallpaper switcher can apply it (previews render the original
    // file natively). after(saved: bool) optional.
    // Requires the full file on disk — the BooruViewer dialog
    // auto-downloads it on open, so by button-press time it is there;
    // exit 3 (test -s failed) tells the user to wait for the download.
    function saveAsWallpaper(img, after) {
        if (!img || img.id === undefined || img.id === null)
            return;
        if (root.isZip(img)) {
            Notifications.notify({ summary: "Cannot use as wallpaper", body: "This file type cannot be previewed" });
            if (after)
                after(false);
            return;
        }
        const src = root.localImagePath(img);
        if (src === "") {
            if (after)
                after(false);
            return;
        }
        const ext = String(img.extension || "jpg").toLowerCase();
        const api = root.apiOf(img) || "danbooru";
        const basename = `booru-${api}-${img.id}.${ext}`;
        const home = Quickshell.env("HOME");
        const targetDir = home + "/.config/wallpapers/custom";
        const targetPath = targetDir + "/" + basename;
        const script = `test -s ${JSON.stringify(src)} || exit 3; ` + `mkdir -p ${JSON.stringify(targetDir)} && ` + `cp -- ${JSON.stringify(src)} ${JSON.stringify(targetPath)}`;
        const p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', p);
        p.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', p);
        p.command = ["bash", "-c", script];
        p.exited.connect(function (code) {
            p.destroy();
            if (code === 3) {
                Notifications.notify({ summary: "Full image not downloaded yet", body: "Wait for the download, then try again" });
                if (after)
                    after(false);
            } else if (code === 0) {
                Notifications.notify({ summary: "Success", body: "Saved to wallpapers/custom — pick it in the Wallpaper switcher" });
                if (after)
                    after(true);
            } else {
                Notifications.notify({ summary: "Error", body: "Could not save to wallpapers folder" });
                if (after)
                    after(false);
            }
        });
        p.running = true;
    }

    function copyTag(tag) {
        if (tag === undefined || tag === null)
            return;
        // Fixed-string copy: no shell interpolation of the tag value.
        const p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = ["bash", "-c", "wl-copy -- \"$1\"", "--", String(tag)];
        p.exited.connect(function () { p.destroy(); });
        p.running = true;
    }

    // Fetch a single post by ID. onDone(img|null, errorString).
    function fetchPostById(apiValue, id, onDone) {
        const api = root.apiByValue(apiValue);
        let cmd = ["python", root.booruScript, "--api", api.value, "--id", String(id)];
        const apiUser = Settings.apiKey(api.value, "user");
        const apiPass = Settings.apiKey(api.value, "key");
        if (apiUser !== "" && apiPass !== "")
            cmd.push("--api-user", apiUser, "--api-key", apiPass);
        const p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', p);
        p.stderr = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', p);
        p.command = cmd;
        p.exited.connect(function (code) {
            const text = p.stdout ? p.stdout.text : "";
            const errText = p.stderr ? p.stderr.text : "";
            p.destroy();
            let parsed = null;
            try {
                parsed = text && text.trim() ? JSON.parse(text) : null;
            } catch (e) {
                parsed = null;
            }
            if (parsed && parsed.error === true) {
                if (onDone)
                    onDone(null, String(parsed.message || "Unknown booru error"));
                return;
            }
            if (Array.isArray(parsed) && parsed.length > 0) {
                const raw = parsed[0];
                if (onDone)
                    onDone({
                        id: raw.id || 0,
                        width: raw.width || 0,
                        height: raw.height || 0,
                        api: api,
                        tags: raw.tags || [],
                        extension: raw.extension,
                        url: raw.url,
                        preview: raw.preview,
                        sample: raw.sample || null
                    }, "");
                return;
            }
            const detail = (errText && errText.trim()) || "Post not found";
            if (onDone)
                onDone(null, detail.slice(0, 300));
        });
        p.running = true;
    }
}
