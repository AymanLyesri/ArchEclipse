// BooruUtils.js — pure helpers extracted from BooruViewerWidget.qml.
// No QML imports, no singleton access: everything arrives via arguments.
.pragma library

function apiOf(img) { return (img && img.api && img.api.value) || "" }

// Cache/reveal maps are keyed by api+id: Safebooru and Danbooru share numeric ids, so plain id
// keys made one site steal the other's "cached" flag and point Image at a missing path.
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

// Preview files are always still images (JPEG/PNG) even for mp4/webm posts, so prefer the preview
// URL's extension and fall back to jpg for videos — Qt Image must decode the cache file.
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

// Ugoira (zip) cannot be decoded by Qt, but Danbooru/Safebooru ship a transcoded sample video,
// which the viewer downloads and plays instead, stored next to the full files.
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
    // Remote danbooru URLs 403 inside Qt (browser UA, no Referer), so there is no remote fallback:
    // fetchOriginal() downloads the file first. The originals path is legacy compat only.
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
    // Qt's Image cannot decode video files and the grid card is a plain AppImage, so videos always
    // prefer the JPEG still preview — otherwise the card went blank once the full file landed.
    const ext = ((img && img.extension) || "").toLowerCase()
    // Ugoira with a transcoded sample downloads as webm, which Image
    // cannot decode either — same rule: the preview still stands in.
    const isUnrenderableVideo = ["mp4", "webm", "mkv"].includes(ext) || hasSampleVideo(img)
    if (!isUnrenderableVideo && isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    if (img && previewIds[cacheKey(img)])
        return "file://" + getIconPath(booruPath, img, "previews")
    // No remote fallback: Qt's TLS backend segfaults on cdn.donmai.us handshakes (and gets 403
    // without a Referer), so downloadPreviews() fetches via headered curl and the grid blanks until cached.
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

function buildPageButtons(widgetWidth, page, currentIcon) {
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
        buttons.push({ label: p === current ? currentIcon : String(p), page: p, active: p === current })
    }
    return buttons
}

function pagedSlice(list, limit, page) {
    if (!(limit > 0)) return list
    var startIndex = (Math.max(1, page) - 1) * limit
    return list.slice(startIndex, startIndex + limit)
}
