-- Migration 015: AI Voice Call Center
-- Adds ai_call ride type and ai_call_logs table for the AI-powered voice IVR system.

-- ── 1. Add ai_call to ride_type constraint ────────────────────────────────────

ALTER TABLE rides DROP CONSTRAINT IF EXISTS rides_ride_type_check;
ALTER TABLE rides
  ADD CONSTRAINT rides_ride_type_check
  CHECK (ride_type IN ('app_request', 'street_hail', 'call_center', 'ai_call'));

-- ── 2. ai_call_logs table ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ai_call_logs (
  id               uuid         DEFAULT gen_random_uuid() PRIMARY KEY,
  call_sid         text         NOT NULL,
  passenger_phone  text         NOT NULL,
  raw_transcript   text,
  pickup_text      text,
  destination_text text,
  pickup_lat       numeric(10, 7),
  pickup_lng       numeric(10, 7),
  vehicle_type     text         NOT NULL DEFAULT 'sedan',
  confidence_score numeric(4, 3),
  status           text         NOT NULL DEFAULT 'in_progress'
                   CHECK (status IN ('in_progress', 'dispatched', 'no_driver', 'failed')),
  ride_id          uuid         REFERENCES rides(id) ON DELETE SET NULL,
  retry_count      integer      NOT NULL DEFAULT 0,
  created_at       timestamptz  DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_call_logs_created_at
  ON ai_call_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_call_logs_status
  ON ai_call_logs (status);

CREATE INDEX IF NOT EXISTS idx_ai_call_logs_passenger_phone
  ON ai_call_logs (passenger_phone);

-- ── 3. RLS ────────────────────────────────────────────────────────────────────

ALTER TABLE ai_call_logs ENABLE ROW LEVEL SECURITY;

-- Admin full access
CREATE POLICY "admin_full_access_ai_call_logs"
  ON ai_call_logs FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Edge Functions use service_role key which bypasses RLS automatically.
