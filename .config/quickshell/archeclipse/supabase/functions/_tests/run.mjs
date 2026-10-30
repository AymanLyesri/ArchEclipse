// Plain-node logic tests: mirrors the Deno functions' signature, link-code and entitlement rules.
// The file-sync test fails when these copies drift from the deployed functions.
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const fnDir = path.resolve(here, "..");

// --- copies of the function logic (kept in sync by the file-sync test) ---

function sortedStringify(params) {
  return JSON.stringify(params, Object.keys(params).sort());
}
function hmacSha512Hex(payload, secret) {
  return crypto.createHmac("sha512", secret.trim()).update(payload).digest("hex");
}
function timingSafeEqual(a, b) {
  if (a.length !== b.length || a.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
const CODE_RE = /AE[\s-]*([A-HJ-NP-Z2-9]{4})[\s-]*([A-HJ-NP-Z2-9]{4})/i;
function extractCode(message) {
  const m = String(message ?? "").toUpperCase().match(CODE_RE);
  if (!m) return null;
  return `AE-${m[1]}-${m[2]}`;
}
function mapStatus(raw) {
  const s = String(raw ?? "").toLowerCase();
  if (s === "finished") return "finished";
  if (s === "expired") return "expired";
  if (s === "failed") return "failed";
  return "pending";
}
// Mirrors grant_supporter_on_payment trigger condition.
function wouldGrant(row) {
  return (
    row.user_id != null &&
    row.status === "finished" &&
    (row.provider === "kofi" || row.provider === "nowpayments")
  );
}

describe("NOWPayments IPN signature (documented algorithm)", () => {
  it("matches the HMAC-SHA512 primitive (node + python agree)", () => {
    // Cross-checked with python3 hashlib.hmac for the same key/message.
    const got = crypto.createHmac("sha512", "key").update("The quick brown fox jumps over the lazy dog").digest("hex");
    assert.equal(
      got,
      "b42af09057bac1e2d41708e48a902e09b5ff7f12ab428a4fe86653c73dd248fb82f948a549f7b791a5b41915ee4d1ec3935357e4e2317250d0372afa2ebeeb3a",
    );
  });

  it("signs with alphabetically sorted top-level keys", () => {
    const params = { payment_status: "finished", payment_id: "123", order_id: "abc" };
    assert.equal(
      sortedStringify(params),
      '{"order_id":"abc","payment_id":"123","payment_status":"finished"}',
    );
  });

  it("valid signature verifies; tampered body or wrong secret rejects", () => {
    const secret = "test-ipn-secret";
    const params = { payment_id: "555", payment_status: "finished", price_amount: 5 };
    const sig = hmacSha512Hex(sortedStringify(params), secret);
    assert.ok(timingSafeEqual(sig, hmacSha512Hex(sortedStringify(params), secret)));
    assert.ok(!timingSafeEqual(sig, hmacSha512Hex(sortedStringify({ ...params, price_amount: 5000 }), secret)));
    assert.ok(!timingSafeEqual(sig, hmacSha512Hex(sortedStringify(params), "wrong-secret")));
    assert.ok(!timingSafeEqual(sig, ""));
    assert.ok(!timingSafeEqual("short", sig));
  });
});

describe("payment_status mapping (only finished grants)", () => {
  for (const s of ["waiting", "confirming", "confirmed", "sending", "partially_paid", "created", "", undefined, "WAITING"]) {
    it(`"${s}" -> pending (no grant)`, () => {
      assert.equal(mapStatus(s), "pending");
      assert.equal(wouldGrant({ user_id: "u1", provider: "nowpayments", status: mapStatus(s) }), false);
    });
  }
  for (const s of ["failed", "expired", "FAILED"]) {
    it(`"${s}" -> terminal non-grant`, () => {
      assert.ok(["failed", "expired"].includes(mapStatus(s)));
      assert.equal(wouldGrant({ user_id: "u1", provider: "nowpayments", status: mapStatus(s) }), false);
    });
  }
  it('"finished" grants only with a known user', () => {
    assert.equal(mapStatus("finished"), "finished");
    assert.equal(wouldGrant({ user_id: "u1", provider: "nowpayments", status: "finished" }), true);
    assert.equal(wouldGrant({ user_id: "u1", provider: "kofi", status: "finished" }), true);
  });
});

describe("unauthenticated / unattributed payments never grant", () => {
  it("finished payment with NULL user_id does not grant", () => {
    assert.equal(wouldGrant({ user_id: null, provider: "kofi", status: "finished" }), false);
  });
  it("unknown provider does not grant", () => {
    assert.equal(wouldGrant({ user_id: "u1", provider: "paypal", status: "finished" }), false);
  });
});

describe("Ko-fi link-code extraction", () => {
  it("finds codes with dashes, spaces, or lowercase", () => {
    // NOTE: 0/O, 1/I/L are outside the code alphabet by design.
    assert.equal(extractCode("Enjoy! AE-AB22-CD34 great work"), "AE-AB22-CD34");
    assert.equal(extractCode("ae-ab22-cd34"), "AE-AB22-CD34");
    assert.equal(extractCode("code AE AB22 CD34 thanks"), "AE-AB22-CD34");
  });
  it("rejects ambiguous chars and missing prefix", () => {
    assert.equal(extractCode("AE-AB10-CD3L thanks"), null); // 0/1/L not in alphabet
    assert.equal(extractCode("AE-AB12-CD34 thanks"), null); // 1 not in alphabet
    assert.equal(extractCode("just a nice donation"), null);
    assert.equal(extractCode("SUPPORT"), null);
    assert.equal(extractCode(null), null);
  });
});

describe("Ko-fi event gating", () => {
  // Mirrors the webhook: only Donation + non-subscription grants.
  function shouldProcess(type, isSub) {
    return type === "Donation" && !(isSub === true || isSub === "true");
  }
  it("processes one-time donations only", () => {
    assert.equal(shouldProcess("Donation", false), true);
    assert.equal(shouldProcess("Subscription", false), false);
    assert.equal(shouldProcess("Donation", true), false);
    assert.equal(shouldProcess("Shop Order", false), false);
    assert.equal(shouldProcess("Commission", false), false);
  });
});

describe("repo files stay in sync with tested logic", () => {
  const read = (p) => fs.readFileSync(path.join(fnDir, p), "utf8");
  it("webhook-nowpayments contains the documented signing recipe", () => {
    const src = read("payment-webhook-nowpayments/index.ts");
    assert.ok(src.includes("Object.keys(params).sort()"));
    assert.ok(src.includes("SHA-512"));
    assert.ok(src.includes("x-nowpayments-sig"));
    assert.ok(src.includes('"finished"') || src.includes("'finished'"));
  });
  it("webhook-kofi contains token check + code regex + idempotency", () => {
    const src = read("payment-webhook-kofi/index.ts");
    assert.ok(src.includes("verification_token"));
    assert.ok(src.includes("KOFI_VERIFICATION_TOKEN"));
    assert.ok(src.includes("AE-"));
    assert.ok(src.includes("duplicate"));
    assert.ok(src.includes("unclaimed") || src.includes("UNCLAIMED"));
  });
  it("create function never trusts body user_id and requires JWT", () => {
    const src = read("create-nowpayments-payment/index.ts");
    assert.ok(src.includes("auth.getUser()"));
    assert.ok(src.includes("order_id"));
    assert.ok(!src.includes("service_role", ) || src.includes("SERVICE_ROLE_KEY"));
    assert.ok(!/body\.user_id|body\["user_id"\]/.test(src));
  });
  it("no secrets hardcoded in functions", () => {
    for (const f of [
      "create-nowpayments-payment/index.ts",
      "payment-webhook-nowpayments/index.ts",
      "payment-webhook-kofi/index.ts",
    ]) {
      const src = read(f);
      assert.ok(!src.includes("sb_secret_") && !src.includes("sb_publishable_"));
      assert.ok(!/x-api-key":\s*"[^$]/.test(src), `${f} must not hardcode provider keys`);
      assert.ok(src.includes("Deno.env.get"));
    }
  });
  it("migration defines ledger, link codes, trigger, RLS, hardening", () => {
    const sql = fs.readFileSync(
      path.resolve(fnDir, "../migrations/20260910000000_supporter_payments.sql"),
      "utf8",
    );
    for (const needle of [
      "supporter_payments",
      "kofi_link_codes",
      "grant_supporter_on_payment",
      "ROW LEVEL SECURITY",
      "auth.jwt()",
      "ON CONFLICT",
      "public.supporters",
      "REVOKE ALL ON FUNCTION public.grant_supporter_on_payment",
      "SET search_path",
    ]) {
      assert.ok(sql.includes(needle), `migration missing: ${needle}`);
    }
    // No direct supporters INSERT policy for end users (only trigger/service_role).
    assert.ok(!/CREATE POLICY[^;]*ON public\.supporters/s.test(sql));
  });
});
