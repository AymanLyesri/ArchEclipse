-- Supporter payments: `supporters` row presence IS supporter state (`user_profiles` has no such column).
-- Only the grant_supporter_on_payment trigger grants; webhooks insert ledger rows, never `supporters`.

-- gen_random_uuid() for payment ids (no-op if already installed).
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Payment ledger: NOWPayments rows start pending (order_id == id) and the IPN transitions them;
-- Ko-fi rows insert finished with user_id from the link code, or NULL for the email claim.
CREATE TABLE IF NOT EXISTS public.supporter_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  provider text NOT NULL CHECK (provider IN ('kofi', 'nowpayments')),
  provider_payment_id text,
  amount numeric,
  currency text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'finished', 'failed', 'expired')),
  donor_email text,
  raw jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Idempotency: the same provider delivery processed twice must not duplicate.
CREATE UNIQUE INDEX IF NOT EXISTS supporter_payments_provider_pid_uidx
  ON public.supporter_payments (provider, provider_payment_id)
  WHERE provider_payment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS supporter_payments_user_id_idx
  ON public.supporter_payments (user_id);

-- Unclaimed Ko-fi lookup by donor email (claim flow).
CREATE INDEX IF NOT EXISTS supporter_payments_unclaimed_kofi_idx
  ON public.supporter_payments (provider, status)
  WHERE user_id IS NULL;

-- Ko-fi link codes: short-lived, single-use, user-bound; created via REST under own-rows RLS.
-- The webhook consumes the AE-XXXX-XXXX code found in the donation message.
CREATE TABLE IF NOT EXISTS public.kofi_link_codes (
  code text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  used boolean NOT NULL DEFAULT false,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '2 hours'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS kofi_link_codes_user_id_idx
  ON public.kofi_link_codes (user_id);

-- updated_at maintenance.
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supporter_payments_touch_updated_at ON public.supporter_payments;
CREATE TRIGGER supporter_payments_touch_updated_at
  BEFORE UPDATE ON public.supporter_payments
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Entitlement: the ONLY writer path for supporter status (SECURITY DEFINER, so the caller cannot).
-- Fires on finished payments attributed to a user; ON CONFLICT DO NOTHING keeps redelivery idempotent.
CREATE OR REPLACE FUNCTION public.grant_supporter_on_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.user_id IS NOT NULL
     AND NEW.status = 'finished'
     AND NEW.provider IN ('kofi', 'nowpayments') THEN
    INSERT INTO public.supporters (id) VALUES (NEW.user_id)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supporter_payments_grant_supporter ON public.supporter_payments;
CREATE TRIGGER supporter_payments_grant_supporter
  AFTER INSERT OR UPDATE ON public.supporter_payments
  FOR EACH ROW EXECUTE FUNCTION public.grant_supporter_on_payment();

-- RLS: users read their own state; every value-granting write is service_role/trigger side.
-- Existing tables are never weakened.
ALTER TABLE public.supporter_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kofi_link_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own payments" ON public.supporter_payments;
CREATE POLICY "Users can read own payments"
  ON public.supporter_payments FOR SELECT
  USING (auth.uid() = user_id);

-- Claim discovery: match on the VERIFIED auth.users email, never the editable user_profiles.email,
-- so a donor can see their own unclaimed finished Ko-fi payments.
DROP POLICY IF EXISTS "Users can discover own unclaimed Ko-fi payments" ON public.supporter_payments;
CREATE POLICY "Users can discover own unclaimed Ko-fi payments"
  ON public.supporter_payments FOR SELECT
  USING (
    provider = 'kofi'
    AND status = 'finished'
    AND user_id IS NULL
    AND donor_email IS NOT NULL
    AND lower(donor_email) = lower(NULLIF(auth.jwt() ->> 'email', ''))
  );

-- Claim: same email guard on the old row, WITH CHECK pins the new row to the claimant and finished.
-- The trigger then grants supporter status in the same transaction.
DROP POLICY IF EXISTS "Users can claim own unclaimed Ko-fi payments" ON public.supporter_payments;
CREATE POLICY "Users can claim own unclaimed Ko-fi payments"
  ON public.supporter_payments FOR UPDATE
  USING (
    provider = 'kofi'
    AND status = 'finished'
    AND user_id IS NULL
    AND donor_email IS NOT NULL
    AND lower(donor_email) = lower(NULLIF(auth.jwt() ->> 'email', ''))
  )
  WITH CHECK (
    provider = 'kofi'
    AND status = 'finished'
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS "Users can read own Ko-fi link codes" ON public.kofi_link_codes;
CREATE POLICY "Users can read own Ko-fi link codes"
  ON public.kofi_link_codes FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own Ko-fi link codes" ON public.kofi_link_codes;
CREATE POLICY "Users can create own Ko-fi link codes"
  ON public.kofi_link_codes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Hardening: trigger functions must not be RPC-executable (triggers fire regardless of EXECUTE).
REVOKE ALL ON FUNCTION public.grant_supporter_on_payment() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.touch_updated_at() FROM PUBLIC, anon, authenticated;
