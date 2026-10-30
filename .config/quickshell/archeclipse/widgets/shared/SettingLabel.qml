// SettingLabel — single-line setting name with a concise AppTooltip (full label bold plus a
// one-line description). Ids stay inside the component so use sites never collide.
import QtQuick
import QtQuick.Controls
import qs.theme

Label {
    id: root
    property string tip: ""

    font.pixelSize: Theme.fontSize
    color: Theme.fg
    elide: Text.ElideRight

    HoverHandler {
        id: hover
        cursorShape: Qt.ArrowCursor
    }

    AppTooltip {
        visible: hover.hovered && root.tip !== ""
        text: "<b>" + root.text + "</b><br>" + root.tip
    }
}
