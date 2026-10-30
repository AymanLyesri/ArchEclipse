pragma Singleton
import QtQuick
import Quickshell

// Shell-lifetime profile cache: LeftIsland is destroyed and recreated on every open,
// so the widget restores instantly and only refetches when the session file changed.
Singleton {
    id: root

    property bool initialized: false
    property var profile: null
    property var cachedSession: null
    property string cachedUid: ""
    property string cachedEmail: ""
    property string supporterSince: ""
    property string lastSessionText: ""
    property string lastSyncAt: "Never"
    property string lastSyncResult: "-"
    property string lastRemoteUpdatedAt: "Never"
}
