import QtQuick
import QtQuick.Controls
import qs.theme

Row {
    id: root

    property var keys: []
    property int chipHeight: 22
    property int chipRadius: 4
    property int pixelSize: ((typeof Settings !== "undefined") && Settings.keybindsFontSize) ? Settings.keybindsFontSize : Theme.fontSizeSmall
    property color chipBg: Theme.surface
    property color chipFg: Theme.accent
    property color separatorColor: Theme.fgDim
    property string iconFontFamily: Theme.fontFamily + ", Symbols Nerd Font, Symbols Nerd Font Mono, sans-serif"
    property string superKey: (typeof Settings !== "undefined" && Settings.keybindsSuperKey) ? Settings.keybindsSuperKey : Icons.keySuper
    property bool useMacSymbol: (typeof Settings !== "undefined") ? !!Settings.keybindsUseMacSymbol : false
    property bool useFnSymbol: (typeof Settings !== "undefined") ? !!Settings.keybindsUseFunctionSymbol : false
    property bool useMouseSymbol: (typeof Settings !== "undefined") ? !!Settings.keybindsUseMouseSymbol : false
    property bool splitButtons: (typeof Settings !== "undefined") ? (Settings.keybindsSplitButtons !== false) : true
    property string combinedText: {
        const entries = (root.keys || []).map((key) => {
            return root.keyLabel(key);
        });
        return entries.join(" ");
    }

    function keyLabel(rawKey) {
        const text = String(rawKey ?? "").trim();
        if (!text)
            return "";

        const normalized = text.toUpperCase();
        const symbolMap = Object.assign({
            "CTRL": "CTRL",
            "CONTROL": "CTRL",
            "SUPER": root.superKey,
            "SUPER_L": root.superKey,
            "SUPER_R": root.superKey,
            "ALT": "ALT",
            "SHIFT": "SHIFT",
            "SPACE": Icons.keySpace,
            "TAB": Icons.keyTab,
            "RETURN": Icons.keyEnter,
            "ENTER": Icons.keyEnter,
            "BACKSPACE": Icons.keyBackspace,
            "DELETE": Icons.keyDelete,
            "ESCAPE": Icons.keyEscape,
            "LEFT": Icons.keyLeft,
            "RIGHT": Icons.keyRight,
            "UP": Icons.keyUp,
            "DOWN": Icons.keyDown,
            "PGUP": Icons.keyPageUp,
            "PGDOWN": Icons.keyPageDown,
            "PRINT": Icons.keyPrint,
            "PERIOD": ".",
            "COMMA": ",",
            "SLASH": "/",
            "HASH": "#",
            "PLUS": "+",
            "MINUS": Icons.keyMinus,
            "EQUAL": "=",
            "XF86MONBRIGHTNESSUP": Icons.keyBrightnessUp,
            "XF86MONBRIGHTNESSDOWN": Icons.keyBrightnessDown,
            "XF86AUDIOMUTE": Icons.keyVolumeOff,
            "XF86AUDIOLOWERVOLUME": Icons.keyVolumeLow,
            "XF86AUDIORAISEVOLUME": Icons.keyVolumeHigh,
            "LMB": "LMB",
            "RMB": "RMB",
            "MOUSE:272": "LMB",
            "MOUSE:273": "RMB",
            "KP0": "0",
            "KP1": "1",
            "KP2": "2",
            "KP3": "3",
            "KP4": "4",
            "KP5": "5",
            "KP6": "6",
            "KP7": "7",
            "KP8": "8",
            "KP9": "9"
        }, root.useMacSymbol ? {
            "CTRL": Icons.keyCtrl,
            "CONTROL": Icons.keyCtrl,
            "ALT": Icons.keyAlt,
            "SHIFT": Icons.keyShift,
            "SUPER": root.superKey,
            "RETURN": Icons.keyEnter
        } : {
        }, root.useFnSymbol ? {
            "F1": Icons.keyF1,
            "F2": Icons.keyF2,
            "F3": Icons.keyF3,
            "F4": Icons.keyF4,
            "F5": Icons.keyF5,
            "F6": Icons.keyF6,
            "F7": Icons.keyF7,
            "F8": Icons.keyF8,
            "F9": Icons.keyF9,
            "F10": Icons.keyF10,
            "F11": Icons.keyF11,
            "F12": Icons.keyF12
        } : {
        }, root.useMouseSymbol ? {
            "LMB": "L" + Icons.keyMouse,
            "RMB": "R" + Icons.keyMouse,
            "MOUSE:272": "L" + Icons.keyMouse,
            "MOUSE:273": "R" + Icons.keyMouse,
            "MOUSE_UP": Icons.keyScrollUp,
            "MOUSE_DOWN": Icons.keyScrollDown,
            "MOUSE_LEFT": Icons.keyScrollLeft,
            "MOUSE_RIGHT": Icons.keyScrollRight
        } : {
        });
        if (Object.prototype.hasOwnProperty.call(symbolMap, normalized))
            return symbolMap[normalized];

        if (normalized.startsWith("CTRL"))
            return root.useMacSymbol ? Icons.keyCtrl : "CTRL";

        if (normalized.startsWith("SUPER"))
            return root.superKey;

        if (normalized.startsWith("ALT"))
            return root.useMacSymbol ? Icons.keyAlt : "ALT";

        if (normalized.startsWith("SHIFT"))
            return root.useMacSymbol ? Icons.keyShift : "SHIFT";

        if (normalized.startsWith("MOUSE"))
            return normalized.replace("MOUSE_", "").replace(":", "");

        return normalized.length <= 2 ? normalized : normalized.charAt(0) + normalized.slice(1).toUpperCase();
    }

    visible: !!keys && keys.length > 0
    spacing: 3

    Row {
        visible: root.splitButtons
        spacing: 3

        Repeater {
            model: root.keys

            delegate: Row {
                required property string modelData
                required property int index

                spacing: 3
                // Fixed height so the "+" label can center deterministically
                // (anchors are ignored inside positioners).
                height: root.chipHeight

                Rectangle {
                    width: kChip.implicitWidth + 10
                    height: root.chipHeight
                    radius: root.chipRadius
                    color: root.chipBg

                    Label {
                        id: kChip

                        anchors.centerIn: parent
                        text: root.keyLabel(modelData)
                        font.pixelSize: root.pixelSize
                        font.bold: true
                        color: root.chipFg
                        font.family: root.iconFontFamily
                    }

                }

                Label {
                    text: "+"
                    y: (parent.height - height) / 2
                    visible: index < (root.keys.length - 1)
                    color: root.separatorColor
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                }

            }

        }

    }

    Rectangle {
        visible: !root.splitButtons
        width: combinedLabel.implicitWidth + 10
        height: root.chipHeight
        radius: root.chipRadius
        color: root.chipBg

        Label {
            id: combinedLabel
            anchors.centerIn: parent
            text: root.combinedText
            font.pixelSize: root.pixelSize
            font.bold: true
            color: root.chipFg
            font.family: root.iconFontFamily
        }

    }

}
