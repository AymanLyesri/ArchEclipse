import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.theme

// Unified launcher entry: icon/glyph slot + name/description/arg lines from a
// Launcher.mkResult() row. Icons resolve via Quickshell.iconPath(); missing fall back to a letter.
Item {
    id: root

    property var entry: ({})
    property bool selected: false
    property bool compact: false
    // Horizontal space reserved on the right (e.g. inline action buttons)
    // so the text column elides before overlapping it.
    property int rightReserve: 0

    readonly property string _rawIcon: entry && entry.icon != null ? String(entry.icon) : ""
    readonly property string _rawGlyph: entry && entry.glyph != null ? String(entry.glyph) : ""
    // Route the raw value like Launcher.mkResult(): an explicit glyph field, a lone glyph char,
    // or nothing means Text; theme names and paths mean image.
    readonly property bool _wantsImage: {
        if (_rawGlyph !== "")
            return false;
        const s = _rawIcon;
        if (s === "")
            return false;
        if (s.startsWith("image://") || s.startsWith("file://") || s.startsWith("qrc:/") || s.startsWith("/"))
            return true;
        if (/^[A-Za-z0-9_\-+.:]+$/.test(s) && s.length > 2)
            return true;
        return false;
    }
    // Resolve to a loadable URL: bare theme names go through Quickshell.iconPath(name, true) so
    // missing icons yield "" (letter fallback) instead of the purple missing-texture.
    readonly property string _iconSrc: {
        if (!_wantsImage)
            return "";
        const s = _rawIcon;
        if (s.startsWith("image://") || s.startsWith("file://") || s.startsWith("qrc:/") || s.startsWith("/"))
            return s;
        return Quickshell.iconPath(s, true);
    }
    readonly property string _glyph: _rawGlyph !== "" ? _rawGlyph : (_wantsImage ? "" : _rawIcon)
    // Image stays visible while loading; any load error drops to the
    // glyph / letter fallback so the slot is never blank.
    readonly property bool _showImage: _iconSrc !== "" && appIcon.status !== Image.Error
    readonly property string _name: entry && entry.name != null ? String(entry.name) : ""
    // Emoji rows carry the glyph as the name too — showing it twice (slot
    // + name line) is pure duplication, so the name line hides then.
    readonly property bool _showName: root._name !== "" && root._name !== root._glyph
    readonly property string _description: entry && entry.description != null ? String(entry.description) : ""
    readonly property string _argText: entry && entry.argText != null ? String(entry.argText) : ""
    readonly property int _slot: compact ? 28 : 34
    readonly property int _iconSize: compact ? 22 : 28

    implicitWidth: 100
    implicitHeight: compact ? 40 : 52

    // RowLayout (not Row + anchors on managed children): the text column
    // can never slide under the icon slot, by construction.
    RowLayout {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        spacing: Theme.spacing

        // ---------- icon slot ----------
        Item {
            id: iconSlot
            Layout.preferredWidth: root._slot
            Layout.preferredHeight: root._slot
            Layout.alignment: Qt.AlignVCenter

            // Desktop / theme icon via the image://icon/ provider — the old delegates rendered
            // every icon as Text, which cannot display an image URL.
            IconImage {
                id: appIcon
                visible: root._showImage
                anchors.centerIn: parent
                width: root._iconSize
                height: root._iconSize
                source: root._iconSrc
                asynchronous: true
            }

            // Nerd Font / emoji glyph
            Text {
                visible: !root._showImage && root._glyph !== ""
                anchors.centerIn: parent
                text: root._glyph
                font.family: Theme.fontFamily
                font.pixelSize: root._iconSize
                color: root.selected ? Theme.accent : Theme.fg
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            // Fallback: first letter of the app name (also covers icons
            // missing from the theme and image load errors)
            Text {
                visible: !root._showImage && root._glyph === ""
                anchors.centerIn: parent
                text: root._name.length > 0 ? root._name[0].toUpperCase() : "?"
                font.family: Theme.fontFamily
                font.pixelSize: root._iconSize - 6
                font.bold: true
                color: root.selected ? Theme.accent : Theme.muted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // ---------- text lines ----------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                Layout.fillWidth: true
                visible: root._showName
                elide: Text.ElideRight
                text: root._name
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? Theme.fontSize : Theme.fontSize + 1
                font.bold: root.selected || root.compact
            }
            Text {
                Layout.fillWidth: true
                visible: root._description !== ""
                elide: Text.ElideRight
                text: root._description
                color: root.selected ? Qt.alpha(Theme.fg, 0.7) : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? Theme.fontSize - 2 : Theme.fontSize - 1
            }
            Text {
                Layout.fillWidth: true
                visible: root._argText !== "" && !root.compact
                elide: Text.ElideRight
                text: root._argText
                color: root.selected ? Qt.alpha(Theme.fg, 0.5) : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
