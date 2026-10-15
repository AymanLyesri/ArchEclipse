// BooruUtils.js — pure helpers extracted from BooruViewerWidget.qml.
// No QML imports, no singleton access: everything arrives via arguments.
.pragma library

function apiOf(img) { return (img && img.api && img.api.value) || "" }

// Disk-cache / reveal maps must be keyed by api+id: Safebooru and
// Danbooru share numeric post ids, and files live under separate
// <api>/ trees. Plain id keys made one site steal the other's "cached"
// flag and point Image at a missing path.
function cacheKey(img) {
    if (!img) return ""
    const api = apiOf(img) || "danbooru"
    return api + ":" + String(img.id)
}

function isInArray(arr, img) {
    if (!img) return false
    // getBookmarkKey: id + api match (same id can exist per API)
    return (arr || []).some(function (x) {
        return x && String(x.id) === String(img.id) && apiOf(x) === apiOf(img)
    })
}

// Preview files are always still images (JPEG/PNG), even when the post
// itself is mp4/webm. Prefer the extension from the preview URL; fall
// back to jpg for video posts so Qt Image can decode the cache file.
function previewExt(img) {
    const preview = (img && img.preview) || ""
    const m = String(preview).match(/\.([a-z0-9]+)(?:\?|#|$)/i)
    if (m) {
        const e = m[1].toLowerCase()
        if (e === "jpeg") return "jpg"
        if (["jpg", "png", "webp", "gif"].indexOf(e) >= 0) return e
    }
    const ext = ((img && img.extension) || "jpg").toLowerCase()
    if (["mp4", "webm", "mkv", "zip"].indexOf(ext) >= 0) return "jpg"
    return ext || "jpg"
}

function getIconPath(booruPath, img, which) {
    const api = (img && img.api && img.api.value) || "danbooru"
    if (which === "previews")
        return booruPath + "/" + api + "/" + which + "/" + img.id + "." + previewExt(img)
    if (which === "images" && hasSampleVideo(img))
        return booruPath + "/" + api + "/" + which + "/" + img.id + "." + sampleExt(img)
    return booruPath + "/" + api + "/" + which + "/" + img.id + "." + ((img && img.extension) || "png")
}

// Ugoira (zip) posts cannot be decoded by Qt, but Danbooru/Safebooru
// ship a transcoded sample video (booru.py "sample"); the viewer
// downloads and plays that instead, stored next to the full files.
function hasSampleVideo(img) {
    return ((img && img.extension) || "").toLowerCase() === "zip" && !!(img && img.sample)
}

// Extension for the transcoded sample file, derived from its URL
// (webm/mp4), never from the post's own "zip" extension.
function sampleExt(img) {
    const s = (img && img.sample) || ""
    const m = String(s).match(/\.([a-z0-9]+)(?:\?|#|$)/i)
    if (m) {
        const e = m[1].toLowerCase()
        if (["webm", "mp4"].indexOf(e) >= 0)
            return e
    }
    return "webm"
}

function isDownloadedIn(downloadedIds, img) {
    return !!img && !!downloadedIds[cacheKey(img)]
}

function imageFileUrl(booruPath, downloadedIds, img) {
    if (!img) return ""
    if (isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    return img.url ? img.url : (img.preview ? img.preview : "file://" + getIconPath(booruPath, img, "previews"))
}

function dialogSource(booruPath, downloadedIds, fullIds, previewIds, img) {
    if (!img) return ""
    const key = cacheKey(img)
    if (isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    // Dialog auto-downloads the full file into <api>/images/ on open.
    // Remote danbooru URLs 403 inside Qt (browser UA, no Referer), so
    // there is no remote fallback — fetchOriginal() downloads it first.
    // The originals path below is legacy compat only.
    if (img && fullIds[key])
        return "file://" + getIconPath(booruPath, img, "images")
    // Local files (e.g. custom waifu uploads) play directly — nothing
    // to fetch, so hand the path to Qt instead of spinning forever.
    if (img && img.url && !/^https?:\/\//.test(img.url))
        return img.url.indexOf("file://") === 0 ? img.url : "file://" + img.url
    // While the full file downloads, show the cached preview still
    // (a JPEG even for video posts) instead of a blank spinner card.
    if (img && previewIds && previewIds[key])
        return "file://" + getIconPath(booruPath, img, "previews")
    return ""
}

function gridSource(booruPath, downloadedIds, previewIds, img) {
    if (!img) return ""
    // Videos (mp4/webm/mkv) cannot be decoded by Qt's Image element — the
    // grid card is a plain AppImage (no AnimatedImage/MediaVideo branch
    // like the dialog has). The preview file is a JPEG still (Danbooru
    // variant URL) despite the video extension, so always prefer it over
    // the downloaded full file; otherwise the card flips to a real video
    // file the moment fetchOriginal() marks it downloaded and goes blank.
    // GIFs are excluded: Image renders their first frame, so the full
    // file still shows (static) instead of blanking.
    const ext = ((img && img.extension) || "").toLowerCase()
    // Ugoira with a transcoded sample downloads as webm, which Image
    // cannot decode either — same rule: the preview still stands in.
    const isUnrenderableVideo = ["mp4", "webm", "mkv"].includes(ext) || hasSampleVideo(img)
    if (!isUnrenderableVideo && isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    if (img && previewIds[cacheKey(img)])
        return "file://" + getIconPath(booruPath, img, "previews")
    // No remote fallback: Qt's TLS backend segfaults in libcrypto
    // (OSSL_DECODER path) on cdn.donmai.us handshakes, and Qt gets
    // 403 there anyway (no Referer). downloadPreviews() fetches via
    // headered curl first; the grid repaints blank until cached.
    return ""
}

// Drop map entries for one API after cleanCache (other APIs stay warm).
function purgeApiKeys(map, apiValue) {
    const next = {}
    const prefix = String(apiValue || "") + ":"
    for (const k in (map || {})) {
        if (Object.prototype.hasOwnProperty.call(map, k) && String(k).indexOf(prefix) !== 0)
            next[k] = map[k]
    }
    return next
}

function clonify(img, currentApiObj) {
    return {
        id: img.id,
        width: img.width,
        height: img.height,
        tags: img.tags || [],
        url: img.url,
        preview: img.preview,
        extension: img.extension,
        sample: img.sample || null,
        api: img.api || currentApiObj
    }
}

function buildPageButtons(widgetWidth, page) {
    var buttons = []
    var totalPagesToShow = Math.floor(widgetWidth / 100) + 2
    var current = page
    if (current > 3) {
        buttons.push({ label: "1", page: 1, active: false })
        buttons.push({ label: "...", page: -1, active: false })
    }
    var startPage = Math.max(1, current - Math.floor(totalPagesToShow / 2))
    var endPage = startPage + totalPagesToShow - 1
    if (endPage - startPage + 1 < totalPagesToShow) endPage = startPage + totalPagesToShow - 1
    for (var p = startPage; p <= endPage; p++) {
        buttons.push({ label: p === current ? "\u{F021}" : String(p), page: p, active: p === current })
    }
    return buttons
}

function pagedSlice(list, limit, page) {
    if (!(limit > 0)) return list
    var startIndex = (Math.max(1, page) - 1) * limit
    return list.slice(startIndex, startIndex + limit)
}
