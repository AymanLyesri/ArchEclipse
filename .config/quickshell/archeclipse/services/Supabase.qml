pragma Singleton
import QtQuick
import Quickshell

// Supabase — single source of truth for backend endpoints + public config.
// ONLY the publishable (anon) key lives here — the same key the web app
// would ship. Service-role / provider API keys stay in Edge Function secrets
// and NEVER appear in QML. Supporter entitlement is read from the
// `supporters` table (row presence); the `supporter_payments` ledger and
// `kofi_link_codes` tables back the verified one-time payment flows.
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

    // True when an API error body means the cached session is dead
    // (GoTrue/PostgREST JWT failures). Single copy: the profile and
    // donations tabs both branch on it to bounce the user to sign-in.
    function isAuthError(text) {
        const t = String(text || "");
        return t.indexOf("JWT expired") >= 0
            || t.indexOf("bad_jwt") >= 0
            || t.indexOf("invalid JWT") >= 0
            || t.indexOf("PGRST303") >= 0
            || (t.indexOf("expired") >= 0 && t.indexOf("token") >= 0);
    }
}
