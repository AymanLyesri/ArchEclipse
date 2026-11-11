// Shared multi-toggle filter chips where any subset stays on (wallhaven Categories): model is
// [string] or [{value,label,tooltip,enabled}], checkedValues caller-driven, allowEmpty guard.
// Chips are fills on the depth ladder — an unselected chip is a raised well, not an outline.
import QtQuick
import qs.theme
import "ModelEntry.js" as ModelEntry

Row {
    id: root

    spacing: Theme.spaceXs + 2

    property string label: ""
    property var model: []
    property var checkedValues: []
    property bool allowEmpty: true
    property int chipHeight: 26
    property int pixelSize: Theme.fontSizeSmall

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
        height: root.chipHeight
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
            hPadding: 10
            enabled: ModelEntry.enabledAt(root.model, index)
            // String models carry no tooltip; the label is still the only explanation there.
            tooltipText: ModelEntry.tooltipAt(root.model, index) || ("Toggle " + text)
            idleBg: on ? Theme.surfaceActive : Theme.surfaceRaised
            idleFg: on ? Theme.accent : Theme.fgDim
            hoverBg: on ? Theme.surfaceActive : Theme.surfaceOverlay
            hoverFg: on ? Theme.accent : Theme.fg
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
