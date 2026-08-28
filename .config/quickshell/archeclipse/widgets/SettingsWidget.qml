import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services

Item {
    id: root

    property string className: ""

    // Settings categories
    property var currentCategory: "ui"

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Category tabs
        Row {
            spacing: 5
            Repeater {
                model: ["ui", "bar", "panels", "theme"]
                delegate: Button {
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    checked: root.currentCategory === modelData
                    onClicked: root.currentCategory = modelData
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 11
                    background: Rectangle {
                        color: root.currentCategory === modelData ? qs.theme.Theme.accentBg : qs.theme.Theme.color0
                        border.color: root.currentCategory === modelData ? qs.theme.Theme.accent : qs.theme.Theme.color8
                        border.width: 1
                        radius: 4
                    }
                }
            }
        }

        // Settings content
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: settingsContentComponent
        }

        Component {
            id: settingsContentComponent
            Item {
                property var category: root.currentCategory

                Column {
                    anchors.fill: parent
                    spacing: 15

                    // UI Settings
                    Item {
                        visible: category === "ui"
                        Column { spacing: 10
                            Row {
                                Text { text: "Opacity"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 0; to: 1; stepSize: 0.01
                                    value: qs.theme.Settings.ui.opacity.value
                                    onValueChanged: qs.theme.Settings.updateSetting("ui.opacity", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: (qs.theme.Settings.ui.opacity.value * 100).toFixed(0) + "%"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            Row {
                                Text { text: "Scale"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 10; to: 30; stepSize: 1
                                    value: qs.theme.Settings.ui.scale.value
                                    onValueChanged: qs.theme.Settings.updateSetting("ui.scale", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.ui.scale.value; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            Row {
                                Text { text: "Font Size"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 10; to: 30; stepSize: 1
                                    value: qs.theme.Settings.ui.fontSize.value
                                    onValueChanged: qs.theme.Settings.updateSetting("ui.fontSize", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.ui.fontSize.value; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            CheckBox {
                                text: "Dynamic Theme Colors"
                                checked: qs.theme.Settings.dynamicThemeColors
                                onToggled: qs.theme.Settings.updateSetting("dynamicThemeColors", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Dynamic Theme Variants"
                                checked: qs.theme.Settings.dynamicThemeVariants
                                onToggled: qs.theme.Settings.updateSetting("dynamicThemeVariants", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Bar Settings
                    Item {
                        visible: category === "bar"
                        Column { spacing: 10
                            CheckBox {
                                text: "Lock Bar"
                                checked: qs.theme.Settings.bar.lock.value
                                onToggled: qs.theme.Settings.updateSetting("bar.lock", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Smart Hide"
                                checked: qs.theme.Settings.bar.smartHide.value
                                onToggled: qs.theme.Settings.updateSetting("bar.smartHide", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Always Expanded"
                                checked: qs.theme.Settings.bar.expanded.value
                                onToggled: qs.theme.Settings.updateSetting("bar.expanded", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Full Width"
                                checked: qs.theme.Settings.bar.fullWidth.value
                                onToggled: qs.theme.Settings.updateSetting("bar.fullWidth", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Top Orientation"
                                checked: qs.theme.Settings.bar.orientation.value
                                onToggled: qs.theme.Settings.updateSetting("bar.orientation", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Workspace Numbers"
                                checked: qs.theme.Settings.bar.workspaceNumbers.value
                                onToggled: qs.theme.Settings.updateSetting("bar.workspaceNumbers", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            Row {
                                Text { text: "Reveal Pressure"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 0; to: 1000; stepSize: 10
                                    value: qs.theme.Settings.bar.revealPressure.value
                                    onValueChanged: qs.theme.Settings.updateSetting("bar.revealPressure", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.bar.revealPressure.value; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                        }
                    }

                    // Panel Settings
                    Item {
                        visible: category === "panels"
                        Column { spacing: 10
                            // Left Panel
                            Text { text: "Left Panel"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; font.bold: true; color: qs.theme.Theme.foreground }
                            CheckBox {
                                text: "Hot Zone Enabled"
                                checked: qs.theme.Settings.leftPanel.hotZone.value
                                onToggled: qs.theme.Settings.updateSetting("leftPanel.hotZone", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Lock"
                                checked: qs.theme.Settings.leftPanel.lock.value
                                onToggled: qs.theme.Settings.updateSetting("leftPanel.lock", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            Row {
                                Text { text: "Width"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 200; to: 600; stepSize: 10
                                    value: qs.theme.Settings.leftPanel.width
                                    onValueChanged: qs.theme.Settings.updateSetting("leftPanel.width", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.leftPanel.width; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            Row {
                                Text { text: "Hot Zone Size"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 1; to: 50; stepSize: 1
                                    value: qs.theme.Settings.leftPanel.hotZoneSize.value
                                    onValueChanged: qs.theme.Settings.updateSetting("leftPanel.hotZoneSize", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.leftPanel.hotZoneSize.value + "px"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }

                            // Right Panel
                            Text { text: "Right Panel"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; font.bold: true; color: qs.theme.Theme.foreground }
                            CheckBox {
                                text: "Hot Zone Enabled"
                                checked: qs.theme.Settings.rightPanel.hotZone.value
                                onToggled: qs.theme.Settings.updateSetting("rightPanel.hotZone", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            CheckBox {
                                text: "Lock"
                                checked: qs.theme.Settings.rightPanel.lock.value
                                onToggled: qs.theme.Settings.updateSetting("rightPanel.lock", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            Row {
                                Text { text: "Width"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 200; to: 500; stepSize: 10
                                    value: qs.theme.Settings.rightPanel.width
                                    onValueChanged: qs.theme.Settings.updateSetting("rightPanel.width", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.rightPanel.width; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            Row {
                                Text { text: "Hot Zone Size"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 1; to: 50; stepSize: 1
                                    value: qs.theme.Settings.rightPanel.hotZoneSize.value
                                    onValueChanged: qs.theme.Settings.updateSetting("rightPanel.hotZoneSize", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.rightPanel.hotZoneSize.value + "px"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                        }
                    }

                    // Theme Settings
                    Item {
                        visible: category === "theme"
                        Column { spacing: 10
                            CheckBox {
                                text: "Enable Blur"
                                checked: qs.theme.Settings.hyprland.decoration.blur.enabled.value
                                onToggled: qs.theme.Settings.updateSetting("hyprland.decoration.blur.enabled", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                            Row {
                                Text { text: "Blur Size"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 0; to: 10; stepSize: 1
                                    value: qs.theme.Settings.hyprland.decoration.blur.size.value
                                    onValueChanged: qs.theme.Settings.updateSetting("hyprland.decoration.blur.size", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.hyprland.decoration.blur.size.value; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            Row {
                                Text { text: "Blur Passes"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 0; to: 10; stepSize: 1
                                    value: qs.theme.Settings.hyprland.decoration.blur.passes.value
                                    onValueChanged: qs.theme.Settings.updateSetting("hyprland.decoration.blur.passes", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.hyprland.decoration.blur.passes.value; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            Row {
                                Text { text: "Border Size"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 0; to: 10; stepSize: 1
                                    value: qs.theme.Settings.hyprland.general.border_size.value
                                    onValueChanged: qs.theme.Settings.updateSetting("hyprland.general.border_size", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.hyprland.general.border_size.value; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            Row {
                                Text { text: "Rounding"; font.family: "JetBrainsMono NFP"; font.pixelSize: 12; color: qs.theme.Theme.foreground; Layout.fillWidth: true }
                                Slider {
                                    from: 0; to: 50; stepSize: 1
                                    value: qs.theme.Settings.hyprland.decoration.rounding.value
                                    onValueChanged: qs.theme.Settings.updateSetting("hyprland.decoration.rounding", value)
                                    Layout.fillWidth: true
                                }
                                Text { text: qs.theme.Settings.hyprland.decoration.rounding.value; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8 }
                            }
                            CheckBox {
                                text: "Shadow Enabled"
                                checked: qs.theme.Settings.hyprland.decoration.shadow.enabled.value
                                onToggled: qs.theme.Settings.updateSetting("hyprland.decoration.shadow.enabled", checked)
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }
}