// Shared multi-toggle filter chips: on/off pill group where any subset
// stays on (e.g. wallpaper switcher's wallhaven Categories
// General/Anime/People). Single-select stays on AppSegmentedControl —
// this covers only the multi-toggle case AppButton Repeaters used to
// inline per call site.
//
//   model         -> [string] or [{value,label[,tooltip,enabled]}].
//                  Strings use the string as both value and label and are
//                  always enabled; object entries may set enabled: false
//                  plus an optional tooltip.
//   checkedValues -> [value] currently on (caller-driven — the chips never
//                  flip it themselves; caller writes its state in onToggled,
//                  e.g. wallhaven's categories "101" bit string).
//   allowEmpty    -> false blocks unchecking the last on-chip and emits
//                  emptyRejected instead (wallhaven's "at least one
//                  category must stay on" guard). True lets all chips go off.
//   label         -> optional leading dim label ("Categories:") in the
//                  wallhaven filter style; empty hides it.
//   chipHeight    -> chip height (24 matches the wallhaven filter row).
//   toggled(i, value, checked) -> emitted on user pick with the chip's
//                  NEW state; caller commits it to checkedValues.
//   emptyRejected -> emitted when allowEmpty is false and the user tries
//                  to uncheck the final on-chip.
//
// Example:
//   AppFilterChips {
//       label: "Categories:"
//       model: ["General", "Anime", "People"]
//       checkedValues: root.checkedCategories
//       allowEmpty: false
//       onToggled: (i, v, c) => root.setCategory(i, c)
//       onEmptyRejected: Notifications.notify({ summary: "Wallhaven", body: "At least one category must stay on." })
//   }
import QtQuick
import qs.theme

Row {
    id: root

    spacing: Theme.spacing

    property string label: ""
    property var model: []
    property var checkedValues: []
    property bool allowEmpty: true
    property int chipHeight: 24
    property int pixelSize: Theme.fontSize - 2

    signal toggled(int index, var value, bool checked)
    signal emptyRejected()

    function valueAt(i) {
        if (!root.model || i < 0 || i >= root.model.length)
            return undefined;
        const e = root.model[i];
        if (typeof e === "string")
            return e;
        return e?.value ?? e?.display ?? e?.name ?? e;
    }
    function labelAt(i) {
        if (!root.model || i < 0 || i >= root.model.length)
            return "";
        const e = root.model[i];
        if (typeof e === "string")
            return e;
        return e?.label ?? e?.display ?? e?.name ?? String(e?.value ?? "");
    }
    function enabledAt(i) {
        if (!root.model || i < 0 || i >= root.model.length)
            return false;
        const e = root.model[i];
        if (typeof e === "string")
            return true;
        return e?.enabled ?? true;
    }
    function tooltipAt(i) {
        if (!root.model || i < 0 || i >= root.model.length)
            return "";
        const e = root.model[i];
        if (typeof e === "string")
            return "";
        return e?.tooltip ?? e?.tooltipText ?? "";
    }
    function isChecked(i) {
        return root.checkedValues.indexOf(root.valueAt(i)) !== -1;
    }

    Text {
        visible: root.label !== ""
        text: root.label
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        height: root.chipHeight + 2
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: root.model
        delegate: AppButton {
            required property var modelData
            required property int index
            readonly property bool on: root.isChecked(index)
            text: root.labelAt(index)
            height: root.chipHeight
            pixelSize: root.pixelSize
            enabled: root.enabledAt(index)
            tooltipText: root.tooltipAt(index)
            idleBg: on ? Theme.surfaceActive : Theme.bg
            idleFg: on ? Theme.accent : Theme.fg
            hoverFg: on ? Theme.accent : Theme.fg
            outlined: true
            outlineColor: Theme.border
            onClicked: {
                const v = root.valueAt(index);
                const checked = !root.isChecked(index);
                if (!checked && !root.allowEmpty && root.checkedValues.length <= 1) {
                    root.emptyRejected();
                    return;
                }
                root.toggled(index, v, checked);
            }
        }
    }
}
