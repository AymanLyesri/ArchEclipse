import QtQuick
import qs.theme

// WaveVisualizer — port of END-4 ii modules/common/widgets/WaveVisualizer.qml
// Draws a smooth audio-spectrum waveform from `points` (raw cava values).
// Used as an overlay on the player widget when audio is playing.
Canvas {
    id: root

    property var points: []
    property int maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: Theme.accent

    onPointsChanged: root.requestPaint()

    function smooth(points, window) {
        const n = points.length
        if (n < 2) return points
        const out = []
        for (let i = 0; i < n; ++i) {
            let sum = 0, count = 0
            for (let j = -window; j <= window; ++j) {
                const idx = Math.max(0, Math.min(n - 1, i + j))
                sum += points[idx]
                count++
            }
            out.push(sum / count)
        }
        return out
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        const src = root.points || []
        const n = src.length
        if (n < 2) return

        const maxVal = root.maxVisualizerValue || 1
        const h = height
        const w = width
        const smoothPts = root.smooth(src, root.smoothing)

        ctx.beginPath()
        ctx.moveTo(0, h)
        for (let i = 0; i < n; ++i) {
            const x = i * w / (n - 1)
            const y = root.live ? h - (smoothPts[i] / maxVal) * h : h
            ctx.lineTo(x, y)
        }
        ctx.lineTo(w, h)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.15)
        ctx.fill()
    }
}
