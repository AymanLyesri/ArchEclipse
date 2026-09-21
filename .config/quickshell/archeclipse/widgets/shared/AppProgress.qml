// Shared progress indicator — single source of truth for every
// loading/error/success state in the shell (ChatBot pill, Booru thin bar,
// Waifu badge, Manga/UserProfile inline label, Wallpaper/KeyBinds/Booru
// spinner, Player determinate bar).
//
// status: "idle" | "loading" | "error" | "success"
// variant:
//   "pill"    — ChatBot parity: full-width 22px rounded pill + centered text.
//   "bar"     — Booru/Player parity: full-width 4px thin bar (determinate
//               fill when 0 <= value <= 1, solid status color otherwise).
//   "badge"   — Waifu parity: small 64x20 status badge.
//   "inline"  — Manga/UserProfile parity: borderless status label.
//   "spinner" — Wallpaper/KeyBinds/BooruDialog parity: BusyIndicator while
//               loading, ⚠ on error, ✓ on success.
// value: < 0 = indeterminate (status color), 0..1 = determinate fill
//        (pill + bar variants).
// Visibility: showLoading/showError default true; showSuccess/showIdle
// default false (ChatBot parity: pill hides on idle/success). Callers that
// previously showed a success tick (e.g. Wallpaper) set showSuccess: true.
// The item collapses to height 0 + visible:false when inactive so it works
// in both Column (explicit height) and ColumnLayout (implicitHeight).

import QtQuick
import QtQuick.Controls
import qs.theme

Item {
    id: root

    property string status: "idle"
    property string variant: "pill"

    property string loadingText: "Working..."
    property string errorText: "Error — see notification"
    property string successText: "Ready"
    property string idleText: ""

    // Determinate fill for pill/bar. Negative = indeterminate.
    property real value: -1

    property bool showLoading: true
    property bool showError: true
    property bool showSuccess: false
    property bool showIdle: false

    readonly property bool active: (status === "loading" && showLoading) || (status === "error" && showError) || (status === "success" && showSuccess) || (status === "idle" && showIdle)
    readonly property string displayText: {
        if (status === "loading")
            return loadingText;
        if (status === "error")
            return errorText;
        if (status === "success")
            return successText;
        return idleText;
    }
    readonly property color statusColor: status === "error" ? Theme.danger : Theme.accent
    readonly property color statusBg: status === "error" ? Theme.dangerBg : Theme.surfaceActive
    readonly property real clampedValue: Math.max(0, Math.min(1, value))
    readonly property bool determinate: value >= 0

    visible: active
    implicitHeight: {
        if (!active)
            return 0;
        if (variant === "bar")
            return 4;
        if (variant === "badge")
            return 20;
        if (variant === "spinner")
            return 20;
        if (variant === "inline")
            return inlineLabel.implicitHeight;
        return 22;
    }
    implicitWidth: {
        if (variant === "badge")
            return 64;
        if (variant === "spinner")
            return 20;
        if (variant === "inline")
            return inlineLabel.implicitWidth;
        return 0;
    }

    // ---- pill (ChatBot) ----
    Rectangle {
        anchors.fill: parent
        visible: root.variant === "pill" && root.active
        radius: 6
        color: root.statusBg
        border.color: root.statusColor
        clip: true

        // Determinate fill underneath the label.
        Rectangle {
            visible: root.determinate
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.clampedValue
            color: root.statusColor
            opacity: 0.35
            Behavior on width {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        Label {
            anchors.centerIn: parent
            text: root.displayText
            color: root.statusColor
            font.pixelSize: Theme.fontSize - 1
        }
    }

    // ---- bar (Booru / Player) ----
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        visible: root.variant === "bar" && root.active
        color: root.determinate ? Theme.color8 : root.statusColor

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.determinate ? parent.width * root.clampedValue : parent.width
            radius: 2
            color: root.statusColor
            Behavior on width {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }

    // ---- badge (Waifu) ----
    Rectangle {
        anchors.fill: parent
        visible: root.variant === "badge" && root.active
        radius: 4
        color: root.status === "error" ? Theme.danger : (root.status === "success" ? Theme.surfaceActive : Theme.bg)
        border.color: root.status === "error" ? Theme.danger : Theme.border

        Text {
            anchors.centerIn: parent
            text: root.displayText
            color: root.status === "loading" ? Theme.fgDim : (root.status === "error" ? "#fff" : Theme.accent)
            font.pixelSize: 11
        }
    }

    // ---- inline (Manga / UserProfile) ----
    // Anchored left/right/verticalCenter (NOT fill): fill would force a
    // wrapped label into a 0-width root in auto-size parents and blow up
    // implicitHeight. Root height comes from implicitHeight below, or from
    // a caller-fixed height (e.g. a 28px nav row, where this centers).
    Label {
        id: inlineLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.variant === "inline" && root.active
        text: root.displayText
        color: root.status === "error" ? Theme.danger : (root.status === "success" ? Theme.accent : Theme.fgDim)
        font.pixelSize: Theme.fontSize - 1
        wrapMode: Text.WordWrap
        verticalAlignment: Text.AlignVCenter
    }

    // ---- spinner (Wallpaper / KeyBinds / BooruDialog) ----
    BusyIndicator {
        anchors.centerIn: parent
        visible: root.variant === "spinner" && root.active && root.status === "loading"
        running: visible
        implicitWidth: 20
        implicitHeight: 20
    }
    Text {
        anchors.centerIn: parent
        visible: root.variant === "spinner" && root.active && root.status === "error"
        text: "⚠"
        color: Theme.danger
    }
    Text {
        anchors.centerIn: parent
        visible: root.variant === "spinner" && root.active && root.status === "success"
        text: "✓"
        color: "lightgreen"
    }
}
