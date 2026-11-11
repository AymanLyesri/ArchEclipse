// SettingLabel — single-line setting name with a concise AppTooltip (full label bold plus a
// one-line description). Type comes from the ladder so every settings surface agrees.
import QtQuick
import QtQuick.Controls
import qs.theme

Label {
    id: root
    property string tip: ""

    font.pixelSize: Theme.typeBody
    color: Theme.fg
    elide: Text.ElideRight

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    AppTooltip {
        visible: hover.hovered && root.tip !== ""
        text: "<b>" + root.text + "</b><br>" + root.tip
    }
}
