-- =============================================================
-- Migration 004: Driver Subscriptions & Payments
-- =============================================================

-- =============================================================
-- driver_subscriptions table
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_subscriptions (
  id                   uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id            uuid        NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  plan                 text        NOT NULL CHECK (plan IN ('daily','weekly','monthly')),
  amount               numeric(10,2) NOT NULL CHECK (amount > 0),
  status               text        NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','expired','cancelled')),
  started_at           timestamptz NOT NULL DEFAULT now(),
  ends_at              timestamptz NOT NULL,
  payment_method       text        NOT NULL
                      CHECK (payment_method IN ('chapa','telebirr','bank')),
  payment_reference    text,
  confirmed_by         uuid        REFERENCES profiles(id),
  confirmed_at         timestamptz,
  auto_renew           boolean     NOT NULL DEFAULT false,
  renewal_notified_at  timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subs_driver      ON driver_subscriptions(driver_id);
CREATE INDEX IF NOT EXISTS idx_subs_status      ON driver_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subs_ends_at     ON driver_subscriptions(ends_at);
CREATE INDEX IF NOT EXISTS idx_subs_auto_renew  ON driver_subscriptions(auto_renew) WHERE auto_renew = true;

-- =============================================================
-- bank_transfers table
-- =============================================================
CREATE TABLE IF NOT EXISTS bank_transfers (
  id               uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id        uuid        NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  amount           numeric(10,2) NOT NULL CHECK (amount > 0),
  purpose          text        NOT NULL DEFAULT 'subscription'
                  CHECK (purpose IN ('subscription','other')),
  reference        text        NOT NULL UNIQUE,
  status           text        NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','confirmed','rejected')),
  screenshot_url   text,
  rejection_reason text,
  confirmed_by     uuid        REFERENCES profiles(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bank_transfers_driver  ON bank_transfers(driver_id);
CREATE INDEX IF NOT EXISTS idx_bank_transfers_status  ON bank_transfers(status);
CREATE INDEX IF NOT EXISTS idx_bank_transfers_ref     ON bank_transfers(reference);

CREATE TRIGGER bank_transfers_updated_at
  BEFORE UPDATE ON bank_transfers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- payments table (ride payments)
-- =============================================================
CREATE TABLE IF NOT EXISTS payments (
  id               uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id          uuid        NOT NULL REFERENCES rides(id) ON DELETE RESTRICT,
  amount           numeric(10,2) NOT NULL CHECK (amount >= 0),
  method           text        NOT NULL
                  CHECK (method IN ('chapa','telebirr','cash','bank')),
  status           text        NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','completed','failed','refunded')),
  reference        text,
  points_discount  numeric(10,2) NOT NULL DEFAULT 0 CHECK (points_discount >= 0),
  chapa_tx_ref     text,
  telebirr_tx_ref  text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_ride    ON payments(ride_id);
CREATE INDEX IF NOT EXISTS idx_payments_status  ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_chapa   ON payments(chapa_tx_ref) WHERE chapa_tx_ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payments_tb      ON payments(telebirr_tx_ref) WHERE telebirr_tx_ref IS NOT NULL;

CREATE TRIGGER payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- Function: get_active_subscription
-- =============================================================
CREATE OR REPLACE FUNCTION get_active_subscription(p_driver_id uuid)
RETURNS SETOF driver_subscriptions
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM driver_subscriptions
  WHERE driver_id = p_driver_id
    AND status = 'active'
    AND ends_at > now()
  ORDER BY ends_at DESC
  LIMIT 1;
$$;

-- =============================================================
-- Function: check_driver_subscription
-- =============================================================
CREATE OR REPLACE FUNCTION check_driver_subscription(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM driver_subscriptions
    WHERE driver_id = p_driver_id
      AND status = 'active'
      AND ends_at > now()
  );
$$;

-- =============================================================
-- Trigger: When subscription expires, notify (don't auto-suspend)
-- =============================================================
CREATE OR REPLACE FUNCTION on_subscription_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When a subscription expires, notify the driver via pg_notify
  -- The actual suspension decision is left to admin/edge function
  IF NEW.status = 'expired' AND OLD.status != 'expired' THEN
    PERFORM pg_notify(
      'subscription_expired',
      json_build_object(
        'driver_id',       NEW.driver_id,
        'subscription_id', NEW.id,
        'plan',            NEW.plan,
        'ended_at',        NEW.ends_at
      )::text
    );
  END IF;

  -- When a subscription is confirmed (bank transfer confirmed), activate driver
  IF NEW.status = 'active' AND OLD.status != 'active' AND NEW.confirmed_at IS NOT NULL THEN
    UPDATE drivers
    SET status = 'active'
    WHERE id = NEW.driver_id AND status != 'suspended';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER driver_subscription_status_change
  AFTER UPDATE ON driver_subscriptions
  FOR EACH ROW EXECUTE FUNCTION on_subscription_status_change();

-- Auto-expire subscriptions whose end date has passed
CREATE OR REPLACE FUNCTION expire_old_subscriptions()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE driver_subscriptions
  SET status = 'expired'
  WHERE status = 'active' AND ends_at <= now();
END;
$$;

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE driver_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_transfers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments              ENABLE ROW LEVEL SECURITY;

-- ---- driver_subscriptions ----
CREATE POLICY "subs_select_own"
  ON driver_subscriptions FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "subs_insert_own"
  ON driver_subscriptions FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "subs_update_own_autorenew"
  ON driver_subscriptions FOR UPDATE
  USING (auth.uid() = driver_id);

CREATE POLICY "subs_admin_all"
  ON driver_subscriptions FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ---- bank_transfers ----
-- Drivers can insert and view their own transfers
CREATE POLICY "bank_transfers_select_own"
  ON bank_transfers FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "bank_transfers_insert_own"
  ON bank_transfers FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

-- Admins can view and update all transfers
CREATE POLICY "bank_transfers_admin_all"
  ON bank_transfers FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ---- payments ----
-- Passengers see payments for their own rides
CREATE POLICY "payments_select_passenger"
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rides
      WHERE rides.id = payments.ride_id AND rides.passenger_id = auth.uid()
    )
  );

-- Drivers see payments for their rides
CREATE POLICY "payments_select_driver"
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rides
      WHERE rides.id = payments.ride_id AND rides.driver_id = auth.uid()
    )
  );

-- Payments inserted by service role (webhooks)
CREATE POLICY "payments_admin_all"
  ON payments FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
