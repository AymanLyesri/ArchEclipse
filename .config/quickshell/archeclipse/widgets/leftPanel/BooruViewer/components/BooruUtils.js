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
    return img.preview ? img.preview : "file://" + getIconPath(booruPath, img, "previews")
}

function gridSource(booruPath, downloadedIds, previewIds, img) {
    if (!img) return ""
    if (isDownloadedIn(downloadedIds, img))
        return "file://" + getIconPath(booruPath, img, "images")
    if (img && previewIds[String(img.id)])
        return "file://" + getIconPath(booruPath, img, "previews")
    return img.preview ? img.preview : "file://" + getIconPath(booruPath, img, "previews")
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
