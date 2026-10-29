import QtQuick
import qs.services
import qs.widgets.shared

// One Hyprland boolean leaf as a settings row (Settings page → Hyprland).
// Same edit path as HyprSliderRow: host binds `value`, the toggle writes
// through Settings.hyprSet + the live `hyprctl eval` push.
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
