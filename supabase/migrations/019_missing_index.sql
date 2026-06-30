-- Performance index for driver ride history queries and process-active-days
-- Covers: earnings reports, activity day calculations, and streak checks
CREATE INDEX IF NOT EXISTS idx_rides_driver_completed
  ON rides(driver_id, completed_at DESC)
  WHERE status = 'completed';
