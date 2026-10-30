import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.shared

// One Hyprland numeric leaf as a settings row: read via the host-bound `value`, write through
// Settings.hyprSet (fresh subtree) + the live `hyprctl eval` push; decimals > 0 marks a float.
SettingRow {
    id: root

    property string settingKey: ""
    property real from: 0
    property real to: 10
    property real stepSize: 0
    property int decimals: 0
    property real value: 0

    labelWidth: 170

    AppSlider {
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        Layout.fillWidth: true
        onValueChanged: {
            const v = root.decimals > 0 ? parseFloat(value.toFixed(root.decimals)) : Math.round(value);
            if (v === root.value)
                return;
            Settings.hyprSet(root.settingKey, v);
            Settings.applyHyprlandSettingLive(root.settingKey, v);
        }
    }
    Label {
        font.pixelSize: Theme.fontSize
        text: root.decimals > 0 ? Number(root.value).toFixed(root.decimals) : root.value
        Layout.preferredWidth: 30
        color: Theme.fgDim
    }
}
