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
import "ModelEntry.js" as ModelEntry

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

    function isChecked(i) {
        return root.checkedValues.indexOf(ModelEntry.valueAt(root.model, i)) !== -1;
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
            text: ModelEntry.labelAt(root.model, index)
            height: root.chipHeight
            pixelSize: root.pixelSize
            enabled: ModelEntry.enabledAt(root.model, index)
            tooltipText: ModelEntry.tooltipAt(root.model, index)
            idleBg: on ? Theme.surfaceActive : Theme.bg
            idleFg: on ? Theme.accent : Theme.fg
            hoverFg: on ? Theme.accent : Theme.fg
            outlined: true
            outlineColor: Theme.border
            onClicked: {
                const v = ModelEntry.valueAt(root.model, index);
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
