import QtQuick
import Quickshell
import qs.theme
import qs.widgets.shared

// Pure login-box UI shared by lock + greeter. No auth imports here.
Column {
    id: root
    property string title: "Locked"
    property string iconText: ""
    property string promptText: "Enter password"
    property string errorText: "Incorrect password — try again"
    property string currentText: ""
    property bool showError: false
    property bool inputVisible: true
    property bool busy: false
    // False in the greeter (no Hyprland session under cage to log out of).
    property bool logoutVisible: true
    property string logoutIcon: "\uf08b"
    property string logoutTooltip: "Logout from Hyprland"
    property string poweroffIcon: "\uf011"
    property string poweroffTooltip: "Shutdown immediately"
    property string suspendIcon: "\uf186"
    property string suspendTooltip: "Put system to sleep"
    property string rebootIcon: "\uf021"
    property string rebootTooltip: "Reboot immediately"
    // Optional user picker (greeter only; empty list = hidden, lock unaffected).
    property var userNames: []
    property string pickedUser: ""
    signal userPicked(string name)
    signal textChanged(string text)
    signal accepted()
    signal escapePressed()
    signal action(int index)
    spacing: 12
    function forceFieldFocus() {
        passwordField.forceActiveFocus();
    }
    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.iconText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize * 4; color: Theme.fg }
    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.title; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 4; font.bold: true; color: Theme.fg }
    AppComboBox {
        width: parent.width
        visible: root.userNames.length > 0
        model: root.userNames
        currentIndex: Math.max(0, root.userNames.indexOf(root.pickedUser))
        onActivated: index => root.userPicked(root.userNames[index])
    }
    AppTextField {
        id: passwordField
        width: parent.width; visible: root.inputVisible
        cornerRadius: 12
        placeholderText: root.showError ? "Incorrect password" : root.promptText
        echoMode: TextInput.Password; inputMethodHints: Qt.ImhSensitiveData
        enabled: !root.busy; text: root.currentText
        onTextChanged: root.textChanged(text)
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escapePressed()
        Component.onCompleted: forceActiveFocus()
    }
    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; visible: root.showError; text: root.errorText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; color: Theme.danger }
    Row {
        width: parent.width; spacing: 8
        AppButton { visible: root.logoutVisible; width: (parent.width - 24) / 4; icon: root.logoutIcon; tooltipText: root.logoutTooltip; onClicked: root.action(0) }
        AppButton { width: root.logoutVisible ? (parent.width - 24) / 4 : (parent.width - 16) / 3; icon: root.poweroffIcon; tooltipText: root.poweroffTooltip; onClicked: root.action(1) }
        AppButton { width: root.logoutVisible ? (parent.width - 24) / 4 : (parent.width - 16) / 3; icon: root.suspendIcon; tooltipText: root.suspendTooltip; onClicked: root.action(2) }
        AppButton { width: root.logoutVisible ? (parent.width - 24) / 4 : (parent.width - 16) / 3; icon: root.rebootIcon; tooltipText: root.rebootTooltip; onClicked: root.action(3) }
    }
}
