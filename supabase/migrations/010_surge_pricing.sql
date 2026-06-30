-- Migration 010: Surge Pricing & Offer Improvements
-- Adds surge pricing rules, price breakdown, is_system_price tracking,
-- and updates offer expiry from 30s to 45s.

-- ── 1. Surge pricing rules ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS surge_pricing_rules (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text NOT NULL,
  rule_type      text NOT NULL CHECK (rule_type IN ('fixed_hours','demand_based','manual','event')),
  multiplier     numeric(4,2) NOT NULL DEFAULT 1.5 CHECK (multiplier >= 1.0 AND multiplier <= 5.0),
  -- fixed_hours fields
  days_of_week   int[],   -- 0=Sunday … 6=Saturday
  start_time     time,
  end_time       time,
  -- manual / event fields
  active_from    timestamptz,
  active_until   timestamptz,
  is_active      boolean NOT NULL DEFAULT false,
  vehicle_types  text[],  -- NULL = applies to all types
  created_by     uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS surge_rules_active_idx ON surge_pricing_rules (is_active, rule_type);
CREATE INDEX IF NOT EXISTS surge_rules_updated_idx ON surge_pricing_rules (updated_at DESC);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION surge_rules_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS surge_rules_updated_at ON surge_pricing_rules;
CREATE TRIGGER surge_rules_updated_at
  BEFORE UPDATE ON surge_pricing_rules
  FOR EACH ROW EXECUTE FUNCTION surge_rules_set_updated_at();

-- ── 2. Extend rides table ─────────────────────────────────────────────────────

ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS surge_multiplier numeric(4,2) NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS price_breakdown  jsonb;

-- ── 3. Add is_system_price to ride_offers ─────────────────────────────────────

ALTER TABLE ride_offers
  ADD COLUMN IF NOT EXISTS is_system_price boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS ride_offers_system_price_idx
  ON ride_offers (ride_id, is_system_price, status, created_at)
  WHERE is_system_price = true AND status = 'pending';

-- ── 4. Update offer expiry default from 30s → 45s ─────────────────────────────

ALTER TABLE ride_offers
  ALTER COLUMN expires_at SET DEFAULT now() + interval '45 seconds';

-- ── 5. Updated calculate_estimated_price with duration & surge ─────────────────
--   Returns jsonb: {base, distance_fare, time_fare, surge_fee, total, surge_multiplier}

CREATE OR REPLACE FUNCTION calculate_estimated_price(
  distance_km       double precision,
  vehicle_type      text,
  duration_minutes  double precision DEFAULT 0,
  surge_mult        double precision DEFAULT 1.0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  base_fare      numeric := 0;
  price_per_km   numeric := 0;
  price_per_min  numeric := 0;
  dist_fare      numeric;
  time_fare      numeric;
  subtotal       numeric;
  surge_fee      numeric;
  total          numeric;
BEGIN
  CASE vehicle_type
    WHEN 'sedan' THEN
      base_fare := 25; price_per_km := 8; price_per_min := 1.5;
    WHEN 'suv' THEN
      base_fare := 35; price_per_km := 12; price_per_min := 2.0;
    WHEN 'vip' THEN
      base_fare := 60; price_per_km := 20; price_per_min := 3.5;
    WHEN 'minibus' THEN
      base_fare := 20; price_per_km := 6;  price_per_min := 1.0;
    ELSE
      base_fare := 25; price_per_km := 8; price_per_min := 1.5;
  END CASE;

  dist_fare := round((price_per_km * distance_km)::numeric, 2);
  time_fare := round((price_per_min * duration_minutes)::numeric, 2);
  subtotal  := base_fare + dist_fare + time_fare;
  surge_fee := round((subtotal * (surge_mult - 1))::numeric, 2);
  total     := round((subtotal + surge_fee)::numeric, 2);

  RETURN jsonb_build_object(
    'base',             base_fare,
    'distance_fare',    dist_fare,
    'time_fare',        time_fare,
    'surge_fee',        surge_fee,
    'total',            total,
    'surge_multiplier', round(surge_mult::numeric, 2)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_estimated_price(double precision, text, double precision, double precision)
  TO authenticated;

-- ── 6. get_current_surge_multiplier ──────────────────────────────────────────
--   Returns the highest active multiplier for a given vehicle type (or all).

CREATE OR REPLACE FUNCTION get_current_surge_multiplier(
  p_vehicle_type text DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  max_mult  numeric := 1.0;
  rule_mult numeric;
  now_ts    timestamptz := now();
  now_time  time := now_ts::time;
  now_dow   int  := EXTRACT(DOW FROM now_ts)::int;
BEGIN
  FOR rule_mult IN
    SELECT multiplier
    FROM   surge_pricing_rules
    WHERE  is_active = true
      AND (vehicle_types IS NULL
           OR p_vehicle_type IS NULL
           OR p_vehicle_type = ANY(vehicle_types))
      AND (
        (rule_type = 'fixed_hours'
          AND days_of_week IS NOT NULL
          AND now_dow = ANY(days_of_week)
          AND now_time BETWEEN start_time AND end_time)
        OR
        (rule_type IN ('manual', 'event')
          AND active_from IS NOT NULL
          AND active_until IS NOT NULL
          AND now_ts BETWEEN active_from AND active_until)
      )
  LOOP
    IF rule_mult > max_mult THEN
      max_mult := rule_mult;
    END IF;
  END LOOP;

  RETURN max_mult;
END;
$$;

GRANT EXECUTE ON FUNCTION get_current_surge_multiplier(text) TO authenticated;

-- ── 7. RLS for surge_pricing_rules ───────────────────────────────────────────

ALTER TABLE surge_pricing_rules ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read active rules (to display surge warnings in-app)
CREATE POLICY "surge_rules_read" ON surge_pricing_rules
  FOR SELECT TO authenticated
  USING (true);

-- Only admins can write
CREATE POLICY "surge_rules_admin_write" ON surge_pricing_rules
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ── 8. Seed default peak-hour rules (disabled by default) ────────────────────

INSERT INTO surge_pricing_rules
  (name, rule_type, multiplier, days_of_week, start_time, end_time, is_active)
VALUES
  ('ذروة الصباح',    'fixed_hours', 1.3, ARRAY[0,1,2,3,4], '07:00', '09:00', false),
  ('ذروة المساء',    'fixed_hours', 1.4, ARRAY[0,1,2,3,4], '17:00', '19:30', false),
  ('ليلة نهاية الأسبوع', 'fixed_hours', 1.2, ARRAY[5,6],  '20:00', '23:59', false)
ON CONFLICT DO NOTHING;
