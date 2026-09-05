import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

// User Profile widget - full port of UserProfile.tsx + Supabase.class.tsx
// Auth via magic link -> local Python callback server writes session.json ->
// profile fetched from Supabase REST. Settings sync upload/download to
// ~/.config/ags/cache/settings/settings.json (shared with AGS shell).
// minimal mode (for UserPanel overlay): shows only avatar + username
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""
    property bool minimal: false

    // --- Config (single source of truth mirroring supabase.constants.ts) ---
    readonly property string supabaseUrl: "https://skekmjmsgcbfhbwgpzkp.supabase.co"
    readonly property string supabaseKey: "sb_publishable_PLXFIwBsb79Gfu3YkW5B-w_rHozkZ1y"
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string authSessionPath: homeDir + "/.config/ags/cache/auth/session.json"
    readonly property string settingsPath: homeDir + "/.config/ags/cache/settings/settings.json"
    readonly property string settingsMetaPath: homeDir + "/.config/ags/cache/settings/settings-sync.json"
    readonly property string avatarPath: homeDir + "/.face.icon"

    // --- State ---
    property var profile: null
    property string progressStatus: "idle"
    property string progressText: "Not signed in"
    property bool isSyncing: false
    property bool isRefreshing: false
    property string lastSyncAt: ""
    property string lastSyncResult: "-"
    property string lastRemoteUpdatedAt: ""
    property var _cachedSession: null

    // AGS UserProfile.tsx:113-125 — per-API bookmark counts from
    // globalSettings booru.bookmarks (each item stores api.value).
    readonly property var booruApis: [
        { name: "Danbooru",  value: "danbooru" },
        { name: "Gelbooru",  value: "gelbooru" },
        { name: "Safebooru", value: "safebooru" },
    ]
    readonly property var booruFavoriteCounts: {
        const counts = { danbooru: 0, gelbooru: 0, safebooru: 0 };
        const marks = Settings.booru ? Settings.booru.bookmarks : null;
        if (marks) for (const b of marks) {
            const v = b && b.api ? b.api.value : null;
            if (v && typeof counts[v] === "number") counts[v] += 1;
        }
        return counts;
    }
    // AGS UserProfile.tsx:44 — fastfetch pin count.
    readonly property int pinnedCount: {
        const pins = Settings.booru ? Settings.booru.pins : null;
        return pins ? pins.length : 0;
    }

    property QtObject fileWatch: QtObject { id: _fw }
    property int activeTab: 0

    Component.onCompleted: {
        applySettingsSyncMeta()
        loadProfile()
        pollTimer.restart()
    }

    property Timer pollTimer: Timer {
        interval: 3000
        repeat: true
        running: false
        onTriggered: { root.loadProfile(); root.applySettingsSyncMeta() }
    }

    // ===== PROFILE =====
    function loadProfile() {
        loadAuthComp.createObject(root).running = true
    }

    function handleSessionJson(text) {
        let session = null
        try { session = text ? JSON.parse(text) : null } catch (e) { session = null }
        root._cachedSession = session
        if (!session?.access_token) {
            root.profile = null
            root.progressStatus = "idle"
            root.progressText = "Not signed in"
            return
        }
        root.progressStatus = "loading"
        root.progressText = "Loading profile..."
        const p = fetchProfileComp.createObject(root)
        p.command = ["bash", "-c",
            "curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' '" + supabaseUrl + "/auth/v1/user'; echo; echo '---SEP---'; curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' '" + supabaseUrl + "/rest/v1/user_profiles?select=id,username,avatar&id=eq." + (lookupUserId() ? encodeURIComponent(lookupUserId()) : "none") + "'"]
        p.running = true
    }

    function lookupUserId() {
        return _cachedSession?.user?.id ?? _cachedSession?.id ?? ""
    }

    // ===== MAGIC LINK =====
    function sendMagicLink(email) {
        if (!email || email.trim() === "") {
            Notifications.notify({ summary: "Email", body: "Enter a valid email" })
            return
        }
        const p = magicLinkComp.createObject(root)
        p.command = ["bash", "-c",
            "curl -sS -X POST -H 'Content-Type: application/json' -H 'apikey: " + supabaseKey + "' -d '" +
            JSON.stringify({ email: email.trim(), options: { shouldCreateUser: true, emailRedirectTo: "http://127.0.0.1:53100/callback" } }) +
            "' '" + supabaseUrl + "/auth/v1/otp'"]
        p.running = true
        ensureAuthServer()
    }

    function ensureAuthServer() {
        const p = authServerComp.createObject(root)
        p.command = ["bash", "-c", "pkill -f 'python3 " + homeDir + "/.config/ags/scripts/auth-server-callback.py' || true"]
        p.running = true
        p.onExited = function() {
            const p2 = authServerComp.createObject(root)
            p2.command = ["bash", "-c", "(python3 '" + homeDir + "/.config/ags/scripts/auth-server-callback.py' >/tmp/ags-auth-server.log 2>&1 &)"]
            p2.running = true
        }
    }

    // ===== UPDATE PROFILE =====
    function updateProfile() {
        const session = _cachedSession
        if (!session?.access_token) {
            Notifications.notify({ summary: "Not signed in", body: "Please sign in to update profile." })
            return
        }
        root.progressStatus = "loading"
        root.progressText = "Updating profile..."
        const uid = session.user?.id ?? session.id ?? ""
        const username = usernameField.text.trim() || homeDir.split("/").pop()
        const p = updateProfileComp.createObject(root)
        p.command = ["bash", "-c",
            "curl -sS -X PATCH -H 'Content-Type: application/json' -H 'apikey: " + supabaseKey +
            "' -H 'Authorization: Bearer " + session.access_token + "' -H 'Prefer: return=representation' -d '" +
            JSON.stringify({ username }) + "' '" + supabaseUrl + "/rest/v1/user_profiles?id=eq." + encodeURIComponent(uid) + "'"]
        p.running = true
    }

    // ===== LOGOUT =====
    function logout() {
        logoutComp.createObject(root).running = true
        root.profile = null
        root.progressStatus = "idle"
        root.progressText = "Signed out"
        Notifications.notify({ summary: "Signed out", body: "Your session has been cleared." })
    }

    // ===== SETTINGS SYNC =====
    function applySettingsSyncMeta() {
        readMetaComp.createObject(root).running = true
    }

    function formatTs(iso) {
        if (!iso) return "Never"
        const d = new Date(iso)
        if (isNaN(d.getTime())) return "Never"
        const p = (n) => n.toString().padStart(2, "0")
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + ":" + p(d.getMinutes())
    }

    function syncSettings(direction) {
        if (root.isSyncing) return
        const session = _cachedSession
        if (!session?.access_token) {
            Notifications.notify({ summary: "Settings Sync", body: "Not signed in." })
            return
        }
        root.isSyncing = true
        root.progressStatus = "loading"
        root.progressText = direction === "upload" ? "Uploading settings..." : "Downloading settings..."
        const uid = session.user?.id ?? session.id ?? ""

        if (direction === "upload") {
            const settingsJson = readLocalSettings()
            const p = syncUploadComp.createObject(root)
            p.command = ["bash", "-c",
                "curl -sS -X POST -H 'Content-Type: application/json' -H 'apikey: " + supabaseKey +
                "' -H 'Authorization: Bearer " + session.access_token + "' -H 'Prefer: resolution=merge-duplicates,return=representation' -d '" +
                JSON.stringify({ id: uid, settings: settingsJson, updated_at: new Date().toISOString() }) + "' '" + supabaseUrl + "/rest/v1/user_settings?on_conflict=id'"]
            p.running = true
        } else {
            const p = syncDownloadComp.createObject(root)
            p.command = ["bash", "-c",
                "curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token +
                "' '" + supabaseUrl + "/rest/v1/user_settings?select=id,settings,updated_at&id=eq." + encodeURIComponent(uid) + "'"]
            p.running = true
        }
    }

    // AGS readLocalSettings (utils/settings-sync.ts): the real on-disk
    // settings file — never {} (an empty upload would wipe the remote copy).
    function readLocalSettings() {
        return Settings.readLocalSettingsJson()
    }

    // ===== AVATAR =====
    function chooseAvatar() {
        zenityComp.createObject(root).running = true
    }

    function maskEmail(email) {
        if (!email) return ""
        const at = email.indexOf("@")
        if (at <= 1) return email
        return email.slice(0, 1) + "***@" + email.slice(at + 1)
    }

    // ===== UI: MINIMAL MODE =====
    Item {
        id: minimalView
        anchors.fill: parent
        visible: root.minimal
        Column {
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width * 0.5, 120)
                height: Math.min(parent.width * 0.5, 120)
                radius: width / 2
                border.width: 2
                border.color: Theme.accent
                clip: true
                Image {
                    id: minAvatarImg
                    anchors.fill: parent
                    source: root.avatarPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    color: Theme.accentBg
                    visible: minAvatarImg.status !== Image.Ready
                    Text { anchors.centerIn: parent; text: "\u{F007}"; font.pixelSize: 48; color: Theme.accent }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.profile?.username ?? "Not signed in"
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.foreground
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.profile?.is_supporter ? "Supporter" : "Member"
                font.pixelSize: Theme.fontSize - 2
                color: Theme.fgDim
            }
        }
    }

    // ===== UI: FULL MODE =====
    Column {
        id: fullView
        anchors.fill: parent
        spacing: 10
        visible: !root.minimal

        // Tab buttons
        Row {
            width: parent.width + 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Rectangle {
                id: accountTabBtn
                width: (parent.width - 6) / 2
                height: 30
                radius: 6
                color: root.activeTab === 0 ? Theme.accentBg : Theme.moduleBg
                border.width: 1
                border.color: root.activeTab === 0 ? Theme.accent : Theme.border
                Text { anchors.centerIn: parent; text: "Account"; font.pixelSize: Theme.fontSize; font.bold: root.activeTab === 0; color: root.activeTab === 0 ? Theme.accent : Theme.fg }
                MouseArea { anchors.fill: parent; onClicked: root.activeTab = 0 }
            }
            Rectangle {
                id: generalTabBtn
                width: (parent.width - 6) / 2
                height: 30
                radius: 6
                color: root.activeTab === 1 ? Theme.accentBg : Theme.moduleBg
                border.width: 1
                border.color: root.activeTab === 1 ? Theme.accent : Theme.border
                Text { anchors.centerIn: parent; text: "About"; font.pixelSize: Theme.fontSize; font.bold: root.activeTab === 1; color: root.activeTab === 1 ? Theme.accent : Theme.fg }
                MouseArea { anchors.fill: parent; onClicked: root.activeTab = 1 }
            }
        }

        // Stack: Account | About
        StackLayout {
            width: parent.width
            height: parent.height - 40
            currentIndex: root.activeTab

            // Account tab
            Column {
                width: parent.width
                spacing: 10
                clip: true

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width * 0.5, 150)
                    height: Math.min(parent.width * 0.5, 150)
                    radius: width / 2
                    border.width: 2
                    border.color: Theme.accent
                    clip: true
                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: root.avatarPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.accentBg
                        visible: avatarImg.status !== Image.Ready
                        Text { anchors.centerIn: parent; text: "\u{F007}"; font.pixelSize: 48; color: Theme.accent }
                    }
                    MouseArea {
                        id: avatarMa
                        anchors.fill: parent
                        onClicked: root.chooseAvatar()
                        ToolTip.visible: avatarMa.containsMouse
                        ToolTip.text: "Click to set up profile picture"
                    }
                }

                Column {
                    spacing: 5
                    width: parent.width
                    TextField {
                        id: usernameField
                        placeholderText: homeDir.split("/").pop()
                        text: root.profile?.username ?? ""
                        Layout.fillWidth: true
                        horizontalAlignment: TextInput.AlignHCenter
                        background: Rectangle { color: Theme.bg; radius: 4; border.width: 1; border.color: Theme.border }
                        onAccepted: root.updateProfile()
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        Label { text: root.maskEmail(root.profile?.email ?? ""); font.pixelSize: Theme.fontSize - 1; color: Theme.fgDim }
                        Label { text: "|"; font.pixelSize: Theme.fontSize - 1; color: Theme.fgDim }
                        Label { text: "Supporter: " + (root.profile?.is_supporter ? "Yes" : "No"); font.pixelSize: Theme.fontSize - 1; color: Theme.fgDim }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.progressText
                        font.pixelSize: Theme.fontSize - 1
                        color: root.progressStatus === "error" ? Theme.danger : root.progressStatus === "success" ? Theme.accent : Theme.fgDim
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5
                    visible: !!root.profile
                    Button {
                        text: "Update"
                        Layout.fillWidth: true
                        onClicked: root.updateProfile()
                        background: Rectangle { color: Theme.accentBg; radius: 4; border.width: 1; border.color: Theme.accent }
                        contentItem: Text { anchors.centerIn: parent; text: "Update"; color: Theme.accent; font.pixelSize: Theme.fontSize }
                    }
                    Button {
                        text: "Refresh Profile"
                        Layout.fillWidth: true
                        enabled: !root.isRefreshing
                        onClicked: { root.isRefreshing = true; root.loadProfile(); root.isRefreshing = false }
                        background: Rectangle { color: Theme.moduleBg; radius: 4; border.width: 1; border.color: Theme.border }
                        contentItem: Text { anchors.centerIn: parent; text: "Refresh Profile"; color: Theme.fg; font.pixelSize: Theme.fontSize }
                    }
                    Button {
                        text: "Logout"
                        Layout.fillWidth: true
                        onClicked: root.logout()
                        background: Rectangle { color: Theme.dangerBg; radius: 4; border.width: 1; border.color: Theme.danger }
                        contentItem: Text { anchors.centerIn: parent; text: "Logout"; color: Theme.danger; font.pixelSize: Theme.fontSize }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5
                    visible: !!root.profile
                    Label { text: "Settings Sync"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.fg }
                    Row {
                        width: parent.width
                        spacing: 8
                        Button {
                            Layout.fillWidth: true
                            text: "Download"
                            onClicked: root.syncSettings("download")
                            background: Rectangle { color: Theme.accentBg; radius: 4; border.width: 1; border.color: Theme.accent }
                            contentItem: Text { anchors.centerIn: parent; text: "Download"; color: Theme.accent; font.pixelSize: Theme.fontSize }
                        }
                        Button {
                            Layout.fillWidth: true
                            text: "Upload"
                            onClicked: root.syncSettings("upload")
                            background: Rectangle { color: Theme.moduleBg; radius: 4; border.width: 1; border.color: Theme.border }
                            contentItem: Text { anchors.centerIn: parent; text: "Upload"; color: Theme.fg; font.pixelSize: Theme.fontSize }
                        }
                    }
                    Label { text: "Last sync: " + root.lastSyncAt; font.pixelSize: Theme.fontSize - 1; color: Theme.fgDim }
                    Label { text: "Last result: " + root.lastSyncResult; font.pixelSize: Theme.fontSize - 1; color: Theme.fgDim }
                    Label { text: "Remote updated: " + root.lastRemoteUpdatedAt; font.pixelSize: Theme.fontSize - 1; color: Theme.fgDim }
                }

                // AGS UserProfile.tsx:524-542 — per-API bookmark counts.
                Column {
                    width: parent.width
                    spacing: 5
                    visible: !!root.profile
                    Label { text: "Booru Favorites"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.fg }
                    Repeater {
                        model: root.booruApis
                        delegate: Row {
                            width: parent.width
                            spacing: 5
                            Label { text: modelData.name; font.pixelSize: Theme.fontSize; color: Theme.fg; Layout.fillWidth: true }
                            Label {
                                text: root.profile ? String(root.booruFavoriteCounts[modelData.value] ?? 0) : ""
                                font.pixelSize: Theme.fontSize; color: Theme.fgDim
                            }
                        }
                    }
                }

                // AGS UserProfile.tsx:543-555 — fastfetch pin count.
                Column {
                    width: parent.width
                    spacing: 5
                    visible: !!root.profile
                    Label { text: "Pinned Images"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.fg }
                    Row {
                        width: parent.width
                        spacing: 6
                        Label { text: "Fastfetch cache"; font.pixelSize: Theme.fontSize; color: Theme.fg; Layout.fillWidth: true }
                        Label {
                            text: root.profile ? String(root.pinnedCount) : ""
                            font.pixelSize: Theme.fontSize; color: Theme.fgDim
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10
                    visible: !root.profile
                    Label { text: "Sign in to sync"; font.pixelSize: Theme.fontSize + 1; font.bold: true; color: Theme.fg }
                    Label { text: "\u2022 Profile picture\n\u2022 Settings\n\u2022 More to come"; font.pixelSize: Theme.fontSize - 1; color: Theme.fgDim; wrapMode: Text.WordWrap }
                    TextField {
                        id: emailField
                        placeholderText: "you@example.com"
                        text: ""
                        Layout.fillWidth: true
                        background: Rectangle { color: Theme.bg; radius: 4; border.width: 1; border.color: Theme.border }
                        onAccepted: root.sendMagicLink(emailField.text)
                    }
                    Button {
                        text: "Send Magic Link"
                        Layout.fillWidth: true
                        enabled: emailField.text.trim().length > 0
                        onClicked: root.sendMagicLink(emailField.text)
                        background: Rectangle { color: Theme.accentBg; radius: 4; border.width: 1; border.color: Theme.accent }
                        contentItem: Text { anchors.centerIn: parent; text: "Send Magic Link"; color: Theme.accent; font.pixelSize: Theme.fontSize }
                    }
                }
            }

            // About tab
            GeneralTab { anchors.fill: parent }
        }
    }

    // Hidden Process components for async operations (wrapped in Component for createObject)
    Component { id: loadAuthComp; Process { stdout: StdioCollector { onStreamFinished: root.handleSessionJson(text) } } }
    Component { id: fetchProfileComp; Process { stdout: StdioCollector { onStreamFinished: { const parts = text.split("---SEP---"); if (parts.length === 2) { try { const user = JSON.parse(parts[0].trim()); const prof = JSON.parse(parts[1].trim()); if (prof?.[0]) { root.profile = { id: user?.id, email: user?.email, username: prof[0].username, avatar: prof[0].avatar, is_supporter: prof[0].is_supporter }; root.progressStatus = "idle"; root.progressText = (prof[0].username ?? "No username") + " \u2022 " + (prof[0].is_supporter ? "Supporter" : "Member"); } else { root.profile = null; root.progressStatus = "error"; root.progressText = "Profile not found"; } } catch (e) { root.profile = null; root.progressStatus = "error"; root.progressText = "Failed to parse profile"; } } } } } }
    Component { id: magicLinkComp; Process { stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); if (r.error) { Notifications.notify({ summary: "Error", body: r.error }); } else { Notifications.notify({ summary: "Magic link sent", body: "Check your email and open the link to complete sign-in." }); } } catch (e) { Notifications.notify({ summary: "Error", body: "Failed to send magic link" }); } } } } }
    Component { id: authServerComp; Process { } }
    Component { id: updateProfileComp; Process { stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); if (r?.[0]?.username) { root.progressStatus = "success"; root.progressText = "Profile updated"; Notifications.notify({ summary: "Profile updated", body: "Your profile has been updated successfully." }); root.loadProfile(); } else { root.progressStatus = "error"; root.progressText = "Update failed"; Notifications.notify({ summary: "Update failed", body: "Failed to update profile." }); } } catch (e) { root.progressStatus = "error"; root.progressText = "Update failed"; Notifications.notify({ summary: "Update failed", body: "Failed to update profile." }); } } } } }
    Component { id: logoutComp; Process { command: ["rm", "-f", root.authSessionPath] } }
    Component { id: readMetaComp; Process { stdout: StdioCollector { onStreamFinished: { try { const m = JSON.parse(text); root.lastSyncAt = m?.last_sync_at ? root.formatTs(m.last_sync_at) : "Never"; root.lastSyncResult = m?.last_sync_result ?? "-"; root.lastRemoteUpdatedAt = m?.last_remote_updated_at ? root.formatTs(m.last_remote_updated_at) : "Never"; } catch (e) { root.lastSyncAt = "Never"; root.lastSyncResult = "-"; root.lastRemoteUpdatedAt = "Never"; } } } } }
    Component { id: syncUploadComp; Process { stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); root.isSyncing = false; root.progressStatus = "success"; root.progressText = "Settings uploaded"; Notifications.notify({ summary: "Settings Sync", body: "Settings uploaded successfully." }); root.applySettingsSyncMeta(); } catch (e) { root.isSyncing = false; root.progressStatus = "error"; root.progressText = "Upload failed"; Notifications.notify({ summary: "Settings Sync", body: "Upload failed." }); } } } } }
    Component { id: syncDownloadComp; Process { stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); root.isSyncing = false; if (r?.[0]?.settings) { const p = writeSettingsComp.createObject(root); p.command = ["bash", "-c", "cat > " + settingsPath + " <<'EOF'\n" + JSON.stringify(r[0].settings, null, 2) + "\nEOF"]; p.running = true; root.progressStatus = "success"; root.progressText = "Settings downloaded"; Notifications.notify({ summary: "Settings Sync", body: "Settings downloaded successfully." }); root.applySettingsSyncMeta(); } else { root.isSyncing = false; root.progressStatus = "error"; root.progressText = "No settings found"; Notifications.notify({ summary: "Settings Sync", body: "No remote settings found." }); } } catch (e) { root.isSyncing = false; root.progressStatus = "error"; root.progressText = "Download failed"; Notifications.notify({ summary: "Settings Sync", body: "Download failed." }); } } } } }
    Component { id: writeSettingsComp; Process { } }
    Component { id: zenityComp; Process { stdout: StdioCollector { onStreamFinished: { const path = text.trim(); if (path && path.length > 0) { const p = setAvatarComp.createObject(root); p.command = ["bash", "-c", "cp '" + path + "' '" + avatarPath + "' && notify-send 'Avatar' 'Profile picture updated'"]; p.running = true; } } } } }
    Component { id: setAvatarComp; Process { } }
}