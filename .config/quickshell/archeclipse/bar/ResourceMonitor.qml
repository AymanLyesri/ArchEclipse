import QtQuick
import qs.theme
import qs.services

// Port of Utilities.tsx ResourceMonitor — CPU / RAM / GPU circular rings.
// Data from SysInfo (same AGS loop binary). Rings drawn with Canvas arcs,
// hover tooltip via text (native tooltips come with the popup pass).
Row {
    id: root
    spacing: 10

    readonly property var res: SysInfo.systemResources
    readonly property real maxGpu: {
        const loads = (res?.gpus ?? []).map(g => g.load).filter(l => l !== null);
        return loads.length ? Math.max(...loads) / 100 : 0;
    }

    Repeater {
        model: [
            { icon: "", val: root.res?.cpuLoad ?? null, tip: "CPU" },
            { icon: "", val: (root.res?.ramUsedGB && root.res?.ramTotalGB) ? root.res.ramUsedGB / root.res.ramTotalGB : null, tip: "RAM" },
            { icon: "󱤟", val: root.maxGpu || null, tip: "GPU" }
        ]

        Item {
            id: ringItem
            required property var modelData
            readonly property real frac: modelData.val === null ? 0 : Math.min(1, modelData.val)
            visible: modelData.val !== null && modelData.val !== undefined

            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2, r = width / 2 - 1.5;
                    ctx.lineWidth = 2;
                    // trough
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                    // value
                    if (ringItem.frac > 0) {
                        ctx.strokeStyle = Theme.foregroundSecondary;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + ringItem.frac * Math.PI * 2);
                        ctx.stroke();
                    }
                }
                Connections {
                    target: SysInfo
                    function onSystemResourcesChanged() { canvas.requestPaint(); }
                }
            }

            Text {
                anchors.centerIn: parent
                text: ringItem.modelData.icon
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }
    }
}
