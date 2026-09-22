import QtQuick
import qs.widgets.shared

// Update / Refresh / Logout action row.
Row {
    id: root
    required property var store
    width: parent.width
    spacing: 8
    visible: !!store.profile
    AppButton {
        width: (parent.width - 16) / 3
        text: "Update"
        onClicked: store.updateProfile()
    }
    AppButton {
        width: (parent.width - 16) / 3
        text: "Refresh"
        tooltipText: "Refresh profile"
        enabled: !store.isRefreshing
        // loadProfile is awaited in try/finally — the flag
        // clears when the fetch completes (see fetchProfileComp
        // + handleSessionJson), not synchronously here.
        onClicked: {
            if (store.isRefreshing)
                return;
            store.isRefreshing = true;
            store.progressStatus = "loading";
            store.progressText = "Refreshing profile...";
            store.loadProfile();
        }
    }
    AppButton {
        width: (parent.width - 16) / 3
        text: "Logout"
        onClicked: store.logout()
    }
}
