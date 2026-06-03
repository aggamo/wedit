-- Migration 016: Call Center Flow Fixes
-- Adds ride_declines table, makes dropoff columns nullable,
-- adds 'seeking' ride status for auto-retry, and seek_retry_at timestamp.

-- ── 1. ride_declines table ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ride_declines (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  ride_id    uuid        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  driver_id  uuid        NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ride_declines_ride_id
  ON ride_declines (ride_id);

-- ── 2. Make dropoff columns nullable (call_center rides may not have destination)

ALTER TABLE rides
  ALTER COLUMN dropoff_lat DROP NOT NULL,
  ALTER COLUMN dropoff_lng DROP NOT NULL;

-- ── 3. seek_retry_at — timestamp for auto-reassignment after all drivers decline

ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS seek_retry_at timestamptz;

-- ── 4. Add 'seeking' to rides.status constraint

ALTER TABLE rides DROP CONSTRAINT IF EXISTS rides_status_check;
ALTER TABLE rides ADD CONSTRAINT rides_status_check
  CHECK (status IN (
    'requested', 'pending', 'accepted', 'driver_arrived',
    'in_progress', 'completed', 'cancelled', 'seeking'
  ));

-- ── 5. RLS for ride_declines

ALTER TABLE ride_declines ENABLE ROW LEVEL SECURITY;

-- Drivers can insert their own declines
CREATE POLICY "driver_insert_own_decline"
  ON ride_declines FOR INSERT
  WITH CHECK (driver_id = auth.uid());

-- Admins can read all
CREATE POLICY "admin_read_ride_declines"
  ON ride_declines FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );
-- Service role bypasses RLS automatically.
