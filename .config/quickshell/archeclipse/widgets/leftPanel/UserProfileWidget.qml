import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services

// User Profile widget - full port of UserProfile.tsx + Supabase.class.tsx
// Auth via magic link -> local Python callback server writes session.json ->
// profile fetched from Supabase REST. Settings sync upload/download to
// ~/.cache/quickshell/settings/settings.json (quickshell-local).
// minimal mode (for the lockscreen overlay): shows only avatar + username
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""
    property bool minimal: false

    // --- Config (values live in the Supabase singleton; keep these aliases
    // so the rest of the widget is untouched) ---
    readonly property string supabaseUrl: Supabase.url
    readonly property string supabaseKey: Supabase.anonKey
    readonly property string homeDir: Supabase.homeDir
    // scripts/auth-server-callback.py owns session.json (SESSION_PATH in the
    // script) — no legacy paths. shell.qml ensures the auth
    // cache dir exists at startup.
    readonly property string authServerScript: homeDir + "/.config/quickshell/archeclipse/scripts/auth-server-callback.py"
    readonly property string authSessionPath: Supabase.authSessionPath
    readonly property string authLogPath: "/tmp/qs-auth-server.log"
    readonly property string settingsPath: homeDir + "/.cache/quickshell/settings/settings.json"
    readonly property string settingsMetaPath: homeDir + "/.cache/quickshell/settings/settings-sync.json"
    readonly property string avatarPath: homeDir + "/.face.icon"
    // Cache-busting avatar source: same path strings don't refetch after
    // cp/curl rewrites ~/.face.icon, so toggle through "" to force reload.
    property string avatarSrc: homeDir + "/.face.icon"
    function reloadAvatar() {
        root.avatarSrc = "";
        Qt.callLater(() => {
            root.avatarSrc = root.avatarPath;
        });
    }

    // --- State ---
    property var profile: null
    property string progressStatus: "idle"
    property string progressText: "Not signed in"
    property bool isSyncing: false
    property bool isRefreshing: false
    property string lastSyncAt: "Never"
    property string lastSyncResult: "-"
    property string lastRemoteUpdatedAt: "Never"
    property var _cachedSession: null
    // Magic-link button confirmation (flips the label on success)
    property string magicState: "Send Magic Link"

    // Per-API bookmark counts from Settings.booru.bookmarks
    // (each item stores api.value).
    readonly property var booruApis: [
        {
            name: "Danbooru",
            value: "danbooru"
        },
        {
            name: "Gelbooru",
            value: "gelbooru"
        },
        {
            name: "Safebooru",
            value: "safebooru"
        },
    ]
    readonly property var booruFavoriteCounts: {
        const counts = {
            danbooru: 0,
            gelbooru: 0,
            safebooru: 0
        };
        const marks = Settings.booru ? Settings.booru.bookmarks : null;
        if (marks)
            for (const b of marks) {
                const v = b && b.api ? b.api.value : null;
                if (v && typeof counts[v] === "number")
                    counts[v] += 1;
            }
        return counts;
    }
    // Fastfetch pin count.
    readonly property int pinnedCount: {
        const pins = Settings.booru ? Settings.booru.pins : null;
        return pins ? pins.length : 0;
    }

    property QtObject fileWatch: QtObject {
        id: _fw
    }
    property int activeTab: 0

    // Change-gated polling: poll the two LOCAL files and only refetch
    // the profile when session.json actually changed — no network on ticks.
    property string _lastSessionText: ""
    property int _netAttempts: 0

    // Shell-lifetime cache: LeftIsland is destroyed/recreated on every
    // open/close (Bar Loader swap). Restore instantly from UserProfileState
    // and skip the net gate + REST fetch — a single cheap local `cat` of
    // session.json refetches only if the session actually changed elsewhere.
    function saveToCache() {
        UserProfileState.profile = root.profile;
        UserProfileState.cachedSession = root._cachedSession;
        UserProfileState.cachedUid = root._cachedUid;
        UserProfileState.cachedEmail = root._cachedEmail;
        UserProfileState.lastSessionText = root._lastSessionText;
        UserProfileState.lastSyncAt = root.lastSyncAt;
        UserProfileState.lastSyncResult = root.lastSyncResult;
        UserProfileState.lastRemoteUpdatedAt = root.lastRemoteUpdatedAt;
        UserProfileState.initialized = true;
    }
    function restoreFromCache() {
        root.profile = UserProfileState.profile;
        root._cachedSession = UserProfileState.cachedSession;
        root._cachedUid = UserProfileState.cachedUid;
        root._cachedEmail = UserProfileState.cachedEmail;
        root._lastSessionText = UserProfileState.lastSessionText;
        root.lastSyncAt = UserProfileState.lastSyncAt;
        root.lastSyncResult = UserProfileState.lastSyncResult;
        root.lastRemoteUpdatedAt = UserProfileState.lastRemoteUpdatedAt;
        if (!root.profile) {
            root.progressStatus = "idle";
            root.progressText = "Not signed in";
        } else {
            // Don't leave the initial "Not signed in" idle text under a
            // restored profile — mirror what a fresh fetch would show.
            root.progressStatus = "idle";
            const un = root.profile.username;
            root.progressText = un ? root.supporterLabel() : "Signed in, but profile not found";
        }
    }

    Component.onCompleted: {
        if (UserProfileState.initialized) {
            restoreFromCache();
            // No usable profile cached (first load failed or was still in
            // flight, or signed state changed): retry with one load.
            // Signed-out this is local-only (cat → idle, no network).
            if (!root.profile) {
                root.loadProfile();
                pollTimer.restart();
                return;
            }
            // Local avatar file only — no network.
            root.reloadAvatar();
            pollTimer.restart();
            // One-shot local session check: onPollSession refetches only
            // when the file text differs from the cached one.
            const p = pollSessionComp.createObject(root);
            p.command = ["cat", root.authSessionPath];
            p.running = true;
            return;
        }
        applySettingsSyncMeta();
        // On-demand auth server: NOT started here. sendMagicLink() starts
        // the Quickshell-managed listener, and it stops itself once
        // session.json appears (or after a timeout). This avoids a stale
        // detached server dying across reboots and leaving /callback dead.
        _netTimer.restart();
    }
    Component.onDestruction: {
        // Never clobber a good cached profile with a transient failure:
        // if this instance never got a profile but the cache has one and
        // the session didn't change, keep the cache.
        if (!root.profile && UserProfileState.profile && root._lastSessionText === UserProfileState.lastSessionText)
            return;
        root.saveToCache();
    }

    // Network gate (wait up to 30s): check the Supabase
    // health endpoint, 3s apart, max 10 tries, then proceed regardless.
    property Timer _netTimer: Timer {
        interval: 3000
        repeat: false
        running: false
        onTriggered: {
            const p = netGateComp.createObject(root);
            p.command = ["curl", "-sS", "-o", "/dev/null", "--max-time", "5", root.supabaseUrl + "/auth/v1/health"];
            p.running = true;
        }
    }

    function onNetGateDone(ok) {
        if (ok || root._netAttempts >= 9) {
            root.loadProfile();
            pollTimer.restart();
            return;
        }
        root._netAttempts++;
        _netTimer.restart();
    }

    property Timer pollTimer: Timer {
        interval: 10000
        repeat: true
        running: false
        onTriggered: {
            const p = pollSessionComp.createObject(root);
            p.command = ["cat", root.authSessionPath];
            p.running = true;
            root.applySettingsSyncMeta();
        }
    }

    function onPollSession(text) {
        if (text !== root._lastSessionText) {
            root._lastSessionText = text;
            root.saveToCache();
            root.loadProfile();
        }
    }

    // ===== PROFILE =====
    function loadProfile() {
        const p = loadAuthComp.createObject(root);
        p.command = ["cat", root.authSessionPath];
        p.running = true;
    }

    function lookupUserId() {
        return root._cachedUid || _cachedSession?.user?.id || _cachedSession?.id || "";
    }
    // UID resolved from /auth/v1/user (step 1).
    // session.json from auth-server-callback.py only carries tokens — no id —
    // so the profile query cannot reuse lookupUserId() synchronously.
    property string _cachedUid: ""
    property string _cachedEmail: ""
    // Auto-refresh: Supabase access_tokens expire after 1h (expires_in=3600).
    // Without this every API call fails with "JWT expired" ~1h after login,
    // which surfaced as "profile not found" / "No settings found" and forced
    // a full magic-link re-login. We refresh via grant_type=refresh_token
    // and retry the original request once.
    property bool _refreshing: false
    property string _retryAfterRefresh: ""

    function tokenNeedsRefresh() {
        const s = root._cachedSession;
        if (!s?.access_token)
            return false;
        const exp = Number(s.expires_at || 0);
        if (!exp)
            return false;
        // Refresh 60s before expiry; expires_at is unix seconds.
        return Date.now() / 1000 >= exp - 60;
    }

    function isAuthErrorText(text) {
        const t = String(text || "");
        return t.indexOf("JWT expired") >= 0 || t.indexOf("bad_jwt") >= 0 || t.indexOf("invalid JWT") >= 0 || t.indexOf("PGRST303") >= 0 || t.indexOf("JWT expired") >= 0 || t.indexOf("expired") >= 0 && t.indexOf("token") >= 0;
    }

    function doRefresh(reason) {
        if (root._refreshing)
            return;
        const rt = root._cachedSession?.refresh_token || "";
        if (!rt) {
            root.progressStatus = "error";
            root.progressText = "Session expired — please sign in again";
            Notifications.notify({
                summary: "Session expired",
                body: "Please send a new magic link to sign in again."
            });
            return;
        }
        root._refreshing = true;
        root._retryAfterRefresh = reason || "";
        root.progressStatus = "loading";
        root.progressText = "Refreshing session...";
        const p = refreshTokenComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -X POST -H 'apikey: " + supabaseKey + "' -H 'Content-Type: application/json' -d " + JSON.stringify(JSON.stringify({
                refresh_token: rt
            })) + " " + JSON.stringify(supabaseUrl + "/auth/v1/token?grant_type=refresh_token")];
        p.running = true;
    }

    function onRefreshFinished(text) {
        root._refreshing = false;
        let r = null;
        try {
            r = text ? JSON.parse(text) : null;
        } catch (e) {
            r = null;
        }
        if (!r?.access_token) {
            const reason = root._retryAfterRefresh;
            root._retryAfterRefresh = "";
            root.progressStatus = "error";
            root.progressText = "Session expired — please sign in again";
            Notifications.notify({
                summary: "Session expired",
                body: "Refresh failed. Please send a new magic link."
            });
            return;
        }
        // Merge refreshed tokens into the cached session, preserving the
        // embedded user (session.json from older saves carries it) and the
        // magic-link type marker.
        const prev = root._cachedSession || {};
        root._cachedSession = {
            access_token: r.access_token,
            refresh_token: r.refresh_token || prev.refresh_token || "",
            expires_at: r.expires_at || prev.expires_at || "",
            expires_in: r.expires_in || prev.expires_in || 3600,
            token_type: r.token_type || prev.token_type || "bearer",
            type: prev.type || "magiclink",
            user: r.user || prev.user || undefined,
            email: r.user?.email || prev.email || undefined
        };
        // Persist so the next shell start / poll sees the fresh token.
        const sp = refreshSaveComp.createObject(root);
        sp.command = ["bash", "-c", "mkdir -p " + JSON.stringify(root.authSessionPath.split("/").slice(0, -1).join("/")) + " && cat > " + JSON.stringify(root.authSessionPath) + " <<'EOF'\n" + JSON.stringify(root._cachedSession, null, 2) + "\nEOF"];
        sp.running = true;
        const reason = root._retryAfterRefresh;
        root._retryAfterRefresh = "";
        root.saveToCache();
        if (reason === "download" || reason === "upload") {
            root.isSyncing = false;
            root.syncSettings(reason);
        } else {
            // Profile path: re-run from the top so uid resolution retries
            // with the fresh token (handles both /user and profile steps).
            root.loadProfile();
        }
    }

    function handleSessionJson(text) {
        root._lastSessionText = text || "";
        let session = null;
        try {
            session = text ? JSON.parse(text) : null;
        } catch (e) {
            session = null;
        }
        root._cachedSession = session;
        if (!session?.access_token) {
            root.profile = null;
            root._cachedUid = "";
            root._cachedEmail = "";
            root.progressStatus = "idle";
            root.progressText = "Not signed in";
            root.isRefreshing = false;
            root.saveToCache();
            return;
        }
        // Session arrived (via /save POST or manual paste) — the on-demand
        // listener has done its job, stop it so it only runs when needed.
        root.stopAuthServer("session saved");
        // Proactive refresh: don't burn a failing /user call when we can
        // see from expires_at that the token is already stale.
        if (root.tokenNeedsRefresh()) {
            root.progressStatus = "loading";
            root.progressText = "Refreshing session...";
            root.doRefresh("profile");
            return;
        }
        // Fast path: session.json already embeds the user (older saves) —
        // skip straight to the profile query.
        const embeddedId = session?.user?.id ?? session?.id ?? "";
        if (embeddedId) {
            root._cachedUid = embeddedId;
            root._cachedEmail = session?.user?.email ?? session?.email ?? "";
            root.saveToCache();
            root.fetchUserProfile(embeddedId);
            return;
        }
        root.progressStatus = "loading";
        root.progressText = "Loading profile...";
        // Step 1: resolve the uid
        // from /auth/v1/user first — the profile table needs id=eq.<uid>.
        const p = fetchUserComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' '" + supabaseUrl + "/auth/v1/user'"];
        p.running = true;
    }

    function onUserFetched(text) {
        let user = null;
        try {
            user = text ? JSON.parse(text) : null;
        } catch (e) {
            user = null;
        }
        if (!user?.id) {
            // Expired access_token returns {"code":403,...,"msg":"...expired"}
            // here — refresh once and retry instead of looking signed out.
            if (!root._refreshing && root.isAuthErrorText(text)) {
                root.doRefresh("profile");
                return;
            }
            root.profile = null;
            root.progressStatus = "error";
            root.progressText = "Signed in, but profile not found";
            root.isRefreshing = false;
            return;
        }
        root._cachedUid = user.id;
        root._cachedEmail = user.email ?? "";
        root.saveToCache();
        root.fetchUserProfile(user.id);
    }

    function fetchUserProfile(uid) {
        root.progressStatus = "loading";
        root.progressText = "Loading profile...";
        const session = root._cachedSession;
        if (!session?.access_token)
            return;
        const p = fetchProfileComp.createObject(root);
        // NOTE: user_profiles has no is_supporter column — entitlement is the
        // presence of a `supporters` row (see checkSupporter below).
        p.command = ["bash", "-c", "curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' '" + supabaseUrl + "/rest/v1/user_profiles?select=id,username,avatar&id=eq." + encodeURIComponent(uid) + "'"];
        p.running = true;
    }

    // ===== SUPPORTER STATE =====
    // Authoritative state lives in Supabase: a row in `supporters` means the
    // user is a supporter. That row is written only by the verified-payment
    // DB trigger — this query is read-only and can never grant status.
    function supporterLabel() {
        if (!root.profile)
            return "Not signed in";
        const name = root.profile.username ?? "No username";
        if (root.profile.is_supporter === true)
            return name + " \u2022 Supporter";
        if (root.profile.is_supporter === false)
            return name + " \u2022 Member";
        return name + " \u2022 \u2026";
    }
    function checkSupporter() {
        const session = root._cachedSession;
        const uid = lookupUserId();
        if (!session?.access_token || !uid)
            return;
        const p = supporterCheckComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' '" + supabaseUrl + "/rest/v1/supporters?select=id&id=eq." + encodeURIComponent(uid) + "'"];
        p.running = true;
    }
    function onSupporterChecked(text) {
        if (!root._refreshing && root.isAuthErrorText(text)) {
            root.doRefresh("profile");
            return;
        }
        let rows = null;
        try {
            rows = text ? JSON.parse(text) : null;
        } catch (e) {
            rows = null;
        }
        if (!Array.isArray(rows) || !root.profile)
            return;
        const supported = rows.length > 0;
        if (root.profile.is_supporter === supported)
            return;
        root.profile = {
            id: root.profile.id,
            email: root.profile.email,
            username: root.profile.username,
            avatar: root.profile.avatar,
            is_supporter: supported
        };
        root.saveToCache();
        root.progressStatus = "idle";
        root.progressText = root.supporterLabel();
    }

    // ===== MAGIC LINK =====
    // Quickshell-managed on-demand listener: authServerProc (below) runs
    // scripts/auth-server-callback.py as a child Process while
    // authServerActive is true — no nohup/detach, so Quickshell owns its
    // lifetime and it dies with the shell instead of going stale.
    property bool authServerActive: false
    property string authServerStatus: "stopped"
    // Local-only fallback when the browser can't reach the listener (server
    // down, link opened on another machine, etc.): paste the full
    // http://127.0.0.1:53100/callback#... URL and we parse the #fragment
    // in pure QML — no HTTP server involved at all.
    property string callbackUrlText: ""
    function sendMagicLink(email) {
        if (!email || email.trim() === "") {
            Notifications.notify({
                summary: "Email",
                body: "Enter a valid email"
            });
            return;
        }
        // Start the listener first so it is up by the time the user
        // opens the email link (server must be listening for /callback).
        startAuthServer();
        const p = magicLinkComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -X POST -H 'Content-Type: application/json' -H 'apikey: " + supabaseKey + "' -d '" + JSON.stringify({
                email: email.trim(),
                options: {
                    shouldCreateUser: true,
                    emailRedirectTo: "http://127.0.0.1:53100/callback"
                }
            }) + "' '" + supabaseUrl + "/auth/v1/otp'"];
        p.running = true;
    }

    function startAuthServer() {
        // Kill any stale detached server (legacy nohup one holding the port
        // or a previous crash), then the onExited handler flips
        // authServerActive=true which spawns the managed child.
        // (The #fragment never reaches the server — the /callback JS must
        // POST it to /save, which requires the server to be listening.)
        if (root.authServerActive)
            return;
        root.authServerStatus = "starting";
        const p = authServerKickComp.createObject(root);
        p.command = ["bash", "-c", "pkill -f '[a]uth-server-callback\\.py' || true"];
        p.running = true;
    }

    function stopAuthServer(reason) {
        if (!root.authServerActive && root.authServerStatus !== "starting")
            return;
        root.authServerActive = false;
        root.authServerStatus = "stopped";
        authServerTimeout.stop();
    }

    // Server-less fallback: parse the pasted callback URL's #fragment
    // (browsers never send it to any server) and write session.json
    // directly. Works even if the listener was never started.
    function importCallbackUrl(url) {
        const s = (url || "").trim();
        if (!s) {
            Notifications.notify({
                summary: "Auth",
                body: "Paste the callback URL first."
            });
            return;
        }
        const hashIdx = s.indexOf("#");
        const frag = hashIdx >= 0 ? s.slice(hashIdx + 1) : "";
        if (!frag || frag.indexOf("access_token=") < 0) {
            Notifications.notify({
                summary: "Invalid link",
                body: "That URL has no #access_token=… fragment."
            });
            return;
        }
        const params = {};
        for (const part of frag.split("&")) {
            const eq = part.indexOf("=");
            if (eq > 0)
                params[decodeURIComponent(part.slice(0, eq))] = decodeURIComponent(part.slice(eq + 1));
        }
        if (!params.access_token) {
            Notifications.notify({
                summary: "Invalid link",
                body: "Could not find access_token in the URL."
            });
            return;
        }
        // Stop the listener — we got the session without it.
        root.stopAuthServer("manual import");
        const session = {
            access_token: params.access_token || "",
            refresh_token: params.refresh_token || "",
            expires_at: params.expires_at || "",
            token_type: params.token_type || "bearer",
            type: params.type || "magiclink"
        };
        const p = manualSaveComp.createObject(root);
        p.command = ["bash", "-c", "mkdir -p " + JSON.stringify(root.authSessionPath.split("/").slice(0, -1).join("/")) + " && cat > " + JSON.stringify(root.authSessionPath) + " <<'EOF'\n" + JSON.stringify(session, null, 2) + "\nEOF"];
        p.running = true;
    }

    // ===== UPDATE PROFILE =====
    function updateProfile() {
        const session = _cachedSession;
        if (!session?.access_token) {
            Notifications.notify({
                summary: "Not signed in",
                body: "Please sign in to update profile."
            });
            return;
        }
        root.progressStatus = "loading";
        root.progressText = "Updating profile...";
        const uid = lookupUserId();
        const username = usernameField.text.trim() || homeDir.split("/").pop();
        const p = updateProfileComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -X PATCH -H 'Content-Type: application/json' -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' -H 'Prefer: return=representation' -d '" + JSON.stringify({
                username
            }) + "' '" + supabaseUrl + "/rest/v1/user_profiles?id=eq." + encodeURIComponent(uid) + "'"];
        p.running = true;
    }

    // ===== LOGOUT =====
    function logout() {
        logoutComp.createObject(root).running = true;
        root.profile = null;
        root._cachedSession = null;
        root._cachedUid = "";
        root._cachedEmail = "";
        root._lastSessionText = "";
        root.progressStatus = "idle";
        root.progressText = "Signed out";
        root.saveToCache();
        Notifications.notify({
            summary: "Signed out",
            body: "Your session has been cleared."
        });
    }

    // ===== SETTINGS SYNC =====
    function applySettingsSyncMeta() {
        const p = readMetaComp.createObject(root);
        p.command = ["cat", root.settingsMetaPath];
        p.running = true;
    }

    function formatTs(iso) {
        if (!iso)
            return "Never";
        const d = new Date(iso);
        if (isNaN(d.getTime()))
            return "Never";
        const p = n => n.toString().padStart(2, "0");
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + ":" + p(d.getMinutes());
    }

    function syncSettings(direction) {
        if (root.isSyncing)
            return;
        const session = _cachedSession;
        if (!session?.access_token) {
            Notifications.notify({
                summary: "Settings Sync",
                body: "Not signed in."
            });
            return;
        }
        // Proactive refresh: never send a visibly-expired token — that
        // failure used to surface as the misleading "No settings found".
        if (root.tokenNeedsRefresh()) {
            root.doRefresh(direction);
            return;
        }
        root.isSyncing = true;
        root.progressStatus = "loading";
        root.progressText = direction === "upload" ? "Uploading settings..." : "Downloading settings...";
        const uid = lookupUserId();
        if (!uid) {
            root.isSyncing = false;
            root.progressStatus = "error";
            root.progressText = "Refreshing session...";
            root.doRefresh(direction);
            return;
        }

        if (direction === "upload") {
            const settingsJson = readLocalSettings();
            // Never upload an empty stub — it would wipe the remote copy.
            if (!settingsJson || Object.keys(settingsJson).length === 0) {
                root.progressStatus = "error";
                root.progressText = "Upload refused: local settings empty";
                Notifications.notify({
                    summary: "Settings Sync",
                    body: "Local settings file is empty — refusing to overwrite the cloud copy."
                });
                return;
            }
            // Write the payload to a temp file and --data-binary it: inlining
            // the JSON in -d '<json>' breaks on any single quote inside the
            // settings (e.g. xal'atath) and always reported "Upload failed".
            const payload = JSON.stringify({
                id: uid,
                settings: settingsJson,
                updated_at: new Date().toISOString()
            });
            const p = syncUploadComp.createObject(root);
            p.command = ["bash", "-c", "cat > /tmp/qs-settings-upload.json <<'QSSETTINGSEOF'\n" + payload + "\nQSSETTINGSEOF\ncurl -sS -X POST -H 'Content-Type: application/json' -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' -H 'Prefer: resolution=merge-duplicates,return=representation' --data-binary @/tmp/qs-settings-upload.json '" + supabaseUrl + "/rest/v1/user_settings?on_conflict=id'"];
            p.running = true;
        } else {
            const p = syncDownloadComp.createObject(root);
            p.command = ["bash", "-c", "curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' '" + supabaseUrl + "/rest/v1/user_settings?select=id,settings,updated_at&id=eq." + encodeURIComponent(uid) + "'"];
            p.running = true;
        }
    }

    // Read the real on-disk
    // settings file — never {} (an empty upload would wipe the remote copy).
    function readLocalSettings() {
        return Settings.readLocalSettingsJson();
    }

    // ===== AVATAR =====
    // State carried across the convert -> upload -> patch -> fetch chain.
    property string _avatarSrc: ""
    property string _avatarUid: ""
    property string _avatarUploadPath: ""
    property string _avatarContentType: ""
    property string _avatarExt: ""

    function chooseAvatar() {
        const p = zenityComp.createObject(root);
        p.command = ["zenity", "--file-selection", "--title=Select Profile Picture", "--file-filter=Images (png, jpg, webp) | *.png *.jpg *.jpeg *.webp"];
        p.running = true;
    }

    function onAvatarPicked(path) {
        const clean = (path || "").trim();
        if (!clean)
            return;
        const ext = (clean.split(".").pop() || "").toLowerCase();
        const ctype = ext === "png" ? "image/png" : (ext === "jpg" || ext === "jpeg") ? "image/jpeg" : ext === "webp" ? "image/webp" : null;
        if (!ctype) {
            Notifications.notify({
                summary: "Invalid image",
                body: "Pick a PNG, JPG, or WebP file."
            });
            return;
        }
        const session = root._cachedSession;
        const uid = lookupUserId();
        // Not signed in: local-only copy.
        if (!session?.access_token || !uid) {
            root.progressStatus = "loading";
            root.progressText = "Updating local avatar...";
            Notifications.notify({
                summary: "Not signed in",
                body: "Updating local avatar only. Sign in to sync across devices."
            });
            root._avatarSrc = clean;
            const p = setAvatarComp.createObject(root);
            p.command = ["cp", clean, root.avatarPath];
            p.running = true;
            return;
        }
        root._avatarSrc = clean;
        root._avatarUid = uid;
        root._avatarContentType = ctype;
        root._avatarExt = ext === "jpeg" ? "jpg" : ext;
        root.progressStatus = "loading";
        root.progressText = "Uploading avatar...";
        // Convert non-JPEG via magick/convert;
        // failures fall back to the original file inside the chain step.
        if (ext === "jpg" || ext === "jpeg") {
            root._avatarUploadPath = clean;
            root.avatarUpload();
        } else {
            const p = avatarConvertComp.createObject(root);
            p.command = ["bash", "-c", "magick " + JSON.stringify(clean) + " " + JSON.stringify("/tmp/" + uid + "-avatar.jpg") + " || convert " + JSON.stringify(clean) + " " + JSON.stringify("/tmp/" + uid + "-avatar.jpg")];
            p.running = true;
        }
    }

    function onAvatarConverted(ok) {
        const tmp = "/tmp/" + root._avatarUid + "-avatar.jpg";
        if (ok) {
            root._avatarUploadPath = tmp;
            root._avatarContentType = "image/jpeg";
            root._avatarExt = "jpg";
        } else {
            Notifications.notify({
                summary: "Image conversion warning",
                body: "Conversion failed, uploading original file."
            });
            root._avatarUploadPath = root._avatarSrc;
        }
        root.avatarUpload();
    }

    function avatarUpload() {
        const p = avatarUploadComp.createObject(root);
        p.command = ["curl", "-sS", "-X", "PUT", "-H", "Content-Type: " + root._avatarContentType, "-H", "apikey: " + root.supabaseKey, "-H", "Authorization: Bearer " + (root._cachedSession?.access_token ?? ""), "-H", "x-upsert: true", "--data-binary", "@" + root._avatarUploadPath, root.supabaseUrl + "/storage/v1/object/avatars/" + root._avatarUid + "." + root._avatarExt];
        p.running = true;
    }

    function onAvatarUploaded(ok) {
        if (!ok) {
            root.progressStatus = "error";
            root.progressText = "Upload failed";
            Notifications.notify({
                summary: "Upload failed",
                body: "Failed to upload profile picture."
            });
            return;
        }
        const url = root.supabaseUrl + "/storage/v1/object/public/avatars/" + root._avatarUid + "." + root._avatarExt;
        root._avatarUrl = url;
        const p = avatarPatchComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -X PATCH -H 'Content-Type: application/json' -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + (root._cachedSession?.access_token ?? "") + "' -H 'Prefer: return=representation' -d " + JSON.stringify(JSON.stringify({
                avatar: url
            })) + " " + JSON.stringify(root.supabaseUrl + "/rest/v1/user_profiles?id=eq." + encodeURIComponent(root._avatarUid))];
        p.running = true;
    }
    property string _avatarUrl: ""

    function onAvatarPatched(ok) {
        if (!ok) {
            root.progressStatus = "error";
            root.progressText = "Upload failed";
            Notifications.notify({
                summary: "Upload failed",
                body: "Failed to update profile picture."
            });
            return;
        }
        // Sync the fresh avatar down to ~/.face.icon immediately
        // (keeps the UI truthful).
        const p = avatarFetchComp.createObject(root);
        p.command = ["curl", "-sS", "--max-time", "30", "-o", root.avatarPath, root._avatarUrl];
        p.running = true;
    }

    function onAvatarFetched(ok) {
        if (!ok) {
            Notifications.notify({
                summary: "Avatar sync failed",
                body: "Uploaded, but the local picture could not be refreshed — will retry on next refresh."
            });
            root.progressStatus = "error";
            root.progressText = "Avatar sync failed";
            return;
        }
        root.progressStatus = "success";
        root.progressText = "Avatar updated";
        Notifications.notify({
            summary: "Avatar updated",
            body: "Your profile picture has been uploaded."
        });
        root.avatarPathChanged();
        root.loadProfile();
    }

    function maskEmail(email) {
        if (!email)
            return "No email";
        const at = email.indexOf("@");
        if (at <= 0)
            return email;
        return email.slice(0, 1) + "***@" + email.slice(at + 1);
    }

    // ===== UI: MINIMAL MODE (avatar + 2em username on a pill) =====
    Item {
        id: minimalView
        anchors.fill: parent
        visible: root.minimal
        Column {
            anchors.centerIn: parent
            width: root.width
            spacing: 10
            Rectangle {
                // Centered manually: parent is a Column positioner,
                // which ignores anchors on children.
                x: (parent.width - width) / 2
                width: Math.min(root.width * 0.5, 140)
                height: Math.min(root.width * 0.5, 140)
                radius: width / 2
                clip: true
                AppImage {
                    id: minAvatarImg
                    anchors.fill: parent
                    source: root.avatarSrc

                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceActive
                    visible: minAvatarImg.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text: "\u{F007}"
                        font.pixelSize: 56
                        color: Theme.accent
                    }
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.profile?.username ?? "Not signed in"
                font.pixelSize: Theme.fontSize * 2
                font.bold: true
                color: Theme.fg
                elide: Text.ElideRight
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
            id: tabRow
            width: parent.width
            spacing: 6
            AppButton {
                width: (parent.width - 6) / 2
                implicitHeight: 30
                toggle: true
                checked: root.activeTab === 0
                outlined: true
                text: "Account"
                onClicked: root.activeTab = 0
            }
            AppButton {
                width: (parent.width - 6) / 2
                implicitHeight: 30
                toggle: true
                checked: root.activeTab === 1
                outlined: true
                text: "About"
                onClicked: root.activeTab = 1
            }
        }

        // Stack: Account | About (unanchored: StackLayout children
        // must not use anchors; height derives from the tab row above).
        StackLayout {
            width: parent.width
            height: parent.height - tabRow.height - fullView.spacing
            currentIndex: root.activeTab

            // Account tab (scrolls on narrow panels)
            SmoothFlickable {
                id: acctFlick
                width: parent.width
                height: parent.height
                contentWidth: width
                contentHeight: acctCol.height
                flickableDirection: Flickable.VerticalFlick
                clip: true
                Column {
                    id: acctCol
                    width: acctFlick.width
                    spacing: 10

                    // ── Identity card: avatar banner spanning the width ──
                    // Margins stay intact: the banner sizes explicitly off
                    // the padded column (width = card − margins), square via
                    // height: width — no edge anchors to overextend.
                    Rectangle {
                        width: parent.width
                        implicitHeight: cardCol.implicitHeight + 20
                        color: Theme.bg
                        radius: 8

                        Column {
                            id: cardCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                id: banner
                                width: parent.width
                                height: width
                                radius: Theme.radius
                                color: Theme.bg
                                clip: true
                                AppImage {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: root.avatarSrc
                                    visible: status === Image.Ready
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.surfaceActive
                                    visible: avatarImg.status !== Image.Ready
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u{F007}"
                                        font.pixelSize: 48
                                        color: Theme.accent
                                    }
                                }
                                MouseArea {
                                    id: avatarMa
                                    anchors.fill: parent
                                    onClicked: root.chooseAvatar()
                                    AppTooltip {
                                        visible: avatarMa.containsMouse
                                        text: "Click to set up profile picture"
                                    }
                                }
                            }

                            Column {
                                id: idCol
                                width: parent.width
                                spacing: 6
                                AppTextField {
                                    id: usernameField
                                    width: parent.width
                                    cornerRadius: 4
                                    placeholderText: homeDir.split("/").pop()
                                    text: root.profile?.username ?? ""
                                    horizontalAlignment: TextInput.AlignHCenter
                                    onAccepted: root.updateProfile()
                                    // Username entry tooltip
                                    AppTooltip {
                                        visible: usernameField.hovered
                                        text: "Click to edit username"
                                    }
                                }
                                Flow {
                                    width: parent.width
                                    spacing: 5
                                    Label {
                                        text: root.maskEmail(root.profile?.email ?? "")
                                        font.pixelSize: Theme.fontSize - 1
                                        color: Theme.fgDim
                                    }
                                    Label {
                                        text: "|"
                                        font.pixelSize: Theme.fontSize - 1
                                        color: Theme.fgDim
                                    }
                                    Label {
                                        text: "Supporter: " + (root.profile?.is_supporter === true ? "Yes" : root.profile?.is_supporter === false ? "No" : "…")
                                        font.pixelSize: Theme.fontSize - 1
                                        color: Theme.fgDim
                                    }
                                }
                                AppProgress {
                                    width: parent.width
                                    // Plain Column ignores implicitHeight — bind it explicitly.
                                    height: implicitHeight
                                    status: root.progressStatus
                                    variant: "inline"
                                    loadingText: root.progressText !== "" ? root.progressText : "Working..."
                                    errorText: root.progressText !== "" ? root.progressText : "Error — see notification"
                                    successText: root.progressText !== "" ? root.progressText : "Ready"
                                    idleText: root.progressText
                                    showSuccess: true
                                    showIdle: true
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        visible: !!root.profile
                        AppButton {
                            width: (parent.width - 16) / 3
                            text: "Update"
                            onClicked: root.updateProfile()
                        }
                        AppButton {
                            width: (parent.width - 16) / 3
                            text: "Refresh"
                            tooltipText: "Refresh profile"
                            enabled: !root.isRefreshing
                            // loadProfile is awaited in try/finally — the flag
                            // clears when the fetch completes (see fetchProfileComp
                            // + handleSessionJson), not synchronously here.
                            onClicked: {
                                if (root.isRefreshing)
                                    return;
                                root.isRefreshing = true;
                                root.progressStatus = "loading";
                                root.progressText = "Refreshing profile...";
                                root.loadProfile();
                            }
                        }
                        AppButton {
                            width: (parent.width - 16) / 3
                            text: "Logout"
                            onClicked: root.logout()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: syncCol.implicitHeight + 20
                        visible: !!root.profile
                        color: Theme.bg
                        radius: 8

                        Column {
                            id: syncCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 8
                            Label {
                                text: "Settings Sync"
                                font.pixelSize: Theme.fontSize + 2
                                font.bold: true
                                color: Theme.fg
                            }
                            Row {
                                width: parent.width
                                spacing: 8
                                AppButton {
                                    width: (parent.width - 8) / 2
                                    text: root.isSyncing ? "Downloading..." : "Download"
                                    enabled: !root.isSyncing
                                    tooltipText: "Download settings from cloud"
                                    onClicked: root.syncSettings("download")
                                }
                                AppButton {
                                    width: (parent.width - 8) / 2
                                    text: root.isSyncing ? "Uploading..." : "Upload"
                                    enabled: !root.isSyncing
                                    tooltipText: "Upload settings to cloud"
                                    onClicked: root.syncSettings("upload")
                                }
                            }
                            Label {
                                width: parent.width
                                text: "Last sync: " + root.lastSyncAt
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fgDim
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                text: "Last result: " + root.lastSyncResult
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fgDim
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                text: "Remote updated: " + root.lastRemoteUpdatedAt
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fgDim
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Favorites + pins side by side.
                    Row {
                        width: parent.width
                        spacing: 10
                        visible: !!root.profile
                        Rectangle {
                            width: (parent.width - 10) / 2
                            implicitHeight: favCol.implicitHeight + 20
                            color: Theme.bg
                            radius: 8

                            Column {
                                id: favCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                spacing: 5
                                Label {
                                    text: "Booru Favorites"
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    color: Theme.fg
                                }
                                Repeater {
                                    model: root.booruApis
                                    delegate: Row {
                                        width: parent.width
                                        spacing: 5
                                        Label {
                                            width: parent.width - 32
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSize - 1
                                            color: Theme.fg
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            width: 27
                                            horizontalAlignment: Text.AlignRight
                                            text: root.profile ? String(root.booruFavoriteCounts[modelData.value] ?? 0) : ""
                                            font.pixelSize: Theme.fontSize - 1
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: (parent.width - 10) / 2
                            implicitHeight: pinCol.implicitHeight + 20
                            color: Theme.bg
                            radius: 8

                            Column {
                                id: pinCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                spacing: 5
                                Label {
                                    text: "Pinned Images"
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    color: Theme.fg
                                }
                                Label {
                                    width: parent.width
                                    text: "Fastfetch cache"
                                    font.pixelSize: Theme.fontSize - 1
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }
                                Label {
                                    width: parent.width
                                    text: root.profile ? String(root.pinnedCount) : ""
                                    font.pixelSize: Theme.fontSize + 2
                                    font.bold: true
                                    color: Theme.accent
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: signCol.implicitHeight + 20
                        visible: !root.profile
                        color: Theme.bg
                        radius: 8

                        Column {
                            id: signCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10
                            Label {
                                text: "Sign in to sync"
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: true
                                color: Theme.fg
                            }
                            Label {
                                width: parent.width
                                text: "\u2022 Profile picture\n\u2022 Settings\n\u2022 More to come"
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fgDim
                                wrapMode: Text.WordWrap
                            }
                            AppTextField {
                                id: emailField
                                width: parent.width
                                cornerRadius: 4
                                placeholderText: "you@example.com"
                                text: ""
                                onAccepted: root.sendMagicLink(emailField.text)
                                onTextChanged: {
                                    if (root.magicState !== "Send Magic Link")
                                        root.magicState = "Send Magic Link";
                                }
                            }
                            AppButton {
                                text: root.magicState
                                width: parent.width
                                enabled: emailField.text.trim().length > 0
                                onClicked: root.sendMagicLink(emailField.text)
                            }
                            Label {
                                width: parent.width
                                text: root.authServerActive ? "Listener: running on :53100 — open the email link now." : root.authServerStatus === "error" ? "Listener failed — paste the link below instead." : "Listener: idle (starts when you send a link)."
                                font.pixelSize: Theme.fontSize - 2
                                color: Theme.fgDim
                                wrapMode: Text.WordWrap
                            }
                            AppTextField {
                                id: callbackField
                                width: parent.width
                                cornerRadius: 4
                                placeholderText: "Paste callback URL here if the link fails…"
                                onTextChanged: root.callbackUrlText = text
                                onAccepted: root.importCallbackUrl(text)
                            }
                            AppButton {
                                text: "Import Pasted Link"
                                width: parent.width
                                enabled: root.callbackUrlText.trim().length > 0
                                outlined: true
                                onClicked: root.importCallbackUrl(callbackField.text)
                            }
                        }
                    }
                }
            }

            // About tab (StackLayout auto-sizes children: no anchors here)
            GeneralTab {}
        }
    }

    // Hidden Process components for async operations (wrapped in Component for createObject).
    // Exit-code rule: onStreamFinished parses payloads; onExited with a
    // non-zero code overrides to the error state (curl -sS still exits 0 on
    // HTTP errors only when -f is absent — network/DNS failures exit non-zero).
    Component {
        id: netGateComp
        Process {
            onExited: code => root.onNetGateDone(code === 0)
        }
    }
    Component {
        id: pollSessionComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onPollSession(text)
            }
        }
    }
    Component {
        id: loadAuthComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.handleSessionJson(text)
            }
        }
    }
    Component {
        id: fetchUserComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onUserFetched(text)
            }
            onExited: code => {
                if (code !== 0 && !root.profile) {
                    root.progressStatus = "error";
                    root.progressText = "Profile fetch failed";
                    root.isRefreshing = false;
                }
            }
        }
    }
    Component {
        id: fetchProfileComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const raw = text.trim();
                        // Expired token returns an error object, not an array —
                        // refresh once instead of reporting "not found".
                        if (!root._refreshing && root.isAuthErrorText(raw)) {
                            root.doRefresh("profile");
                            return;
                        }
                        const prof = JSON.parse(raw);
                        if (prof?.[0]) {
                            root.profile = {
                                id: root._cachedUid,
                                email: root._cachedEmail,
                                username: prof[0].username,
                                avatar: prof[0].avatar,
                                // Resolved by checkSupporter() below — never
                                // trust a profile-column value here.
                                is_supporter: null
                            };
                            root.saveToCache();
                            root.progressStatus = "idle";
                            root.progressText = root.supporterLabel();
                            // Sync avatar to ~/.face.icon on every load:
                            // silent download, notify only on failure.
                            if (prof[0].avatar)
                                root.syncAvatarSilent(prof[0].avatar);
                            root.checkSupporter();
                        } else {
                            // Fall back to a user-only profile when the
                            // user_profiles row is missing — stay signed in.
                            if (root._cachedUid) {
                                root.profile = {
                                    id: root._cachedUid,
                                    email: root._cachedEmail,
                                    username: null,
                                    avatar: null,
                                    is_supporter: null
                                };
                                root.saveToCache();
                                root.progressStatus = "idle";
                                root.progressText = "Signed in, but profile not found";
                                root.checkSupporter();
                            } else {
                                root.profile = null;
                                root.progressStatus = "error";
                                root.progressText = "Profile not found";
                                root.saveToCache();
                            }
                        }
                    } catch (e) {
                        root.profile = null;
                        root.progressStatus = "error";
                        root.progressText = "Failed to parse profile";
                    }
                }
            }
            onExited: code => {
                root.isRefreshing = false;
                if (code !== 0) {
                    root.progressStatus = "error";
                    root.progressText = root.profile ? "Refresh failed" : "Profile fetch failed";
                }
            }
        }
    }
    Component {
        id: supporterCheckComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onSupporterChecked(text)
            }
            onExited: code => {
            }
        }
    }
    Component {
        id: magicLinkComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const r = JSON.parse(text);
                        if (r.error) {
                            Notifications.notify({
                                summary: "Error",
                                body: r.error
                            });
                        } else {
                            root.magicState = "Check email...";
                            Notifications.notify({
                                summary: "Magic link sent",
                                body: "Check your email and open the link to complete sign-in."
                            });
                        }
                    } catch (e) {
                        Notifications.notify({
                            summary: "Error",
                            body: "Failed to send magic link"
                        });
                    }
                }
            }
        }
    }
    // On-demand listener: child of the widget, running only while
    // authServerActive. stdout goes to the log file for debugging.
    Process {
        id: authServerProc
        command: ["bash", "-c", "exec python3 " + JSON.stringify(root.authServerScript) + " >>" + JSON.stringify(root.authLogPath) + " 2>&1"]
        running: root.authServerActive
        onStarted: {
            root.authServerStatus = "running";
            authServerTimeout.restart();
        }
        onExited: code => {
            if (root.authServerActive) {
                // Crashed or port busy while still wanted — surface it.
                root.authServerActive = false;
                root.authServerStatus = "error";
                authServerTimeout.stop();
                Notifications.notify({
                    summary: "Auth server failed",
                    body: "Listener exited (code " + code + "). Paste the callback URL below instead — no server needed."
                });
            }
        }
    }
    // Kills stale detached servers, then hands off to authServerProc.
    Component {
        id: authServerKickComp
        Process {
            onExited: code => {
                root.authServerActive = true;
            }
        }
    }
    // Shows listener state in the sign-in card.
    Timer {
        id: authServerTimeout
        interval: 15 * 60 * 1000
        repeat: false
        running: false
        onTriggered: {
            root.stopAuthServer("15min timeout");
            Notifications.notify({
                summary: "Auth server stopped",
                body: "No sign-in completed in 15 minutes. Send a new magic link to restart it."
            });
        }
    }
    // Manual paste fallback writer (importCallbackUrl).
    Component {
        id: manualSaveComp
        Process {
            onExited: code => {
                if (code !== 0) {
                    Notifications.notify({
                        summary: "Auth",
                        body: "Could not write session file."
                    });
                    return;
                }
                root.callbackUrlText = "";
                callbackField.text = "";
                Notifications.notify({
                    summary: "Signed in",
                    body: "Session imported from the pasted link."
                });
                root.loadProfile();
            }
        }
    }
    Component {
        id: updateProfileComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const r = JSON.parse(text);
                        if (r?.[0]?.username) {
                            root.progressStatus = "success";
                            root.progressText = "Profile updated";
                            Notifications.notify({
                                summary: "Profile updated",
                                body: "Your profile has been updated successfully."
                            });
                            root.loadProfile();
                        } else {
                            root.progressStatus = "error";
                            root.progressText = "Update failed";
                            Notifications.notify({
                                summary: "Update failed",
                                body: "Failed to update profile."
                            });
                        }
                    } catch (e) {
                        root.progressStatus = "error";
                        root.progressText = "Update failed";
                        Notifications.notify({
                            summary: "Update failed",
                            body: "Failed to update profile."
                        });
                    }
                }
            }
        }
    }
    Component {
        id: logoutComp
        Process {
            command: ["rm", "-f", root.authSessionPath]
        }
    }
    // SettingsSyncMeta is camelCase {lastSyncAt, lastDirection,
    // lastRemoteUpdatedAt}; direction maps to human labels.
    Component {
        id: readMetaComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const m = JSON.parse(text);
                        root.lastSyncAt = m?.lastSyncAt ? root.formatTs(m.lastSyncAt) : "Never";
                        const d = m?.lastDirection;
                        root.lastSyncResult = !d ? "-" : d === "noop" ? "Up to date" : d === "download" ? "Downloaded" : "Uploaded";
                        root.lastRemoteUpdatedAt = m?.lastRemoteUpdatedAt ? root.formatTs(m.lastRemoteUpdatedAt) : "Never";
                        root.saveToCache();
                    } catch (e) {
                        root.lastSyncAt = "Never";
                        root.lastSyncResult = "-";
                        root.lastRemoteUpdatedAt = "Never";
                    }
                }
            }
        }
    }
    function writeSyncMeta(direction, remoteUpdatedAt) {
        const p = metaWriteComp.createObject(root);
        p.command = ["bash", "-c", "cat > " + JSON.stringify(root.settingsMetaPath) + " <<'EOF'\n" + JSON.stringify({
                lastSyncAt: new Date().toISOString(),
                lastDirection: direction,
                lastRemoteUpdatedAt: remoteUpdatedAt || null
            }, null, 2) + "\nEOF"];
        p.running = true;
    }
    Component {
        id: syncUploadComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const r = JSON.parse(text);
                        root._syncOut = JSON.stringify(r);
                    } catch (e) {
                        root._syncOut = "";
                    }
                }
            }
            onExited: code => {
                root.isSyncing = false;
                if (code !== 0 || !root._syncOut) {
                    root.progressStatus = "error";
                    root.progressText = "Upload failed";
                    Notifications.notify({
                        summary: "Settings Sync",
                        body: "Upload failed."
                    });
                    return;
                }
                try {
                    if (!root._refreshing && root.isAuthErrorText(root._syncOut)) {
                        root.doRefresh("upload");
                        return;
                    }
                    const r = JSON.parse(root._syncOut);
                    // PostgREST errors come back as {message, code, ...} with
                    // curl exit 0 — surface them instead of fake success.
                    if (r?.message || r?.msg || r?.error) {
                        root.progressStatus = "error";
                        root.progressText = "Upload failed: " + (r.message || r.msg || r.error);
                        Notifications.notify({
                            summary: "Settings Sync",
                            body: "Upload failed: " + (r.message || r.msg || r.error)
                        });
                        return;
                    }
                    const updated = r?.updated_at ?? (Array.isArray(r) ? r[0]?.updated_at : null);
                    root.writeSyncMeta("upload", updated);
                    root.progressStatus = "success";
                    root.progressText = "Settings uploaded";
                    Notifications.notify({
                        summary: "Settings Sync",
                        body: "Uploaded to cloud"
                    });
                    root.applySettingsSyncMeta();
                } catch (e) {
                    root.progressStatus = "error";
                    root.progressText = "Upload failed";
                    Notifications.notify({
                        summary: "Settings Sync",
                        body: "Upload failed."
                    });
                }
            }
        }
    }
    property string _syncOut: ""
    Component {
        id: syncDownloadComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    root._syncOut = text;
                }
            }
            onExited: code => {
                root.isSyncing = false;
                if (code !== 0) {
                    root.progressStatus = "error";
                    root.progressText = "Download failed";
                    Notifications.notify({
                        summary: "Settings Sync",
                        body: "Download failed."
                    });
                    return;
                }
                try {
                    // Auth failure looks like {"message":"JWT expired"} — that
                    // is NOT "no settings", it just needs a token refresh.
                    if (!root._refreshing && root.isAuthErrorText(root._syncOut)) {
                        root.doRefresh("download");
                        return;
                    }
                    const r = JSON.parse(root._syncOut);
                    if (r?.[0]?.settings) {
                        const p = writeSettingsComp.createObject(root);
                        p.command = ["bash", "-c", "cat > " + root.settingsPath + " <<'EOF'\n" + JSON.stringify(r[0].settings, null, 2) + "\nEOF"];
                        p.running = true;
                        root.writeSyncMeta("download", r[0].updated_at);
                        root.progressStatus = "success";
                        root.progressText = "Settings downloaded";
                        Notifications.notify({
                            summary: "Settings Sync",
                            body: "Downloaded from cloud"
                        });
                        root.applySettingsSyncMeta();
                    } else {
                        root.isSyncing = false;
                        root.progressStatus = "error";
                        root.progressText = "No settings found — upload first";
                        Notifications.notify({
                            summary: "Settings Sync",
                            body: "No remote settings for this account yet. Press Upload on the device that has your settings, then Download here."
                        });
                    }
                } catch (e) {
                    root.progressStatus = "error";
                    root.progressText = "Download failed";
                    Notifications.notify({
                        summary: "Settings Sync",
                        body: "Download failed."
                    });
                }
            }
        }
    }
    Component {
        id: refreshTokenComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onRefreshFinished(text)
            }
            onExited: code => {
                if (code !== 0 && root._refreshing) {
                    root._refreshing = false;
                    root._retryAfterRefresh = "";
                    root.isSyncing = false;
                    root.progressStatus = "error";
                    root.progressText = "Session expired — please sign in again";
                    Notifications.notify({
                        summary: "Session expired",
                        body: "Could not refresh the session. Please send a new magic link."
                    });
                }
            }
        }
    }
    Component {
        id: refreshSaveComp
        Process {}
    }
    Component {
        id: writeSettingsComp
        Process {}
    }
    Component {
        id: metaWriteComp
        Process {}
    }
    // zenity exits 1 on cancel — silent.
    Component {
        id: zenityComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    root._zenityOut = text.trim();
                }
            }
            onExited: code => {
                if (code === 0)
                    root.onAvatarPicked(root._zenityOut);
                else if (code !== 1)
                    Notifications.notify({
                        summary: "Avatar picker failed",
                        body: "Could not open the file picker."
                    });
            }
        }
    }
    property string _zenityOut: ""
    // Local-only avatar copy (not signed in): progress + reload on success.
    Component {
        id: setAvatarComp
        Process {
            onExited: code => {
                if (code !== 0) {
                    root.progressStatus = "error";
                    root.progressText = "Local update failed";
                    Notifications.notify({
                        summary: "Local update failed",
                        body: "Could not copy the selected picture."
                    });
                    return;
                }
                root.progressStatus = "success";
                root.progressText = "Avatar updated locally";
                Notifications.notify({
                    summary: "Avatar updated",
                    body: "Using the selected picture locally."
                });
                root.reloadAvatar();
            }
        }
    }
    Component {
        id: avatarConvertComp
        Process {
            onExited: code => root.onAvatarConverted(code === 0)
        }
    }
    Component {
        id: avatarUploadComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    root._avatarUpOut = text;
                }
            }
            onExited: code => root.onAvatarUploaded(code === 0)
        }
    }
    property string _avatarUpOut: ""
    Component {
        id: avatarPatchComp
        Process {
            onExited: code => root.onAvatarPatched(code === 0)
        }
    }
    Component {
        id: avatarFetchComp
        Process {
            onExited: code => {
                root.reloadAvatar();
                root.onAvatarFetched(code === 0);
            }
        }
    }
    // Silent avatar sync on profile load:
    // no success notification, failure notifies once (retried next load).
    function syncAvatarSilent(url) {
        if (!url)
            return;
        const p = avatarSyncComp.createObject(root);
        p.command = ["curl", "-sS", "--max-time", "30", "-o", root.avatarPath, url];
        p.running = true;
    }
    Component {
        id: avatarSyncComp
        Process {
            onExited: code => {
                if (code === 0) {
                    root.reloadAvatar();
                } else {
                    Notifications.notify({
                        summary: "Avatar sync failed",
                        body: "Could not refresh the local picture — will retry on next refresh."
                    });
                }
            }
        }
    }
}
