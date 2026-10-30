// Authenticated one-time checkout: QML → function → NOWPayments POST /v1/invoice → { invoice_url }.
// user_id comes from the verified JWT only (never the body), so the API key never reaches QML.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const NOWPAYMENTS_API_KEY = Deno.env.get("NOWPAYMENTS_API_KEY") ?? "";
const NOWPAYMENTS_API_BASE =
  Deno.env.get("NOWPAYMENTS_API_BASE") ?? "https://api.nowpayments.io/v1";

// Suggested one-time amounts (USD). Custom amounts within [MIN, MAX] allowed.
const MIN_AMOUNT = 1;
const MAX_AMOUNT = 1000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json({ error: "Sign in required" }, 401);
  }

  // Verify the caller's JWT; the sub is the only trusted user identity.
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return json({ error: "Invalid or expired session" }, 401);
  }

  let body: { amount?: unknown; pay_currency?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount < MIN_AMOUNT || amount > MAX_AMOUNT) {
    return json({ error: `Amount must be between ${MIN_AMOUNT} and ${MAX_AMOUNT} USD` }, 400);
  }
  const rounded = Math.round(amount * 100) / 100;

  const payCurrency =
    typeof body.pay_currency === "string" && body.pay_currency.trim() !== ""
      ? body.pay_currency.trim().toLowerCase()
      : undefined;

  if (!NOWPAYMENTS_API_KEY) {
    console.error("create-nowpayments-payment: NOWPAYMENTS_API_KEY not configured");
    return json({ error: "Crypto payments are temporarily unavailable" }, 503);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  // 1. Create the local intent row FIRST so order_id always resolves server-side.
  const { data: payment, error: insertError } = await admin
    .from("supporter_payments")
    .insert({
      user_id: user.id,
      provider: "nowpayments",
      amount: rounded,
      currency: "USD",
      status: "pending",
    })
    .select("id")
    .single();

  if (insertError || !payment) {
    console.error("create-nowpayments-payment: intent insert failed", insertError?.message);
    return json({ error: "Could not start checkout" }, 500);
  }

  // 2. Create the NOWPayments invoice (one-time hosted checkout).
  const ipnCallbackUrl = `${SUPABASE_URL}/functions/v1/payment-webhook-nowpayments`;
  const invoicePayload: Record<string, unknown> = {
    price_amount: rounded,
    price_currency: "usd",
    order_id: payment.id,
    order_description: "ArchEclipse supporter contribution (one-time)",
    ipn_callback_url: ipnCallbackUrl,
    is_fixed_rate: false,
    is_fee_paid_by_user: false,
  };
  if (payCurrency) invoicePayload.pay_currency = payCurrency;

  let invoice: { id?: string; invoice_url?: string };
  try {
    const res = await fetch(`${NOWPAYMENTS_API_BASE}/invoice`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": NOWPAYMENTS_API_KEY,
      },
      body: JSON.stringify(invoicePayload),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      console.error("create-nowpayments-payment: provider error", res.status, text.slice(0, 300));
      throw new Error(`provider ${res.status}`);
    }
    invoice = await res.json();
  } catch (e) {
    console.error("create-nowpayments-payment: provider request failed", String(e).slice(0, 300));
    await admin.from("supporter_payments").delete().eq("id", payment.id);
    return json({ error: "Payment provider unreachable, please retry" }, 502);
  }

  if (!invoice?.id || !invoice?.invoice_url) {
    console.error("create-nowpayments-payment: malformed provider response");
    await admin.from("supporter_payments").delete().eq("id", payment.id);
    return json({ error: "Payment provider returned an invalid response" }, 502);
  }

  // 3. Bind the provider invoice id to the intent (drives IPN idempotency).
  const { error: updateError } = await admin
    .from("supporter_payments")
    .update({ provider_payment_id: `invoice:${invoice.id}` })
    .eq("id", payment.id);
  if (updateError) {
    console.error("create-nowpayments-payment: intent bind failed", updateError.message);
  }

  return json({
    payment_id: payment.id,
    invoice_id: invoice.id,
    invoice_url: invoice.invoice_url,
  });
});
