import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services

// Supporter widget — one-time contributions that unlock supporter status.
//
// Two verified providers (no subscriptions):
//  [Ko-fi]        fiat/card/PayPal. Checkout stays on ko-fi.com. The donor
//                 pastes their link code (AE-XXXX-XXXX) into the Ko-fi
//                 message; the server-side webhook links the payment.
//  [Crypto]       NOWPayments hosted invoice, created via our Edge Function
//                 (API key stays server-side). QML only sees the invoice URL.
//
// Supporter status is NEVER granted here. Only the server-side verified
// webhook -> DB trigger path writes `supporters`. This widget only reads
// that table and opens external checkouts.
Item {
    id: root

    // --- Config (public values only — no secrets in QML) ---
    readonly property string supabaseUrl: Supabase.url
    readonly property string supabaseKey: Supabase.anonKey
    readonly property string fnCreatePayment: Supabase.fnCreateNowPayments
    readonly property string kofiUrl: Supabase.kofiPageUrl
    readonly property string authSessionPath: Supabase.authSessionPath

    // --- State ---
    property var session: null
    property string uid: ""
    property bool signedIn: false
    property bool supporterKnown: false
    property bool isSupporter: false
    property bool busy: false
    property string statusText: "Sign in to support"
    property string statusKind: "idle" // idle | loading | ok | warn | error

    property var amounts: [3, 5, 10, 25]
    property int selectedAmount: 5

    // Standalone direct-transfer addresses (legacy options). These leave the
    // shell entirely (plain wallet transfer, no provider callback), so they
    // can NEVER be verified and do not activate supporter status.
    property var standaloneCryptos: [
        { name: "Bitcoin", icon: "", address: "1JisW9xeatCFadtgsenjbpCcFePZGPyXow", color: "#F7931A" },
        { name: "Ethereum", icon: "", address: "0x52d06d47bb9dc75eaf027f18cb197d5817989a96", color: "#627EEA" },
        { name: "BSC (BEP20)", icon: "", description: "BNB Smart Chain", address: "0x52d06d47bb9dc75eaf027f18cb197d5817989a96", color: "#F3BA2F" }
    ]

    property string linkCode: ""
    property string linkCodeState: "idle" // idle | loading | ready | error

    property string pendingPaymentId: ""
    property string pendingState: "" // "" | waiting | finished | failed

    property var claimRows: []
    property bool claimChecked: false

    Component.onCompleted: root.boot()

    function boot() {
        root.setStatus("loading", "Checking session…");
        const p = readSessionComp.createObject(root);
        p.command = ["cat", root.authSessionPath];
        p.running = true;
    }

    function setStatus(kind, text) {
        root.statusKind = kind;
        root.statusText = text;
    }

    function authHeaders(token) {
        return ["-H", "apikey: " + root.supabaseKey, "-H", "Authorization: Bearer " + token];
    }

    // Supabase access_tokens expire after ~1h. Unlike UserProfileWidget this
    // widget owns no refresh flow — on auth errors, say so plainly and route
    // to the Account tab instead of showing a generic "retry".
    function isAuthErrorText(text) {
        const t = String(text || "");
        return t.indexOf("JWT expired") >= 0 || t.indexOf("bad_jwt") >= 0 || t.indexOf("PGRST303") >= 0 || (t.indexOf("expired") >= 0 && t.indexOf("token") >= 0);
    }
    function sessionExpired() {
        root.setStatus("error", "Session expired — open Account to sign in again");
        Notifications.notify({ summary: "Session expired", body: "Your sign-in expired. Open the Account tab and send a new magic link." });
    }

    // --- Session / identity ---
    function onSessionText(text) {
        let s = null;
        try {
            s = text ? JSON.parse(text) : null;
        } catch (e) {
            s = null;
        }
        if (!s?.access_token) {
            root.session = null;
            root.signedIn = false;
            root.uid = "";
            root.supporterKnown = false;
            root.setStatus("idle", "Sign in to support");
            return;
        }
        root.session = s;
        root.signedIn = true;
        root.resolveUid();
    }

    function resolveUid() {
        // Fast path: UserProfileWidget already resolved the uid this session.
        const cached = UserProfileState.cachedUid;
        if (cached) {
            root.uid = cached;
            root.afterIdentity();
            return;
        }
        const p = whoAmIComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' '" + root.supabaseUrl + "/auth/v1/user'"];
        p.running = true;
    }

    function onWhoAmI(text) {
        let u = null;
        try {
            u = text ? JSON.parse(text) : null;
        } catch (e) {
            u = null;
        }
        if (!u?.id) {
            root.sessionExpired();
            return;
        }
        root.uid = u.id;
        root.afterIdentity();
    }

    function afterIdentity() {
        root.refreshSupporter();
        root.ensureLinkCode();
    }

    // --- Supporter state (read-only; row presence in `supporters`) ---
    function refreshSupporter() {
        if (!root.session?.access_token || !root.uid)
            return;
        root.setStatus("loading", "Checking supporter status…");
        const p = supporterComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' '" + root.supabaseUrl + "/rest/v1/supporters?select=id&id=eq." + encodeURIComponent(root.uid) + "'"];
        p.running = true;
    }

    function onSupporter(text) {
        let rows = null;
        try {
            rows = text ? JSON.parse(text) : null;
        } catch (e) {
            rows = null;
        }
        if (!Array.isArray(rows)) {
            if (root.isAuthErrorText(text)) {
                root.sessionExpired();
                return;
            }
            root.setStatus("error", "Could not check status — retry");
            return;
        }
        root.supporterKnown = true;
        const supported = rows.length > 0;
        if (supported !== root.isSupporter) {
            root.isSupporter = supported;
            root.mirrorToProfileCache(supported);
            if (supported)
                Notifications.notify({ summary: "Supporter", body: "Thank you! Supporter status is active." });
        }
        if (supported)
            root.setStatus("ok", "Supporter active — thank you!");
        else if (root.pendingPaymentId || root.pendingState === "waiting")
            root.setStatus("warn", "Payment pending — finish checkout, then Refresh");
        else
            root.setStatus("idle", "One-time contribution • no subscription");
    }

    // Keep the profile widget consistent without a restart: it restores from
    // UserProfileState when recreated.
    function mirrorToProfileCache(supported) {
        const p = UserProfileState.profile;
        if (p && p.is_supporter !== supported) {
            UserProfileState.profile = {
                id: p.id, email: p.email, username: p.username,
                avatar: p.avatar, is_supporter: supported
            };
        }
    }

    // --- Ko-fi link code (short-lived, single-use, own row via RLS) ---
    function codeAlphabet() {
        return "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    }
    function makeCode() {
        const a = root.codeAlphabet();
        let s = "";
        for (let i = 0; i < 8; i++)
            s += a[Math.floor(Math.random() * a.length)];
        return "AE-" + s.slice(0, 4) + "-" + s.slice(4);
    }

    function ensureLinkCode() {
        if (!root.session?.access_token || !root.uid)
            return;
        root.linkCodeState = "loading";
        const p = codeGetComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' '" + root.supabaseUrl + "/rest/v1/kofi_link_codes?select=code,expires_at&user_id=eq." + encodeURIComponent(root.uid) + "&used=eq.false&order=created_at.desc&limit=1'"];
        p.running = true;
    }

    function onCodeGet(text) {
        if (root.isAuthErrorText(text)) {
            root.linkCodeState = "error";
            root.sessionExpired();
            return;
        }
        let rows = null;
        try {
            rows = text ? JSON.parse(text) : null;
        } catch (e) {
            rows = null;
        }
        if (Array.isArray(rows) && rows[0]?.code) {
            const exp = new Date(rows[0].expires_at).getTime();
            if (exp > Date.now() + 5 * 60 * 1000) {
                root.linkCode = rows[0].code;
                root.linkCodeState = "ready";
                return;
            }
        }
        root.createLinkCode(0);
    }

    function createLinkCode(attempt) {
        const code = root.makeCode();
        const exp = new Date(Date.now() + 2 * 3600 * 1000).toISOString();
        const p = codePutComp.createObject(root);
        p.attempt = attempt;
        p.code = code;
        p.command = ["bash", "-c", "curl -sS -X POST -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' -H 'Content-Type: application/json' -H 'Prefer: return=representation' -d " + JSON.stringify(JSON.stringify({ code: code, user_id: root.uid, expires_at: exp })) + " " + JSON.stringify(root.supabaseUrl + "/rest/v1/kofi_link_codes")];
        p.running = true;
    }

    function onCodePut(text, attempt, code) {
        let rows = null;
        try {
            rows = text ? JSON.parse(text) : null;
        } catch (e) {
            rows = null;
        }
        if (Array.isArray(rows) && rows[0]?.code) {
            root.linkCode = rows[0].code;
            root.linkCodeState = "ready";
            return;
        }
        // PK collision on the random code (or transient error): retry once.
        if (attempt < 1 && !root.isAuthErrorText(text)) {
            root.createLinkCode(attempt + 1);
            return;
        }
        if (root.isAuthErrorText(text))
            root.sessionExpired();
        root.linkCodeState = "error";
    }

    // --- NOWPayments crypto checkout (via Edge Function; key stays server-side) ---
    function payWithCrypto() {
        if (!root.signedIn) {
            root.goSignIn();
            return;
        }
        if (root.busy)
            return;
        root.busy = true;
        root.pendingState = "";
        root.setStatus("loading", "Creating crypto checkout…");
        const p = createPayComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -X POST -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' -H 'Content-Type: application/json' -d " + JSON.stringify(JSON.stringify({ amount: root.selectedAmount })) + " " + JSON.stringify(root.fnCreatePayment)];
        p.running = true;
    }

    function onCheckout(text) {
        root.busy = false;
        let r = null;
        try {
            r = text ? JSON.parse(text) : null;
        } catch (e) {
            r = null;
        }
        if (!r?.invoice_url || !r?.payment_id) {
            if (root.isAuthErrorText(text)) {
                root.sessionExpired();
                return;
            }
            const msg = r?.error ? String(r.error) : "Checkout failed — please retry";
            root.setStatus("error", msg);
            Notifications.notify({ summary: "Crypto checkout", body: msg });
            return;
        }
        root.pendingPaymentId = r.payment_id;
        root.pendingState = "waiting";
        root.setStatus("warn", "Checkout open in browser — finish payment, then Refresh");
        Notifications.notify({ summary: "Checkout created", body: "Complete the payment in your browser." });
        root.openUrl(r.invoice_url);
        root.showQRCode(r.invoice_url, "crypto checkout");
    }

    function refreshPayment() {
        if (!root.session?.access_token) {
            root.goSignIn();
            return;
        }
        if (root.pendingPaymentId) {
            const p = payStatusComp.createObject(root);
            p.command = ["bash", "-c", "curl -sS -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' '" + root.supabaseUrl + "/rest/v1/supporter_payments?select=status&id=eq." + encodeURIComponent(root.pendingPaymentId) + "'"];
            p.running = true;
        } else {
            root.refreshSupporter();
        }
    }

    function onPayStatus(text) {
        let rows = null;
        try {
            rows = text ? JSON.parse(text) : null;
        } catch (e) {
            rows = null;
        }
        const st = Array.isArray(rows) && rows[0]?.status ? String(rows[0].status) : "";
        if (!st) {
            if (root.isAuthErrorText(text)) {
                root.sessionExpired();
                return;
            }
            root.setStatus("error", "Could not check payment — retry");
            return;
        }
        if (st === "finished") {
            root.pendingState = "finished";
            root.pendingPaymentId = "";
            root.refreshSupporter();
        } else if (st === "failed" || st === "expired") {
            root.pendingState = "failed";
            root.pendingPaymentId = "";
            root.setStatus("error", "Payment " + st + " — you can try again");
        } else {
            root.pendingState = "waiting";
            root.setStatus("warn", "Still pending — finish payment, then Refresh");
            root.refreshSupporter();
        }
    }

    // --- Ko-fi claim (donated without a code; email-matched server-side) ---
    function checkClaim() {
        if (!root.signedIn) {
            root.goSignIn();
            return;
        }
        root.claimChecked = false;
        root.claimRows = [];
        const p = claimGetComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' '" + root.supabaseUrl + "/rest/v1/supporter_payments?select=id,amount,currency,created_at&provider=eq.kofi&status=eq.finished&user_id=is.null'"];
        p.running = true;
    }

    function onClaimGet(text) {
        root.claimChecked = true;
        if (root.isAuthErrorText(text)) {
            root.sessionExpired();
            return;
        }
        let rows = null;
        try {
            rows = text ? JSON.parse(text) : null;
        } catch (e) {
            rows = null;
        }
        root.claimRows = Array.isArray(rows) ? rows : [];
        if (root.claimRows.length === 0)
            Notifications.notify({ summary: "Ko-fi claim", body: "No unclaimed donation found for your account." });
    }

    function claimRow(id) {
        const p = claimPutComp.createObject(root);
        p.command = ["bash", "-c", "curl -sS -X PATCH -H 'apikey: " + root.supabaseKey + "' -H 'Authorization: Bearer " + root.session.access_token + "' -H 'Content-Type: application/json' -H 'Prefer: return=representation' -d " + JSON.stringify(JSON.stringify({ user_id: root.uid })) + " " + JSON.stringify(root.supabaseUrl + "/rest/v1/supporter_payments?user_id=is.null&id=eq." + encodeURIComponent(id))];
        p.running = true;
    }

    function onClaimPut(text) {
        let rows = null;
        try {
            rows = text ? JSON.parse(text) : null;
        } catch (e) {
            rows = null;
        }
        if (Array.isArray(rows) && rows[0]?.id) {
            root.claimRows = [];
            Notifications.notify({ summary: "Ko-fi claim", body: "Donation linked — checking supporter status…" });
            root.refreshSupporter();
        } else if (root.isAuthErrorText(text)) {
            root.sessionExpired();
        } else {
            Notifications.notify({ summary: "Ko-fi claim", body: "Claim failed — the donation may already be linked." });
        }
    }

    function goSignIn() {
        Notifications.notify({ summary: "Sign in required", body: "Please sign in first." });
        Registry.selectLeftTab("UserProfile");
    }

    // --- UI ---
    SmoothFlickable {
        id: donateScroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: donateCol.implicitHeight
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: donateCol
            width: donateScroll.width
            spacing: 16
            topPadding: 4

            GeneralTab {
                id: generalEmbed
                width: parent.width
                height: generalEmbed.implicitHeight
                widgetWidth: parent.width
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Column {
                width: parent.width
                spacing: 5
                Label {
                    width: parent.width
                    text: "Support ArchEclipse"
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    color: Theme.fg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Label {
                    width: parent.width
                    text: "Help support continued development and maintenance."
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            // Status card
            Rectangle {
                width: parent.width
                implicitHeight: statusCol.implicitHeight + 20
                radius: Theme.radius
                color: Theme.surface
                border.color: root.isSupporter ? Theme.accent : Theme.border
                border.width: 1
                Column {
                    id: statusCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: root.isSupporter ? "♥ Supporter" : "Supporter status"
                            font.pixelSize: Theme.fontSize + 1
                            font.bold: true
                            color: root.isSupporter ? Theme.accent : Theme.fg
                        }
                        Item { Layout.fillWidth: true; Layout.fillHeight: true }
                        Label {
                            text: !root.signedIn ? "signed out" : !root.supporterKnown ? "…" : root.isSupporter ? "active" : "not yet"
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fgDim
                        }
                    }
                    Label {
                        width: parent.width
                        text: root.statusText
                        font.pixelSize: Theme.fontSize - 1
                        color: root.statusKind === "error" ? Theme.danger : root.statusKind === "warn" ? Theme.accent : Theme.fgDim
                        wrapMode: Text.WordWrap
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        AppButton {
                            width: (parent.width - 8) / 2
                            height: 32
                            text: "Refresh"
                            pixelSize: Theme.fontSize - 1
                            outlined: true
                            enabled: root.signedIn
                            tooltipText: "Re-check supporter status"
                            onClicked: root.signedIn ? (root.pendingPaymentId ? root.refreshPayment() : root.refreshSupporter()) : root.goSignIn()
                        }
                        AppButton {
                            width: (parent.width - 8) / 2
                            height: 32
                            text: root.signedIn ? "Account" : "Sign in"
                            pixelSize: Theme.fontSize - 1
                            outlined: true
                            tooltipText: "Open profile / sign in"
                            onClicked: Registry.selectLeftTab("UserProfile")
                        }
                    }
                }
            }

            // Amount selector (one-time)
            Column {
                width: parent.width
                spacing: 8
                Label {
                    width: parent.width
                    text: "One-time amount (USD)"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.fg
                    horizontalAlignment: Text.AlignHCenter
                }
                Row {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: root.amounts
                        delegate: AppButton {
                            required property var modelData
                            width: (parent.width - 24) / 4
                            height: 38
                            text: "$" + modelData
                            toggle: true
                            checked: root.selectedAmount === modelData
                            outlined: true
                            onClicked: root.selectedAmount = modelData
                        }
                    }
                }
            }

            // Ko-fi card
            Rectangle {
                width: parent.width
                implicitHeight: kofiCol.implicitHeight + 20
                radius: Theme.radius
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                Column {
                    id: kofiCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8
                    Label {
                        text: "Ko-fi — card / PayPal"
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        color: "#29ABE0"
                    }
                    Label {
                        width: parent.width
                        text: "Checkout happens on Ko-fi. Paste your link code into the Ko-fi message so the donation is linked to your account."
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                        wrapMode: Text.WordWrap
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        AppTextField {
                            id: codeField
                            width: parent.width - 108
                            height: 34
                            text: root.linkCodeState === "ready" ? root.linkCode : root.linkCodeState === "loading" ? "…" : "—"
                            readOnly: true
                            placeholderText: "Sign in to get a code"
                        }
                        AppButton {
                            width: 100
                            height: 34
                            text: "Copy"
                            pixelSize: Theme.fontSize - 1
                            outlined: true
                            enabled: root.linkCodeState === "ready"
                            tooltipText: "Copy link code"
                            onClicked: root.copyToClipboard(root.linkCode, "Link code")
                        }
                    }
                    AppButton {
                        width: parent.width
                        height: 46
                        icon: ""
                        text: "Support with Ko-fi — $" + root.selectedAmount
                        pixelSize: Theme.fontSize
                        outlined: true
                        outlineColor: "#29ABE0"
                        idleBg: Theme.surface
                        hoverBg: "#29ABE0"
                        idleFg: Theme.fg
                        hoverFg: "white"
                        tooltipText: "Open Ko-fi in your browser\nPut " + (root.linkCode || "your link code") + " in the message"
                        onClicked: {
                            if (!root.signedIn) {
                                root.goSignIn();
                                return;
                            }
                            // The code-in-message link is a workaround (Ko-fi
                            // has no metadata field), so at least make it
                            // paste-ready: copy, then open checkout.
                            if (root.linkCodeState === "ready" && root.linkCode !== "")
                                root.copyToClipboard(root.linkCode, "Link code");
                            root.openUrl(root.kofiUrl);
                        }
                    }
                }
            }

            // Crypto card
            Rectangle {
                width: parent.width
                implicitHeight: cryptoCol.implicitHeight + 20
                radius: Theme.radius
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                Column {
                    id: cryptoCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8
                    Label {
                        text: "Crypto — NOWPayments"
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        color: "#F7931A"
                    }
                    Label {
                        width: parent.width
                        text: "Pay with Bitcoin, Ethereum and more. Status activates only after the payment is confirmed on-chain. Tip: small amounts under ~$20 need a low-minimum coin (e.g. ETH, TRX) — BTC enforces a higher minimum."
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                        wrapMode: Text.WordWrap
                    }
                    AppButton {
                        width: parent.width
                        height: 46
                        icon: ""
                        text: root.busy ? "Creating checkout…" : "Pay with Crypto — $" + root.selectedAmount
                        pixelSize: Theme.fontSize
                        outlined: true
                        outlineColor: "#F7931A"
                        idleBg: Theme.surface
                        hoverBg: "#F7931A"
                        idleFg: Theme.fg
                        hoverFg: "white"
                        enabled: !root.busy
                        tooltipText: "Create a crypto checkout"
                        onClicked: root.payWithCrypto()
                    }
                    Label {
                        visible: root.pendingState !== ""
                        width: parent.width
                        text: root.pendingState === "finished" ? "Payment confirmed." : root.pendingState === "failed" ? "Payment failed or expired." : "Payment pending — complete it in your browser, then press Refresh."
                        font.pixelSize: Theme.fontSize - 1
                        color: root.pendingState === "failed" ? Theme.danger : Theme.accent
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Standalone direct transfers (unverified — no supporter status).
            // Plain wallet transfers with no provider callback, so the shell
            // cannot verify them. Kept for donors who prefer it.
            Rectangle {
                width: parent.width
                implicitHeight: standCol.implicitHeight + 20
                radius: Theme.radius
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                Column {
                    id: standCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8
                    Label {
                        text: "Direct wallet transfer — standalone"
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        color: Theme.fg
                    }
                    Label {
                        width: parent.width
                        text: "Sends coins straight to a wallet. There is no verification for these, so they do not activate supporter status — use Ko-fi or the crypto checkout above for that."
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                        wrapMode: Text.WordWrap
                    }
                    AppMasonry {
                        width: parent.width
                        columns: 2
                        spacing: 10
                        model: root.standaloneCryptos
                        delegate: Item {
                            property var modelData
                            property var opt: modelData ?? ({})
                            property string addr: opt.address ?? ""
                            property string qrData: opt.address ?? ""
                            property color brandColor: opt.color ?? Theme.accent
                            width: parent.width
                            height: standCardCol.implicitHeight
                            Column {
                                id: standCardCol
                                width: parent.width
                                spacing: 6
                                AppButton {
                                    width: parent.width
                                    height: 46
                                    icon: opt.icon ?? ""
                                    text: opt.name ?? ""
                                    pixelSize: Theme.fontSize
                                    outlined: true
                                    outlineColor: brandColor
                                    idleBg: Theme.surface
                                    hoverBg: brandColor
                                    idleFg: Theme.fg
                                    hoverFg: "white"
                                    tooltipText: "Copy " + opt.name + " address\n" + addr
                                    onClicked: root.copyToClipboard(addr, opt.name)
                                }
                                Label {
                                    visible: (opt.description ?? "") !== ""
                                    width: parent.width
                                    text: opt.description ?? ""
                                    font.pixelSize: Theme.fontSize - 3
                                    color: Theme.fgDim
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                AppButton {
                                    width: parent.width
                                    height: 32
                                    icon: ""
                                    text: "QR"
                                    pixelSize: Theme.fontSize - 2
                                    outlined: true
                                    outlineColor: Theme.border
                                    idleBg: "transparent"
                                    hoverBg: Theme.surfaceActive
                                    tooltipText: "Show QR Code"
                                    onClicked: {
                                        if (qrData) root.showQRCode(qrData, opt.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Claim card (Ko-fi without code)
            Rectangle {
                width: parent.width
                implicitHeight: claimCol.implicitHeight + 20
                radius: Theme.radius
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                Column {
                    id: claimCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8
                    Label {
                        text: "Donated on Ko-fi without a code?"
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        color: Theme.fg
                    }
                    Label {
                        width: parent.width
                        text: "If the Ko-fi email matches your sign-in email, you can link it here."
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                        wrapMode: Text.WordWrap
                    }
                    AppButton {
                        width: parent.width
                        height: 34
                        text: "Check for my donation"
                        pixelSize: Theme.fontSize - 1
                        outlined: true
                        onClicked: root.checkClaim()
                    }
                    Column {
                        visible: root.claimChecked
                        width: parent.width
                        spacing: 6
                        Label {
                            visible: root.claimRows.length === 0
                            width: parent.width
                            text: "No unclaimed donation found."
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fgDim
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Repeater {
                            model: root.claimRows
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                spacing: 8
                                Label {
                                    width: parent.width - 108
                                    text: (modelData.amount ?? "?") + " " + (modelData.currency ?? "") + " • " + String(modelData.created_at ?? "").slice(0, 10)
                                    font.pixelSize: Theme.fontSize - 1
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                AppButton {
                                    width: 100
                                    height: 30
                                    text: "Claim"
                                    pixelSize: Theme.fontSize - 1
                                    outlined: true
                                    onClicked: root.claimRow(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                Label {
                    width: parent.width
                    text: "Thank you for your support! 💖"
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    color: Theme.accent
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // --- Hidden Process components (repo convention: Component + createObject) ---
    Component {
        id: readSessionComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onSessionText(text)
            }
        }
    }
    Component {
        id: whoAmIComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onWhoAmI(text)
            }
            onExited: code => {
                if (code !== 0)
                    root.setStatus("error", "Could not verify session — retry");
            }
        }
    }
    Component {
        id: supporterComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onSupporter(text)
            }
            onExited: code => {
                if (code !== 0)
                    root.setStatus("error", "Could not check status — retry");
            }
        }
    }
    Component {
        id: codeGetComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onCodeGet(text)
            }
            onExited: code => {
                if (code !== 0)
                    root.linkCodeState = "error";
            }
        }
    }
    Component {
        id: codePutComp
        Process {
            property int attempt: 0
            property string code: ""
            stdout: StdioCollector {
                onStreamFinished: root.onCodePut(text, attempt, code)
            }
            onExited: code => {
                if (code !== 0)
                    root.linkCodeState = "error";
            }
        }
    }
    Component {
        id: createPayComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onCheckout(text)
            }
            onExited: code => {
                if (code !== 0) {
                    root.busy = false;
                    root.setStatus("error", "Checkout failed — please retry");
                }
            }
        }
    }
    Component {
        id: payStatusComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onPayStatus(text)
            }
            onExited: code => {
                if (code !== 0)
                    root.setStatus("error", "Could not check payment — retry");
            }
        }
    }
    Component {
        id: claimGetComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onClaimGet(text)
            }
        }
    }
    Component {
        id: claimPutComp
        Process {
            stdout: StdioCollector {
                onStreamFinished: root.onClaimPut(text)
            }
            onExited: code => {
                if (code !== 0)
                    Notifications.notify({ summary: "Ko-fi claim", body: "Claim request failed." });
            }
        }
    }

    // --- Helpers (reused patterns: clipboard, external browser, QR) ---
    function copyToClipboard(text, label) {
        const proc = copyProcComp.createObject(root);
        proc.label = label;
        proc.command = ["bash", "-c", "echo -n " + JSON.stringify(text) + " | wl-copy"];
        proc.running = true;
    }

    property Component copyProcComp: Component {
        Process {
            property string label: ""
            onExited: (code) => {
                if (code === 0) {
                    Notifications.notify({ summary: "Copied to Clipboard", body: label + " copied successfully!" });
                } else {
                    Notifications.notify({ summary: "Error", body: "Failed to copy to clipboard" });
                }
            }
        }
    }

    function openUrl(url) {
        Quickshell.execDetached(["xdg-open", url]);
        Notifications.notify({ summary: "Opening page", body: "Opening checkout in browser…" });
    }

    function showQRCode(data, name) {
        const qrPath = "/tmp/supporter_qr_" + Date.now() + ".png";
        const proc = qrProcComp.createObject(root);
        proc.command = ["qrencode", "-o", qrPath, data];
        proc.running = true;
        proc.qrPath = qrPath;
        proc.name = name;
    }

    property Component qrProcComp: Component {
        Process {
            property string qrPath: ""
            property string name: ""
            onExited: (code) => {
                if (code === 0) {
                    Quickshell.execDetached(["xdg-open", qrPath]);
                    Notifications.notify({ summary: "QR Code Generated", body: "Scan the QR code to open the " + name + "!" });
                } else {
                    Notifications.notify({ summary: "Error", body: "QR code generation failed. Install 'qrencode' package." });
                }
            }
        }
    }
}
