// BooruUtils.js — pure helpers extracted from BooruViewerWidget.qml.
// No QML imports, no singleton access: everything arrives via arguments.
.pragma library

function apiOf(img) { return (img && img.api && img.api.value) || "" }

function isInArray(arr, img) {
    if (!img) return false
    // getBookmarkKey: id + api match (same id can exist per API)
    return (arr || []).some(function (x) {
        return x && String(x.id) === String(img.id) && apiOf(x) === apiOf(img)
    })
}

function getIconPath(booruPath, img, which) {
    const api = (img && img.api && img.api.value) || "danbooru"
    return booruPath + "/" + api + "/" + which + "/" + img.id + "." + (img.extension || "png")
}

function isDownloadedIn(downloadedIds, img) {
    return !!img && !!downloadedIds[String(img.id)]
}

function imageFileUrl(booruPath, downloadedIds, img) {
    if (!img) return ""
    if (isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    return img.url ? img.url : (img.preview ? img.preview : "file://" + getIconPath(booruPath, img, "previews"))
}

function dialogSource(booruPath, downloadedIds, fullIds, previewIds, img) {
    if (!img) return ""
    if (isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    // Dialog auto-downloads the full file into <api>/images/ on open.
    // Remote danbooru URLs 403 inside Qt (browser UA, no Referer), so
    // there is no remote fallback — fetchOriginal() downloads it first.
    // The originals path below is legacy compat only.
    if (img && fullIds[String(img.id)])
        return "file://" + getIconPath(booruPath, img, "images")
    // Local files (e.g. custom waifu uploads) play directly — nothing
    // to fetch, so hand the path to Qt instead of spinning forever.
    if (img && img.url && !/^https?:\/\//.test(img.url))
        return img.url.indexOf("file://") === 0 ? img.url : "file://" + img.url
    // While the full file downloads, show the cached preview still
    // (a JPEG even for video posts) instead of a blank spinner card.
    if (img && previewIds && previewIds[String(img.id)])
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
    const isUnrenderableVideo = ["mp4", "webm", "mkv"].includes(ext)
    if (!isUnrenderableVideo && isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    if (img && previewIds[String(img.id)])
        return "file://" + getIconPath(booruPath, img, "previews")
    // No remote fallback: Qt's TLS backend segfaults in libcrypto
    // (OSSL_DECODER path) on cdn.donmai.us handshakes, and Qt gets
    // 403 there anyway (no Referer). downloadPreviews() fetches via
    // headered curl first; the grid repaints blank until cached.
    return ""
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
