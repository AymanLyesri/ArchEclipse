import QtQuick
import qs.services

// Shared Esc-to-close grabber (1x1 focused item).
Item {
    id: root
    property var states: []
    width: 1; height: 1
    focus: true
    Keys.onEscapePressed: {
        for (let i = 0; i < root.states.length; i++)
            BarState.deactivate(root.states[i]);
    }
}
