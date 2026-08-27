import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Settings Widget
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            spacing: 8
            Label {
                text: "Settings"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                spacing: 16
                width: parent.width

                // UI Settings
                Column {
                    spacing: 8
                    Label {
                        text: "Interface"
                        font.pixelSize: Theme.fontSize + 2
                        font.bold: true
                        color: Theme.accent
                    }

                    Row {
                        spacing: 8
                        Label {
                            text: "Opacity"
                            Layout.preferredWidth: 100
                            color: Theme.fg
                        }
                        Slider {
                            id: opacitySlider
                            from: 0
                            to: 1
                            value: Settings.uiOpacity
                            stepSize: 0.01
                            Layout.fillWidth: true
                            onValueChanged: Settings.uiOpacity = value
                        }
                    }

                    Row {
                        spacing: 8
                        Label {
                            text: "Scale"
                            Layout.preferredWidth: 100
                            color: Theme.fg
                        }
                        SpinBox {
                            id: scaleSpin
                            from: 8
                            to: 20
                            value: Settings.uiScale
                            Layout.fillWidth: true
                            onValueChanged: Settings.uiScale = value
                        }
                    }

                    Row {
                        spacing: 8
                        Label {
                            text: "Font Size"
                            Layout.preferredWidth: 100
                            color: Theme.fg
                        }
                        SpinBox {
                            id: fontSizeSpin
                            from: 10
                            to: 20
                            value: Settings.uiFontSize
                            Layout.fillWidth: true
                            onValueChanged: Settings.uiFontSize = value
                        }
                    }
                }

                // Bar Settings
                Column {
                    spacing: 8
                    Label {
                        text: "Bar"
                        font.pixelSize: Theme.fontSize + 2
                        font.bold: true
                        color: Theme.accent
                    }

                    Column {
                        spacing: 8
                        CheckBox {
                            text: "Lock Bar"
                            checked: Settings.barLock
                            onToggled: Settings.barLock = checked
                        }
                        CheckBox {
                            text: "Smart Hide"
                            checked: Settings.barSmartHide
                            onToggled: Settings.barSmartHide = checked
                        }
                        CheckBox {
                            text: "Always Expanded"
                            checked: Settings.barExpanded
                            onToggled: Settings.barExpanded = checked
                        }
                        CheckBox {
                            text: "Full Width"
                            checked: Settings.barFullWidth
                            onToggled: Settings.barFullWidth = checked
                        }
                        CheckBox {
                            text: "Workspace Numbers"
                            checked: Settings.workspaceNumbers
                            onToggled: Settings.workspaceNumbers = checked
                        }
                    }
                }

                // Panel Settings
                Column {
                    spacing: 8
                    Label {
                        text: "Panels"
                        font.pixelSize: Theme.fontSize + 2
                        font.bold: true
                        color: Theme.accent
                    }

                    Column {
                        spacing: 8
                        Row {
                            spacing: 8
                            Label { text: "Left Panel Width:"; color: Theme.fg }
                            SpinBox {
                                from: 200
                                to: 800
                                value: Settings.leftPanelWidth
                                onValueChanged: Settings.leftPanelWidth = value
                            }
                        }
                        Row {
                            spacing: 8
                            Label { text: "Right Panel Width:"; color: Theme.fg }
                            SpinBox {
                                from: 200
                                to: 800
                                value: Settings.rightPanelWidth
                                onValueChanged: Settings.rightPanelWidth = value
                            }
                        }
                        CheckBox {
                            text: "Left Panel Hot Zone"
                            checked: Settings.leftPanelHotZone
                            onToggled: Settings.leftPanelHotZone = checked
                        }
                        CheckBox {
                            text: "Right Panel Hot Zone"
                            checked: Settings.rightPanelHotZone
                            onToggled: Settings.rightPanelHotZone = checked
                        }
                    }
                }

                // Theme Settings
                Column {
                    spacing: 8
                    Label {
                        text: "Theme"
                        font.pixelSize: Theme.fontSize + 2
                        font.bold: true
                        color: Theme.accent
                    }

                    Column {
                        spacing: 8
                        CheckBox {
                            text: "Dynamic Theme Colors"
                            checked: Settings.dynamicThemeColors
                            onToggled: Settings.dynamicThemeColors = checked
                        }
                        CheckBox {
                            text: "Dynamic Theme Variants"
                            checked: Settings.dynamicThemeVariants
                            onToggled: Settings.dynamicThemeVariants = checked
                        }
                        CheckBox {
                            text: "Blur"
                            checked: Settings.barBlur
                            onToggled: Settings.barBlur = checked
                        }
                    }
                }
            }
        }
    }
}