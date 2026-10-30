// Shared multi-toggle filter chips where any subset stays on (wallhaven Categories): model is
// [string] or [{value,label,tooltip,enabled}], checkedValues caller-driven, allowEmpty guard.
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
