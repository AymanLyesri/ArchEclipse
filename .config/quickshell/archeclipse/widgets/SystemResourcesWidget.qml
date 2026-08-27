import Quickshell
import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    property string className: ""

    // System resources from SysInfo service
    property real cpuUsage: qs.services.SysInfo.cpuUsage
    property real ramUsage: qs.services.SysInfo.ramUsage
    property real ramTotal: qs.services.SysInfo.ramTotal
    property real gpuUsage: qs.services.SysInfo.gpuUsage
    property real gpuTemp: qs.services.SysInfo.gpuTemp

    // Canvas rings for visualization
    function drawRing(ctx, x, y, radius, progress, color, bgColor) {
        ctx.save()
        ctx.beginPath()
        ctx.arc(x, y, radius, 0, 2 * Math.PI)
        ctx.strokeStyle = bgColor
        ctx.lineWidth = 8
        ctx.stroke()

        ctx.beginPath()
        ctx.arc(x, y, radius, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress)
        ctx.strokeStyle = color
        ctx.lineWidth = 8
        ctx.lineCap = "round"
        ctx.stroke()
        ctx.restore()
    }

    function drawText(ctx, text, x, y, font, color) {
        ctx.save()
        ctx.font = font
        ctx.fillStyle = color
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText(text, x, y)
        ctx.restore()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        // CPU Ring
        Row {
            spacing: 15
            Repeater {
                model: [
                    { label: "CPU", value: root.cpuUsage / 100, color: qs.theme.Theme.color4 },
                    { label: "RAM", value: root.ramTotal > 0 ? root.ramUsage / root.ramTotal : 0, color: qs.theme.Theme.color2 },
                    { label: "GPU", value: root.gpuUsage / 100, color: qs.theme.Theme.color1 }
                ]
                delegate: Item {
                    width: 100
                    height: 100

                    Canvas {
                        id: ringCanvas
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const radius = 40
                            const cx = width / 2
                            const cy = height / 2
                            drawRing(ctx, cx, cy, radius, modelData.value, modelData.color, qs.theme.Theme.color8)
                            drawText(ctx, modelData.label, cx, cy - 10, "12px JetBrainsMono NFP", qs.theme.Theme.foreground)
                            drawText(ctx, (modelData.value * 100).toFixed(0) + "%", cx, cy + 10, "14px JetBrainsMono NFP", modelData.color)
                        }
                    }
                }
            }
        }

        // GPU Temp
        Row {
            spacing: 15
            Text {
                text: "GPU Temp: " + root.gpuTemp.toFixed(0) + "°C"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                color: qs.theme.Theme.foreground
            }
        }
    }
}