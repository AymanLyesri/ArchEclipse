pragma Singleton
import QtQuick
import Quickshell

// UserProfileState — shell-lifetime cache for UserProfileWidget.
// LeftIsland is destroyed/recreated on every open/close (Bar Loader swap),
// which used to re-run the full profile load (net gate + REST) on each open.
// The widget restores from here instantly on creation and only refetches when
// the local session file actually changed (cheap `cat` compare, no network).
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
