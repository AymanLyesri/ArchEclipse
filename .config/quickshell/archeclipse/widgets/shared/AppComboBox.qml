import QtQuick
import QtQuick.Controls
import qs.theme

// Shared dropdown: a recessed field plus a floating popup on the overlay depth, with the
// selected row washed in accent. No resting outline — the chevron and fill do the work.
ComboBox {
    id: root

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    implicitHeight: Math.max(30, Theme.fontSize + 18)

    contentItem: Text {
        leftPadding: 10
        rightPadding: root.indicator.width + root.spacing
        text: root.displayText
        font: root.font
        color: root.enabled ? Theme.fg : Theme.muted
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 140
        color: root.activeFocus || root.popup.visible ? Theme.surfaceOverlay : Theme.surfaceRaised
        radius: Theme.radius
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent

        Behavior on color {
            CAnim {}
        }
    }

    indicator: Text {
        x: root.width - width - 10
        y: root.topPadding + (root.availableHeight - height) / 2
        text: Icons.chevronDown
        font.pixelSize: Theme.fontSizeCaption
        font.family: Theme.fontFamily
        color: Theme.muted
        rotation: root.popup.visible ? 180 : 0

        Behavior on rotation {
            Anim { type: Anim.FastEffects }
        }
    }

    popup: Popup {
        y: root.height + Theme.spaceXs
        width: root.width
        implicitHeight: contentItem.implicitHeight + 8
        padding: 4
        background: Rectangle {
            color: Theme.surfaceFloat
            radius: Theme.radius
        }
        contentItem: SmoothListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }

    // The dropdown is a separate surface, so entering it drops the host's own hover and its
    // hide timer would close the panel mid-pick. Nearest ancestor tracking popupCount holds it.
    function _popupHost() {
        let p = root.parent;
        while (p) {
            if (p.popupCount !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    Connections {
        target: root.popup
        function onVisibleChanged() {
            const host = root._popupHost();
            if (host)
                host.popupCount = Math.max(0, host.popupCount + (root.popup.visible ? 1 : -1));
        }
    }

    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: root.width - 8
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            leftPadding: 8
            text: typeof modelData === "string" ? modelData : (modelData?.display ?? modelData?.name ?? "")
            font: root.font
            color: parent.highlighted ? Theme.accent : Theme.fg
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radius
            color: parent.highlighted ? Theme.surfaceActive : "transparent"

            Behavior on color {
                CAnim {}
            }
        }
    }
}
