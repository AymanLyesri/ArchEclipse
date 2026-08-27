import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.theme

// System Resources widget ported from widgets/rightPanel/components/SystemResources.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    property var stats: SysInfo.systemResources

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            spacing: 8
            Label {
                text: "System Resources"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
            }
            Item { 
                Layout.fillWidth: true 
            }
            Label {
                id: updatedLabel
                text: "Updated: --"
                font.pixelSize: Theme.fontSize - 2
                color: Theme.fgDim
            }
        }

        // CPU, RAM, GPU columns
        Row {
            spacing: 8
            Layout.fillWidth: true

            // CPU Column
            Column {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    text: "CPU"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.fg
                }
                Label {
                    text: root.stats ? "Load: " + root.stats.cpuLoad.toFixed(1) + "%" : "Load: N/A"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                Label {
                    text: root.stats ? "Clock: " + root.stats.clockGHz.toFixed(2) + " GHz" : "Clock: N/A"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                Label {
                    text: root.stats && root.stats.cpuTempC !== null ? "Temp: " + root.stats.cpuTempC.toFixed(1) + "°C" : "Temp: N/A"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
            }

            // RAM Column
            Column {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    text: "RAM"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.fg
                }
                Label {
                    text: root.stats ? "Total: " + root.stats.ramTotalGB.toFixed(2) + " GB" : "Total: N/A"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                Label {
                    text: root.stats ? "Used: " + root.stats.ramUsedGB.toFixed(2) + " GB" : "Used: N/A"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                Label {
                    text: root.stats ? "Free: " + root.stats.ramFreeGB.toFixed(2) + " GB" : "Free: N/A"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
            }

            // GPU Columns (dynamic)
            Repeater {
                model: root.stats && root.stats.gpus ? root.stats.gpus : []
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        text: modelData.label
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        color: Theme.fg
                    }
                    Label {
                        text: "Driver: " + modelData.driver
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    Label {
                        text: modelData.load !== null ? "Load: " + modelData.load.toFixed(1) + "%" : "Load: N/A"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    Label {
                        text: modelData.memoryUsedGB !== null && modelData.memoryTotalGB !== null
                            ? "Memory: " + modelData.memoryUsedGB.toFixed(2) + "/" + modelData.memoryTotalGB.toFixed(2) + " GB"
                            : modelData.memoryUsedGB !== null ? "Memory: " + modelData.memoryUsedGB.toFixed(2) + " GB" : "Memory: N/A"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    Label {
                        text: modelData.tempC !== null ? "Temp: " + modelData.tempC.toFixed(1) + "°C" : "Temp: N/A"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                }
            }
        }
    }
}