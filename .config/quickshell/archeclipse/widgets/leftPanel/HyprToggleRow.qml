import QtQuick
import qs.services
import qs.widgets.shared

// One Hyprland boolean leaf as a settings row: host binds `value`, the toggle writes through
// Settings.hyprSet + the live `hyprctl eval` push (same path as HyprSliderRow).
SettingRow {
    id: root

    property string settingKey: ""
    property bool value: false

    AppToggle {
        checked: root.value
        onToggled: {
            Settings.hyprSet(root.settingKey, checked);
            Settings.applyHyprlandSettingLive(root.settingKey, checked);
        }
    }
}
