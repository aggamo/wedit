-- Migration 011: Street Hail / Quick Ride
-- Adds ride_type discrimination, passenger_phone, and SMS logging infrastructure.

-- ── 1. ride_type on rides table ───────────────────────────────────────────────

ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS ride_type TEXT NOT NULL DEFAULT 'app_request'
    CHECK (ride_type IN ('app_request', 'street_hail'));

ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS passenger_phone TEXT;

ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS distance_km numeric(8,2);

-- ── 2. sms_logs table ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sms_logs (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id          uuid REFERENCES rides(id) ON DELETE SET NULL,
  phone_number     text NOT NULL,
  message_type     text NOT NULL CHECK (message_type IN ('ride_start', 'ride_end')),
  message_body     text NOT NULL,
  status           text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'sent', 'failed')),
  provider_response jsonb,
  created_at       timestamptz NOT NULL DEFAULT now(),
  sent_at          timestamptz
);

CREATE INDEX IF NOT EXISTS sms_logs_ride_idx    ON sms_logs (ride_id);
CREATE INDEX IF NOT EXISTS sms_logs_status_idx  ON sms_logs (status, created_at DESC);

-- ── 3. RLS for sms_logs ───────────────────────────────────────────────────────

ALTER TABLE sms_logs ENABLE ROW LEVEL SECURITY;

-- Drivers can see SMS logs for their own rides
CREATE POLICY "sms_logs_driver_read" ON sms_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM rides
      WHERE rides.id = sms_logs.ride_id
        AND rides.driver_id = auth.uid()
    )
  );

-- Service role (Edge Functions) can do everything
CREATE POLICY "sms_logs_service_role" ON sms_logs
  FOR ALL TO service_role USING (true);

-- ── 4. Grant send-sms Edge Function access ────────────────────────────────────
-- (Service role is used inside the Edge Function, so this is automatic via supabase-js)

-- ── 5. Helper: street_hail fare estimate ─────────────────────────────────────
-- Convenience function called by the app to verify fare at end of ride.

CREATE OR REPLACE FUNCTION calculate_street_hail_fare(
  p_vehicle_type   text,
  p_distance_km    double precision,
  p_duration_min   double precision
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  base_fare     numeric;
  price_per_km  numeric;
  price_per_min numeric;
BEGIN
  CASE p_vehicle_type
    WHEN 'sedan'   THEN base_fare := 25; price_per_km := 8;  price_per_min := 1.5;
    WHEN 'suv'     THEN base_fare := 35; price_per_km := 12; price_per_min := 2.0;
    WHEN 'vip'     THEN base_fare := 60; price_per_km := 20; price_per_min := 3.5;
    WHEN 'minibus' THEN base_fare := 20; price_per_km := 6;  price_per_min := 1.0;
    ELSE                base_fare := 25; price_per_km := 8;  price_per_min := 1.5;
  END CASE;
  RETURN round(
    (base_fare + price_per_km * p_distance_km + price_per_min * p_duration_min)::numeric,
    2
  );
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_street_hail_fare(text, double precision, double precision)
  TO authenticated;

-- ── 6. Index to quickly find street_hail rides per driver ─────────────────────

CREATE INDEX IF NOT EXISTS rides_street_hail_driver_idx
  ON rides (driver_id, ride_type, created_at DESC)
  WHERE ride_type = 'street_hail';
