import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme
import qs.services

// WorkspaceClientPopup — port of WorkspaceOverview.tsx workspaceClientLayout
// Shows a scaled-down tiling layout preview of a workspace's clients.
// Fetches hyprctl clients -j, builds layout tree, flattens to render model, renders.
Item {
    id: root
    property int workspaceId: 0
    property var clients: []       // parsed from hyprctl clients -j, filtered to this workspace
    property bool loading: false
    property bool ready: false

    // Flat render model: [{ class, title, x, y, w, h, depth, color }]
    property var renderModel: []

    // Compute totals for normalization
    property real totalX: 0
    property real totalY: 0
    property real totalW: root.width || 1
    property real totalH: root.height || 1

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text)
                    root.clients = all.filter(c => c.workspace && c.workspace.id === root.workspaceId && !c.floating)
                } catch (e) { root.clients = [] }
                root.ready = true
                root.loading = false
            }
        }
    }

    function fetchClients() {
        root.loading = true
        root.ready = false
        root.clients = []
        root.renderModel = []
        clientsProc.running = true
    }

    // Parse hyprland client JSON
    function parseClients(raw) {
        return raw.map(c => ({
            cls: c.class || "",
            title: c.title || "",
            pid: c.pid ?? 0,
            at: Array.isArray(c.at) ? c.at : [0, 0],
            size: Array.isArray(c.size) ? c.size : [0, 0]
        }))
    }

    // Build flat render model by recursively splitting the client list
    // Each node gets a normalized [0..1] x/y/w/h region
    function buildFlatModel(cs, x0, y0, x1, y1, depth) {
        if (cs.length === 0) return []
        if (cs.length === 1) {
            return [{
                cls: cs[0].cls, title: cs[0].title, pid: cs[0].pid ?? 0,
                x: x0, y: y0, w: x1 - x0, h: y1 - y0,
                depth: depth
            }]
        }
        // Try vertical separator
        const xs = []
        cs.forEach(c => {
            if (!xs.includes(c.at[0])) xs.push(c.at[0])
            if (!xs.includes(c.at[0] + c.size[0])) xs.push(c.at[0] + c.size[0])
        })
        xs.sort((a, b) => a - b)
        for (let i = 0; i < xs.length; i++) {
            const x = xs[i]
            const left = cs.filter(c => c.at[0] + c.size[0] <= x + 5)
            const right = cs.filter(c => c.at[0] >= x - 5)
            if (left.length > 0 && right.length > 0 && left.length + right.length === cs.length) {
                // Normalize split position to region
                const minX = Math.min(...cs.map(c => c.at[0]))
                const maxX = Math.max(...cs.map(c => c.at[0] + c.size[0]))
                const range = maxX - minX || 1
                const splitNorm = x0 + (x - minX) / range * (x1 - x0)
                return [
                    ...buildFlatModel(left, x0, y0, splitNorm, y1, depth + 1),
                    ...buildFlatModel(right, splitNorm, y0, x1, y1, depth + 1)
                ]
            }
        }
        // Try horizontal separator
        const ys = []
        cs.forEach(c => {
            if (!ys.includes(c.at[1])) ys.push(c.at[1])
            if (!ys.includes(c.at[1] + c.size[1])) ys.push(c.at[1] + c.size[1])
        })
        ys.sort((a, b) => a - b)
        for (let i = 0; i < ys.length; i++) {
            const y = ys[i]
            const top = cs.filter(c => c.at[1] + c.size[1] <= y + 5)
            const bot = cs.filter(c => c.at[1] >= y - 5)
            if (top.length > 0 && bot.length > 0 && top.length + bot.length === cs.length) {
                const minY = Math.min(...cs.map(c => c.at[1]))
                const maxY = Math.max(...cs.map(c => c.at[1] + c.size[1]))
                const range = maxY - minY || 1
                const splitNorm = y0 + (y - minY) / range * (y1 - y0)
                return [
                    ...buildFlatModel(top, x0, y0, x1, splitNorm, depth + 1),
                    ...buildFlatModel(bot, x0, splitNorm, x1, y1, depth + 1)
                ]
            }
        }
        // Fallback: biggest wins
        const sorted = [...cs].sort((a, b) => (b.size[0] * b.size[1]) - (a.size[0] * a.size[1]))
        return [{
            cls: sorted[0].cls, title: sorted[0].title, pid: sorted[0].pid ?? 0,
            x: x0, y: y0, w: x1 - x0, h: y1 - y0,
            depth: depth
        }]
    }

    // Rebuild render model when clients change
    property var parsedClients: parseClients(root.clients)
    onParsedClientsChanged: {
        if (parsedClients.length === 0) { renderModel = []; return }
        renderModel = buildFlatModel(parsedClients, 0, 0, 1, 1, 0)
    }

    // Empty state
    Column {
        visible: root.clients.length === 0 && !root.loading
        anchors.centerIn: parent
        spacing: 4
        Text {
            text: "\u{EABC}"
            font.family: "Font Awesome 6 Free"
            font.pixelSize: 24
            color: Theme.fgDim
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "empty"
            font.pixelSize: Theme.fontSize - 2
            color: Theme.fgDim
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Loading
    Text {
        visible: root.loading
        text: "..."
        font.pixelSize: 14
        color: Theme.fgDim
        anchors.centerIn: parent
    }

    // Flat layout renderer
    Repeater {
        model: root.renderModel
        Rectangle {
            id: cell
            required property var modelData

            x: modelData.x * root.width
            y: modelData.y * root.height
            width: modelData.w * root.width
            height: modelData.h * root.height
            radius: 3
            color: Theme.accentBg
            border.width: 1
            border.color: Theme.accent
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 0

                Text {
                    width: parent.width
                    text: WorkspaceIcons.forClientClass(cell.modelData.cls)
                    font.family: "Font Awesome 6 Free"
                    font.pixelSize: Math.max(8, Math.min(14, parent.height * 0.55))
                    color: Theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    width: parent.width
                    text: cell.modelData.cls
                    font.pixelSize: Math.max(6, Math.min(8, parent.height * 0.2))
                    color: Theme.fgDim
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            ToolTip {
                visible: cellTipMouse.containsMouse && !cellDragMouse.drag.active
                text: cell.modelData.cls + "\n" + cell.modelData.title
            }
            MouseArea {
                id: cellTipMouse
                anchors.fill: parent
                hoverEnabled: true
            }
            // Drag source — drag a client tile onto a workspace/special button
            // to move it there (port of AGS Gtk.DragSource in WorkspaceOverview).
            MouseArea {
                id: cellDragMouse
                anchors.fill: parent
                drag.target: cell
                drag.axis: Drag.XAndYAxis
                cursorShape: Qt.ClosedHandCursor
                property string pid: cell.modelData.pid ?? ""
                Drag.active: cellDragMouse.drag.active
                Drag.supportedActions: Qt.MoveAction
                Drag.keys: ["application/x-qs-client"]
                Drag.source: cellDragMouse
                Drag.hotSpot: Qt.point(cellDragMouse.mouseX, cellDragMouse.mouseY)
                Drag.mimeData: { "application/x-qs-client": "pid:" + cellDragMouse.pid }
                Drag.dragType: Drag.Internal
                onPressed: {
                    cell.opacity = 0.6
                    cell.scale = 1.05
                }
                onReleased: {
                    cell.opacity = 1.0
                    cell.scale = 1.0
                    cellDragMouse.Drag.drop()
                }
            }
        }
    }
}
