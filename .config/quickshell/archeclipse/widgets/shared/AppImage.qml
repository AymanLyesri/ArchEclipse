import QtQuick
import Quickshell.Widgets
import qs.theme

ClippingRectangle {
    id: root

    property string source: ""
    property int fillMode: Image.PreserveAspectCrop
    readonly property int status: root.__useAnimated ? agif.status : img.status
    readonly property real implicitImageWidth: root.__useAnimated ? agif.implicitWidth : img.implicitWidth
    readonly property real implicitImageHeight: root.__useAnimated ? agif.implicitHeight : img.implicitHeight
    property int sourceWidth: 0
    // Optional fallback (e.g. original file when thumbnail is missing).
    // If the main source fails to load, automatically retry once with this.
    property string fallbackSource: ""
    property bool __fallbackUsed: false
    property bool animated: false
    readonly property bool __isGif: /\.gif(\?.*)?$/i.test(String(root.source))
    readonly property bool __useAnimated: root.animated && root.__isGif
    // Unified badge overlay (top-right). Callers feed icon strings, e.g.
    // badges: [video ? "\uf03d" : "", bookmarked ? "\uf02e" : ""].filter(x => x !== "")
    property var badges: []

    radius: Theme.radius
    color: "transparent"

    onSourceChanged: root.__fallbackUsed = false

    Image {
        id: img
        anchors.fill: parent
        asynchronous: true
        cache: true
        fillMode: root.fillMode
        sourceSize.width: root.sourceWidth
        visible: !root.__useAnimated
        source: root.__useAnimated ? "" : root.source
        onStatusChanged: {
            if (status === Image.Error && !root.__useAnimated && !root.__fallbackUsed && root.fallbackSource !== "" && root.source !== root.fallbackSource) {
                root.__fallbackUsed = true;
                root.source = root.fallbackSource;
            }
        }
    }

    AnimatedImage {
        id: agif
        anchors.fill: parent
        asynchronous: true
        cache: true
        fillMode: root.fillMode
        sourceSize.width: root.sourceWidth
        visible: root.__useAnimated
        playing: root.__useAnimated
        source: root.__useAnimated ? root.source : ""
        onStatusChanged: {
            if (status === Image.Error && root.__useAnimated && !root.__fallbackUsed && root.fallbackSource !== "" && root.source !== root.fallbackSource) {
                root.__fallbackUsed = true;
                root.source = root.fallbackSource;
            }
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        spacing: 4
        visible: root.badges.length > 0
        Repeater {
            model: root.badges
            delegate: Rectangle {
                required property string modelData
                width: 24
                height: 18
                radius: Theme.radius
                color: Theme.accent
                visible: modelData !== ""
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: 9
                    font.family: Theme.fontFamily
                    color: "white"
                }
            }
        }
    }
}
