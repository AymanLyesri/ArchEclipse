import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme

// Crypto entry item — port of widgets/Crypto.tsx + CryptoViewer.tsx CryptoEntryItem.
// Fetches crypto price data via crypto.py, displays symbol, price, change %,
// and a Unicode bar chart graph (▁▂▃▄▅▆▇█).
Item {
    id: root
    property var entry: {}
    property int itemWidth: parent ? parent.width : 200

    readonly property string cryptoScript: `${Quickshell.env("HOME")}/.config/ags/scripts/crypto.py`
    readonly property var barChars: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    property var prices: []
    property double currentPrice: 0
    property string loadingState: "loading"  // "loading" | "error" | "success"
    property double priceChange: 0
    property double priceChangePercent: 0

    // Computed graph string from prices
    readonly property string graph: {
        const prices = root.prices
        const maxPoints = Math.floor(root.itemWidth / 10)
        if (prices.length === 0) return root.barChars[0].repeat(maxPoints)

        const recent = prices.slice(-maxPoints)
        const padded = []
        const padCount = maxPoints - recent.length
        for (let i = 0; i < padCount; i++) padded.push(recent[0] || 0)
        const all = padded.concat(recent)

        const sorted = all.slice().sort((a, b) => a - b)
        return all.map(p => {
            const rank = sorted.filter(x => x <= p).length
            const percentile = rank / sorted.length
            const barIndex = Math.min(7, Math.floor(percentile * 8))
            return root.barChars[barIndex]
        }).join("")
    }

    // Trend color
    readonly property string trendColor: root.prices.length < 2
        ? ""
        : root.prices[root.prices.length - 1] >= root.prices[0] ? "up" : "down"

    // Format price
    readonly property string formattedPrice: root.currentPrice === 0
        ? "Loading..."
        : "$" + root.currentPrice.toLocaleString("en-US", {
            minimumFractionDigits: 2, maximumFractionDigits: 2
          })

    // Format change
    readonly property string formattedChange: {
        const sign = root.priceChange >= 0 ? "+" : ""
        return sign + root.priceChange.toFixed(2) + " (" + sign + root.priceChangePercent.toFixed(2) + "%)"
    }

    // Fetch crypto data
    function fetchCrypto() {
        if (!root.entry || !root.entry.symbol) return

        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["python", "' + root.cryptoScript + '", "' + root.entry.symbol + '", "' + root.entry.timeframe + '"] }',
            root
        )
        proc.running = true
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        proc.stdout.onStreamFinished.connect(function() {
            const text = proc.stdout.text
            try {
                if (text && text.trim() !== "") {
                    const parsed = JSON.parse(text)
                    if (parsed.prices && Array.isArray(parsed.prices)) {
                        const fetchedPrices = parsed.prices.map(p => p.price)
                        root.prices = fetchedPrices
                        root.currentPrice = fetchedPrices.length > 0 ? fetchedPrices[fetchedPrices.length - 1] : 0

                        if (fetchedPrices.length >= 2) {
                            const first = fetchedPrices[0]
                            const last = fetchedPrices[fetchedPrices.length - 1]
                            root.priceChange = last - first
                            root.priceChangePercent = (root.priceChange / first) * 100
                        }
                        root.loadingState = "success"
                    } else {
                        root.loadingState = "error"
                    }
                } else {
                    root.loadingState = "error"
                }
            } catch (e) {
                root.loadingState = "error"
            }
            proc.destroy()
        })
    }

    // Poll every 5 minutes (like AGS POLL_INTERVAL = 300000)
    Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: root.fetchCrypto()
    }

    // Initial fetch
    Component.onCompleted: {
        fetchCrypto()
    }

    Column {
        anchors.fill: parent
        spacing: 4

        // Entry header: symbol, price, change
        Row {
            id: headerRow
            spacing: 8
            width: parent.width

            // Symbol
            Label {
                text: (root.entry.symbol || "btc").toUpperCase()
                font.pixelSize: Theme.fontSize
                color: root.trendColor === "up" ? "#4ade80" : root.trendColor === "down" ? "#f87171" : Theme.fg
            }

            // Price
            Label {
                text: root.formattedPrice
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                visible: root.loadingState !== "loading"
                // Guarded: 0-wide item before Loader stretch must not go negative
                width: Math.max(0, parent.width - 120)
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            // Change — AGS Crypto.tsx has this COMMENTED OUT (lines 176-179).
            // We hide it to match AGS visual behavior exactly.
            /*
            Label {
                text: root.formattedChange
                font.pixelSize: Theme.fontSize - 1
                color: root.trendColor === "up" ? "#4ade80" : root.trendColor === "down" ? "#f87171" : Theme.fgDim
                visible: root.loadingState === "success" && root.prices.length >= 2
            }
            */
        }

        // Graph
        Label {
            id: graphLabel
            text: root.graph
            font.family: "Monospace"
            font.pixelSize: Theme.fontSize - 2
            color: root.trendColor === "up" ? "#4ade80" : root.trendColor === "down" ? "#f87171" : Theme.fgDim
            font.bold: true
            visible: root.entry.showGraph !== false
            width: parent.width
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignLeft
        }

        // Price bar (loading/error indicator)
        Rectangle {
            width: parent.width
            height: 4
            color: root.trendColor === "up" ? "#4ade80" : root.trendColor === "down" ? "#f87171" : Theme.fgDim
            opacity: 0.3
            visible: root.loadingState === "success"
            radius: 2
        }
    }
}
