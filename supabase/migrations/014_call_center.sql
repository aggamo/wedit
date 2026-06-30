-- Migration 014: Call Center
-- Adds call_center ride type and call_center_agents management table.

-- ── 1. Add call_center to ride_type constraint ─────────────────────────────

ALTER TABLE rides DROP CONSTRAINT IF EXISTS rides_ride_type_check;
ALTER TABLE rides
  ADD CONSTRAINT rides_ride_type_check
  CHECK (ride_type IN ('app_request', 'street_hail', 'call_center'));

-- ── 2. call_center_agents table ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS call_center_agents (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_call_center_agents_profile
  ON call_center_agents (profile_id);

-- ── 3. RLS ─────────────────────────────────────────────────────────────────────

ALTER TABLE call_center_agents ENABLE ROW LEVEL SECURITY;

-- Admin full access
CREATE POLICY "admin_full_access_call_center_agents"
  ON call_center_agents FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Call center agents can read their own record
CREATE POLICY "agent_read_own"
  ON call_center_agents FOR SELECT
  USING (profile_id = auth.uid());

-- ── 4. Grant call_center_agent read on rides / drivers / driver_locations ──────

-- (Admins already have full access via existing policies.
--  Call-center agents need read-only access to dispatch.)

CREATE POLICY "call_center_read_rides"
  ON rides FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM call_center_agents
      WHERE profile_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "call_center_read_driver_locations"
  ON driver_locations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM call_center_agents
      WHERE profile_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "call_center_read_drivers"
  ON drivers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM call_center_agents
      WHERE profile_id = auth.uid() AND is_active = true
    )
  );
