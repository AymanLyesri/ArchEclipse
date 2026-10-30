// Unauthenticated NOWPayments IPN: HMAC-SHA512 over the key-sorted body must equal x-nowpayments-sig.
// Only payment_status "finished" grants value; unique (provider, provider_payment_id) keeps it idempotent.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const IPN_SECRET = Deno.env.get("NOWPAYMENTS_IPN_SECRET") ?? "";

// Terminal per current NOWPayments GET /payment/:id status semantics.
const SUCCESS_STATUSES = new Set(["finished"]);
const FAILED_STATUSES = new Set(["failed", "expired"]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length || a.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// Exactly the documented Node.js reference:
//   hmac.update(JSON.stringify(params, Object.keys(params).sort()))
async function computeSignature(params: Record<string, unknown>, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret.trim()),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const payload = JSON.stringify(params, Object.keys(params).sort());
  return toHex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)));
}

function mapStatus(raw: unknown): "pending" | "finished" | "failed" | "expired" {
  const s = String(raw ?? "").toLowerCase();
  if (SUCCESS_STATUSES.has(s)) return "finished";
  if (s === "expired") return "expired";
  if (FAILED_STATUSES.has(s)) return "failed";
  // waiting / confirming / confirmed / sending / partially_paid / unknown:
  // still in flight -> keep pending, NEVER grant.
  return "pending";
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  if (!IPN_SECRET) {
    console.error("payment-webhook-nowpayments: NOWPAYMENTS_IPN_SECRET not configured");
    return json({ error: "Webhook not configured" }, 500);
  }

  const signature = req.headers.get("x-nowpayments-sig") ?? "";
  if (!signature) {
    return json({ error: "Missing signature" }, 401);
  }

  let rawText = "";
  try {
    rawText = await req.text();
  } catch {
    return json({ error: "Unreadable body" }, 400);
  }

  let params: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(rawText);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("not an object");
    params = parsed as Record<string, unknown>;
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const expected = await computeSignature(params, IPN_SECRET);
  if (!timingSafeEqual(expected, signature.trim())) {
    console.warn("payment-webhook-nowpayments: signature mismatch");
    return json({ error: "Invalid signature" }, 403);
  }

  const paymentId = params.payment_id != null ? String(params.payment_id) : "";
  const invoiceId =
    (params.invoice_id ?? params.invoiceId ?? "") != null
      ? String(params.invoice_id ?? params.invoiceId ?? "")
      : "";
  const orderId = params.order_id != null ? String(params.order_id) : "";
  if (!paymentId && !invoiceId && !orderId) {
    return json({ error: "Missing payment identifiers" }, 400);
  }

  const status = mapStatus(params.payment_status);
  const providerPid = paymentId ? `payment:${paymentId}` : invoiceId ? `invoice:${invoiceId}` : null;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  // Resolve the local intent row: prefer our order_id (= supporter_payments.id),
  // fall back to a previously bound provider id.
  let rowId: string | null = null;
  if (orderId) {
    const { data } = await admin.from("supporter_payments").select("id").eq("id", orderId).maybeSingle();
    if (data) rowId = data.id;
  }
  if (!rowId && providerPid) {
    const { data } = await admin
      .from("supporter_payments")
      .select("id")
      .eq("provider", "nowpayments")
      .eq("provider_payment_id", providerPid)
      .maybeSingle();
    if (data) rowId = data.id;
  }

  if (!rowId) {
    // No intent row (e.g. manually created invoice): record unattributed so
    // funds are auditable, but grant NOTHING without a known user.
    if (!providerPid) return json({ ok: true, recorded: false });
    const { error } = await admin.from("supporter_payments").insert({
      user_id: null,
      provider: "nowpayments",
      provider_payment_id: providerPid,
      amount: params.price_amount ?? null,
      currency: (params.price_currency ?? params.pay_currency ?? null) as string | null,
      status,
      raw: params,
    });
    if (error && !String(error.message).includes("duplicate")) {
      console.error("payment-webhook-nowpayments: unattributed insert failed", error.message);
      return json({ error: "Storage failed" }, 500);
    }
    return json({ ok: true, recorded: true, unattributed: true });
  }

  // Forward-only update: pending -> terminal. A finished row is never
  // downgraded by a delayed/duplicate delivery.
  const patch: Record<string, unknown> = { raw: params };
  if (providerPid) patch.provider_payment_id = providerPid;
  if (status !== "pending") patch.status = status;

  const { data: current } = await admin
    .from("supporter_payments")
    .select("status")
    .eq("id", rowId)
    .single();

  if (current?.status === "finished") {
    return json({ ok: true, duplicate: true });
  }

  const { error: updateError } = await admin
    .from("supporter_payments")
    .update(patch)
    .eq("id", rowId);
  if (updateError) {
    console.error("payment-webhook-nowpayments: update failed", updateError.message);
    return json({ error: "Storage failed" }, 500);
  }

  console.log(
    `payment-webhook-nowpayments: ${providerPid ?? orderId} -> ${status} (row ${rowId})`,
  );
  return json({ ok: true, status });
});
