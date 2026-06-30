-- Migration 021: driver_priority_grants table + process-active-days cron job

-- 1. Table for priority hour grants (from reward boxes or admin)
CREATE TABLE IF NOT EXISTS driver_priority_grants (
  id         uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id  uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  hours      integer     NOT NULL,
  source     text        NOT NULL,   -- 'reward_box' | 'admin' | 'achievement'
  granted_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_priority_grants_driver
  ON driver_priority_grants(driver_id, expires_at);

ALTER TABLE driver_priority_grants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "priority_grants_driver_select"
  ON driver_priority_grants
  FOR SELECT
  USING (driver_id = auth.uid());

-- 2. Schedule process-active-days to run daily at 01:00 UTC
SELECT cron.schedule(
  'process-active-days',
  '0 1 * * *',
  $$
    SELECT net.http_post(
      url     => current_setting('app.supabase_url') || '/functions/v1/process-active-days',
      headers => jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key')
      ),
      body    => '{}'::jsonb
    )
  $$
);
