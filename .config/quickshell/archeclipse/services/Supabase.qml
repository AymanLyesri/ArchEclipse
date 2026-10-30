pragma Singleton
import QtQuick
import Quickshell

// Backend endpoints + public config. Only the publishable (anon) key lives here;
// service-role and provider keys stay in Edge Function secrets, never in QML.
Singleton {
    id: root

    readonly property string url: "https://skekmjmsgcbfhbwgpzkp.supabase.co"
    readonly property string anonKey: "sb_publishable_PLXFIwBsb79Gfu3YkW5B-w_rHozkZ1y"
    readonly property string functionsBase: url + "/functions/v1"
    readonly property string fnCreateNowPayments: functionsBase + "/create-nowpayments-payment"

    // External support page (checkout itself stays on Ko-fi).
    readonly property string kofiPageUrl: "https://ko-fi.com/aymanlyesri"

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string authSessionPath: homeDir + "/.cache/quickshell/auth/session.json"

    // True when an API error body means the cached session is dead (GoTrue/PostgREST
    // JWT failures); profile and donations both branch on it to bounce to sign-in.
    function isAuthError(text) {
        const t = String(text || "");
        return t.indexOf("JWT expired") >= 0
            || t.indexOf("bad_jwt") >= 0
            || t.indexOf("invalid JWT") >= 0
            || t.indexOf("PGRST303") >= 0
            || (t.indexOf("expired") >= 0 && t.indexOf("token") >= 0);
    }
}
