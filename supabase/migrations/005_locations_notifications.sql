-- =============================================================
-- Migration 005: Driver Locations, Notifications, Complaints
-- =============================================================

-- =============================================================
-- driver_locations table (upserted frequently by driver app)
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_locations (
  driver_id   uuid            PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  lat         double precision NOT NULL,
  lng         double precision NOT NULL,
  heading     double precision NOT NULL DEFAULT 0
              CHECK (heading >= 0 AND heading < 360),
  speed       double precision NOT NULL DEFAULT 0 CHECK (speed >= 0),
  is_online   boolean         NOT NULL DEFAULT false,
  updated_at  timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_driver_locations_online
  ON driver_locations(is_online)
  WHERE is_online = true;

-- Spatial index using earthdistance cube representation
CREATE INDEX IF NOT EXISTS idx_driver_locations_geo
  ON driver_locations
  USING gist(ll_to_earth(lat, lng));

-- Auto-update updated_at on location change
CREATE OR REPLACE FUNCTION driver_locations_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER driver_locations_updated_at
  BEFORE INSERT OR UPDATE ON driver_locations
  FOR EACH ROW EXECUTE FUNCTION driver_locations_set_updated_at();

-- =============================================================
-- notifications table
-- =============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id         uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title      text        NOT NULL,
  body       text        NOT NULL,
  type       text        NOT NULL DEFAULT 'general'
             CHECK (type IN (
               'ride_request','ride_accepted','ride_started','ride_completed',
               'payment','subscription','leaderboard','general'
             )),
  data       jsonb       NOT NULL DEFAULT '{}',
  is_read    boolean     NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user    ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread  ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_type    ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- =============================================================
-- complaints table
-- =============================================================
CREATE TABLE IF NOT EXISTS complaints (
  id               uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id      uuid        NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  reported_user_id uuid        NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  ride_id          uuid        REFERENCES rides(id) ON DELETE SET NULL,
  category         text        NOT NULL
                  CHECK (category IN (
                    'driver_behavior','passenger_behavior','payment','app_issue','other'
                  )),
  description      text        NOT NULL,
  status           text        NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','investigating','resolved','closed')),
  admin_note       text,
  resolved_by      uuid        REFERENCES profiles(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT complaints_no_self_report CHECK (reporter_id != reported_user_id)
);

CREATE INDEX IF NOT EXISTS idx_complaints_reporter  ON complaints(reporter_id);
CREATE INDEX IF NOT EXISTS idx_complaints_reported  ON complaints(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status    ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_ride      ON complaints(ride_id) WHERE ride_id IS NOT NULL;

CREATE TRIGGER complaints_updated_at
  BEFORE UPDATE ON complaints
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- Enable Supabase Realtime on key tables
-- =============================================================
-- Note: Supabase Realtime is configured via the Supabase dashboard
-- or supabase/config.toml. The SQL below uses the low-level
-- supabase_realtime publication which Supabase manages.
-- Adding tables to the publication enables CDC-based broadcasts.

DO $$
BEGIN
  -- driver_locations
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'driver_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE driver_locations;
  END IF;

  -- rides
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'rides'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE rides;
  END IF;

  -- ride_offers
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'ride_offers'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE ride_offers;
  END IF;

  -- notifications
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  END IF;
END
$$;

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications     ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints         ENABLE ROW LEVEL SECURITY;

-- ---- driver_locations ----
-- Drivers can upsert their own location
CREATE POLICY "driver_locations_upsert_own"
  ON driver_locations FOR ALL
  USING (auth.uid() = driver_id)
  WITH CHECK (auth.uid() = driver_id);

-- All authenticated users can read online driver locations (for map display)
CREATE POLICY "driver_locations_select_online"
  ON driver_locations FOR SELECT
  USING (auth.role() = 'authenticated' AND is_online = true);

-- ---- notifications ----
-- Users see only their own notifications
CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Users can mark their own notifications as read
CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role and admins can insert notifications for any user
CREATE POLICY "notifications_admin_insert"
  ON notifications FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Admins see all notifications
CREATE POLICY "notifications_admin_all"
  ON notifications FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ---- complaints ----
-- Reporters see their own complaints
CREATE POLICY "complaints_select_own"
  ON complaints FOR SELECT
  USING (auth.uid() = reporter_id);

-- Authenticated users can submit complaints
CREATE POLICY "complaints_insert_own"
  ON complaints FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- Admins see and manage all complaints
CREATE POLICY "complaints_admin_all"
  ON complaints FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
