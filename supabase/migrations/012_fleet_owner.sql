-- =============================================================
-- Migration 012: Fleet Owner Feature
-- Adds fleet owner role, tables, triggers, RLS, and cron jobs
-- =============================================================

-- =============================================================
-- 1. Update profiles.role CHECK to include fleet_owner
-- =============================================================
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('passenger', 'driver', 'admin', 'fleet_owner'));

-- =============================================================
-- 2. fleet_owner_subscription_plans
-- =============================================================
CREATE TABLE IF NOT EXISTS fleet_owner_subscription_plans (
  id              uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            text        NOT NULL,
  max_vehicles    integer     NOT NULL CHECK (max_vehicles > 0),
  monthly_fee_etb integer     NOT NULL CHECK (monthly_fee_etb >= 0),
  features        jsonb       NOT NULL DEFAULT '{}',
  -- features example: {"daily_summary_notification": true}
  is_active       boolean     NOT NULL DEFAULT true,
  updated_by      uuid        REFERENCES profiles(id),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Seed two default plans
INSERT INTO fleet_owner_subscription_plans (name, max_vehicles, monthly_fee_etb, features) VALUES
  ('Basic',    5,  500,  '{"daily_summary_notification": false}'::jsonb),
  ('Premium', 20, 1500,  '{"daily_summary_notification": true}'::jsonb)
ON CONFLICT DO NOTHING;

-- =============================================================
-- 3. fleet_owners
-- =============================================================
CREATE TABLE IF NOT EXISTS fleet_owners (
  id                    uuid        PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  company_name          text,
  tax_id                text,
  subscription_plan_id  uuid        REFERENCES fleet_owner_subscription_plans(id),
  subscription_expiry   timestamptz,
  is_active             boolean     NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER fleet_owners_updated_at
  BEFORE UPDATE ON fleet_owners
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- 4. fleet_vehicles
-- =============================================================
CREATE TABLE IF NOT EXISTS fleet_vehicles (
  id               uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  fleet_owner_id   uuid        NOT NULL REFERENCES fleet_owners(id) ON DELETE CASCADE,
  plate_number     text        NOT NULL UNIQUE,
  model            text,
  color            text,
  year             integer     CHECK (year >= 2000 AND year <= extract(year FROM now()) + 1),
  photo_url        text,
  vehicle_type     text        NOT NULL DEFAULT 'sedan'
                               CHECK (vehicle_type IN ('sedan','suv','vip','minibus')),
  is_car_active    boolean     NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fleet_vehicles_owner  ON fleet_vehicles(fleet_owner_id);
CREATE INDEX IF NOT EXISTS idx_fleet_vehicles_active ON fleet_vehicles(is_car_active);

CREATE TRIGGER fleet_vehicles_updated_at
  BEFORE UPDATE ON fleet_vehicles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- 5. fleet_driver_assignments
-- =============================================================
CREATE TABLE IF NOT EXISTS fleet_driver_assignments (
  id                    uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  fleet_owner_id        uuid        NOT NULL REFERENCES fleet_owners(id) ON DELETE CASCADE,
  fleet_vehicle_id      uuid        NOT NULL REFERENCES fleet_vehicles(id) ON DELETE CASCADE,
  driver_id             uuid        NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  revenue_share_type    text        NOT NULL
                                    CHECK (revenue_share_type IN
                                      ('percentage','daily_rent','weekly_rent','monthly_rent')),
  revenue_share_value   integer     NOT NULL CHECK (revenue_share_value >= 0),
  max_daily_trips       integer,                  -- NULL = unlimited
  daily_trips_count     integer     NOT NULL DEFAULT 0,  -- reset daily via cron
  settlement_cycle      text        NOT NULL DEFAULT 'weekly'
                                    CHECK (settlement_cycle IN ('daily','weekly','monthly')),
  is_active             boolean     NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  -- One active driver per vehicle at a time
  UNIQUE (fleet_vehicle_id)
);

CREATE INDEX IF NOT EXISTS idx_fda_driver ON fleet_driver_assignments(driver_id);
CREATE INDEX IF NOT EXISTS idx_fda_owner  ON fleet_driver_assignments(fleet_owner_id);

CREATE TRIGGER fleet_driver_assignments_updated_at
  BEFORE UPDATE ON fleet_driver_assignments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- 6. fleet_settlements
-- =============================================================
CREATE TABLE IF NOT EXISTS fleet_settlements (
  id               uuid         PRIMARY KEY DEFAULT uuid_generate_v4(),
  fleet_owner_id   uuid         NOT NULL REFERENCES fleet_owners(id),
  assignment_id    uuid         NOT NULL REFERENCES fleet_driver_assignments(id),
  period_start     timestamptz  NOT NULL,
  period_end       timestamptz  NOT NULL,
  total_fare       numeric(12,2) NOT NULL DEFAULT 0,
  owner_share      numeric(12,2) NOT NULL DEFAULT 0,
  driver_share     numeric(12,2) NOT NULL DEFAULT 0,
  waived           boolean       NOT NULL DEFAULT false,
  receipt_url      text,
  confirmed        boolean       NOT NULL DEFAULT false,
  created_at       timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fleet_settlements_owner      ON fleet_settlements(fleet_owner_id);
CREATE INDEX IF NOT EXISTS idx_fleet_settlements_assignment ON fleet_settlements(assignment_id);

-- =============================================================
-- 7. fleet_work_model_history
-- Tracks changes to work model for mid-cycle audit
-- =============================================================
CREATE TABLE IF NOT EXISTS fleet_work_model_history (
  id              uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  assignment_id   uuid        NOT NULL REFERENCES fleet_driver_assignments(id) ON DELETE CASCADE,
  revenue_share_type  text    NOT NULL,
  revenue_share_value integer NOT NULL,
  effective_from  timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 8. fleet_terms_acceptances
-- Records T&C acceptance by fleet owners and fleet drivers
-- =============================================================
CREATE TABLE IF NOT EXISTS fleet_terms_acceptances (
  id              uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role            text        NOT NULL CHECK (role IN ('fleet_owner', 'fleet_driver')),
  version         text        NOT NULL DEFAULT '1.0',
  accepted_at     timestamptz NOT NULL DEFAULT now(),
  device_info     jsonb,
  UNIQUE (user_id, role, version)
);

-- =============================================================
-- 9. admin_fleet_staff
-- Admin employees with permission to manage fleet owners
-- =============================================================
CREATE TABLE IF NOT EXISTS admin_fleet_staff (
  id                        uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                   uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  can_manage_fleet_owners   boolean     NOT NULL DEFAULT true,
  can_edit_plans            boolean     NOT NULL DEFAULT false,
  created_by                uuid        REFERENCES profiles(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

-- =============================================================
-- 10. Extend drivers table
-- =============================================================
ALTER TABLE drivers
  ADD COLUMN IF NOT EXISTS fleet_owner_id uuid  REFERENCES fleet_owners(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_fleet_driver boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_drivers_fleet_owner ON drivers(fleet_owner_id);

-- =============================================================
-- 11. Trigger: increment daily_trips_count when ride completes
-- =============================================================
CREATE OR REPLACE FUNCTION increment_fleet_daily_trips()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE fleet_driver_assignments
    SET daily_trips_count = daily_trips_count + 1
    WHERE driver_id = NEW.driver_id
      AND is_active = true;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER rides_fleet_daily_trips
  AFTER UPDATE OF status ON rides
  FOR EACH ROW EXECUTE FUNCTION increment_fleet_daily_trips();

-- =============================================================
-- 12. Trigger: log work model changes to history
-- =============================================================
CREATE OR REPLACE FUNCTION log_fleet_work_model_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (NEW.revenue_share_type != OLD.revenue_share_type
      OR NEW.revenue_share_value != OLD.revenue_share_value) THEN
    INSERT INTO fleet_work_model_history
      (assignment_id, revenue_share_type, revenue_share_value)
    VALUES
      (NEW.id, NEW.revenue_share_type, NEW.revenue_share_value);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER fleet_assignment_work_model_log
  AFTER UPDATE OF revenue_share_type, revenue_share_value ON fleet_driver_assignments
  FOR EACH ROW EXECUTE FUNCTION log_fleet_work_model_change();

-- =============================================================
-- 13. RPC: calculate_fleet_settlement
-- Returns settlement figures for an assignment over a period
-- =============================================================
CREATE OR REPLACE FUNCTION calculate_fleet_settlement(
  p_assignment_id  uuid,
  p_period_start   timestamptz,
  p_period_end     timestamptz
)
RETURNS TABLE (
  total_fare   numeric,
  owner_share  numeric,
  driver_share numeric,
  waived       boolean
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_type          text;
  v_value         integer;
  v_cycle         text;
  v_total         numeric(12,2);
  v_owner         numeric(12,2);
  v_driver        numeric(12,2);
  v_days          integer;
  v_waived        boolean;
BEGIN
  SELECT
    fda.revenue_share_type,
    fda.revenue_share_value,
    fda.settlement_cycle,
    COALESCE(
      (SELECT SUM(r.final_price)
       FROM rides r
       WHERE r.driver_id = fda.driver_id
         AND r.status = 'completed'
         AND r.completed_at BETWEEN p_period_start AND p_period_end),
      0
    )::numeric(12,2),
    COALESCE(
      (SELECT fs.waived FROM fleet_settlements fs
       WHERE fs.assignment_id = p_assignment_id
         AND fs.period_start = p_period_start
         AND fs.period_end = p_period_end
       LIMIT 1),
      false
    )
  INTO v_type, v_value, v_cycle, v_total, v_waived
  FROM fleet_driver_assignments fda
  WHERE fda.id = p_assignment_id;

  IF v_waived THEN
    RETURN QUERY SELECT v_total, 0::numeric, v_total, true;
    RETURN;
  END IF;

  IF v_type = 'percentage' THEN
    v_driver := ROUND(v_total * v_value / 100.0, 2);
    v_owner  := v_total - v_driver;
  ELSIF v_type = 'daily_rent' THEN
    v_days  := GREATEST(1, DATE_PART('day', p_period_end - p_period_start)::integer + 1);
    v_owner := LEAST(v_total, (v_value * v_days)::numeric(12,2));
    v_driver := v_total - v_owner;
  ELSIF v_type = 'weekly_rent' THEN
    v_owner := LEAST(v_total, v_value::numeric(12,2));
    v_driver := v_total - v_owner;
  ELSIF v_type = 'monthly_rent' THEN
    v_owner := LEAST(v_total, v_value::numeric(12,2));
    v_driver := v_total - v_owner;
  ELSE
    v_owner  := 0;
    v_driver := v_total;
  END IF;

  RETURN QUERY SELECT v_total, v_owner, v_driver, false;
END;
$$;

-- =============================================================
-- 14. Update find_nearby_drivers to respect fleet restrictions
-- =============================================================
CREATE OR REPLACE FUNCTION find_nearby_drivers(
  center_lat       double precision,
  center_lng       double precision,
  radius_meters    double precision,
  p_vehicle_type   text
)
RETURNS TABLE (
  driver_id        uuid,
  lat              double precision,
  lng              double precision,
  distance_meters  double precision,
  heading          double precision
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  WITH candidate_drivers AS (
    SELECT
      dl.driver_id,
      dl.lat,
      dl.lng,
      dl.heading,
      earth_distance(
        ll_to_earth(center_lat, center_lng),
        ll_to_earth(dl.lat, dl.lng)
      ) AS dist_m,
      d.preferred_dest_lat,
      d.preferred_dest_lng,
      d.preferred_dest_enabled,
      d.preferred_dest_radius_km
    FROM driver_locations dl
    JOIN drivers d ON d.id = dl.driver_id
    -- For non-fleet drivers: join vehicles as before
    LEFT JOIN vehicles v ON v.driver_id = dl.driver_id AND d.is_fleet_driver = false
    -- For fleet drivers: join via assignment → fleet_vehicles
    LEFT JOIN fleet_driver_assignments fda ON fda.driver_id = dl.driver_id AND fda.is_active = true
    LEFT JOIN fleet_vehicles fv ON fv.id = fda.fleet_vehicle_id
    LEFT JOIN fleet_owners fo ON fo.id = d.fleet_owner_id
    WHERE
      dl.is_online = true
      AND d.status = 'active'
      AND earth_distance(
            ll_to_earth(center_lat, center_lng),
            ll_to_earth(dl.lat, dl.lng)
          ) <= radius_meters
      -- Vehicle type filter: fleet vehicle or personal vehicle
      AND (
        (d.is_fleet_driver = false AND v.type = p_vehicle_type AND v.is_active = true)
        OR
        (d.is_fleet_driver = true  AND fv.vehicle_type = p_vehicle_type AND fv.is_car_active = true)
      )
      -- Fleet owner must be active and subscription valid
      AND (
        d.is_fleet_driver = false
        OR (fo.is_active = true AND (fo.subscription_expiry IS NULL OR fo.subscription_expiry > now()))
      )
      -- Respect max daily trips limit
      AND (
        d.is_fleet_driver = false
        OR fda.max_daily_trips IS NULL
        OR fda.daily_trips_count < fda.max_daily_trips
      )
  ),
  scored AS (
    SELECT
      cd.driver_id,
      cd.lat,
      cd.lng,
      cd.heading,
      cd.dist_m,
      CASE
        WHEN cd.preferred_dest_enabled
             AND cd.preferred_dest_lat IS NOT NULL
             AND cd.preferred_dest_lng IS NOT NULL
             AND earth_distance(
                   ll_to_earth(cd.preferred_dest_lat, cd.preferred_dest_lng),
                   ll_to_earth(center_lat, center_lng)
                 ) <= (cd.preferred_dest_radius_km * 1000)
        THEN cd.dist_m - 1000
        ELSE cd.dist_m
      END AS sort_score
    FROM candidate_drivers cd
  )
  SELECT
    s.driver_id,
    s.lat,
    s.lng,
    s.dist_m  AS distance_meters,
    s.heading
  FROM scored s
  ORDER BY s.sort_score ASC;
END;
$$;

-- =============================================================
-- 15. RLS Policies
-- =============================================================
ALTER TABLE fleet_owner_subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleet_owners                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleet_vehicles                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleet_driver_assignments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleet_settlements              ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleet_work_model_history       ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleet_terms_acceptances        ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_fleet_staff              ENABLE ROW LEVEL SECURITY;

-- fleet_owner_subscription_plans: everyone can read active plans
CREATE POLICY "plans_select_active"
  ON fleet_owner_subscription_plans FOR SELECT
  USING (is_active = true OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

CREATE POLICY "plans_admin_all"
  ON fleet_owner_subscription_plans FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_owners
CREATE POLICY "fleet_owners_select_own"
  ON fleet_owners FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "fleet_owners_update_own"
  ON fleet_owners FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "fleet_owners_insert_own"
  ON fleet_owners FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "fleet_owners_admin_all"
  ON fleet_owners FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "fleet_owners_staff_select"
  ON fleet_owners FOR SELECT
  USING (EXISTS (SELECT 1 FROM admin_fleet_staff WHERE user_id = auth.uid()));

CREATE POLICY "fleet_owners_staff_update"
  ON fleet_owners FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM admin_fleet_staff
    WHERE user_id = auth.uid() AND can_manage_fleet_owners = true
  ));

-- fleet_vehicles
CREATE POLICY "fleet_vehicles_owner_all"
  ON fleet_vehicles FOR ALL
  USING (EXISTS (
    SELECT 1 FROM fleet_owners WHERE id = fleet_owner_id AND id = auth.uid()
  ));

CREATE POLICY "fleet_vehicles_driver_select"
  ON fleet_vehicles FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM fleet_driver_assignments fda
    WHERE fda.fleet_vehicle_id = id AND fda.driver_id = auth.uid()
  ));

CREATE POLICY "fleet_vehicles_admin_all"
  ON fleet_vehicles FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_driver_assignments
CREATE POLICY "fda_owner_all"
  ON fleet_driver_assignments FOR ALL
  USING (EXISTS (
    SELECT 1 FROM fleet_owners WHERE id = fleet_owner_id AND id = auth.uid()
  ));

CREATE POLICY "fda_driver_select"
  ON fleet_driver_assignments FOR SELECT
  USING (driver_id = auth.uid());

CREATE POLICY "fda_admin_all"
  ON fleet_driver_assignments FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_settlements
CREATE POLICY "settlements_owner_all"
  ON fleet_settlements FOR ALL
  USING (fleet_owner_id = auth.uid());

CREATE POLICY "settlements_driver_select"
  ON fleet_settlements FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM fleet_driver_assignments WHERE id = assignment_id AND driver_id = auth.uid()
  ));

CREATE POLICY "settlements_driver_update_receipt"
  ON fleet_settlements FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM fleet_driver_assignments WHERE id = assignment_id AND driver_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM fleet_driver_assignments WHERE id = assignment_id AND driver_id = auth.uid()
  ));

CREATE POLICY "settlements_admin_all"
  ON fleet_settlements FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_work_model_history
CREATE POLICY "work_model_history_owner_select"
  ON fleet_work_model_history FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM fleet_driver_assignments fda
    JOIN fleet_owners fo ON fo.id = fda.fleet_owner_id
    WHERE fda.id = assignment_id AND fo.id = auth.uid()
  ));

CREATE POLICY "work_model_history_admin_all"
  ON fleet_work_model_history FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_terms_acceptances
CREATE POLICY "terms_own"
  ON fleet_terms_acceptances FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "terms_admin_select"
  ON fleet_terms_acceptances FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- admin_fleet_staff
CREATE POLICY "fleet_staff_self_select"
  ON admin_fleet_staff FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "fleet_staff_admin_all"
  ON admin_fleet_staff FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- =============================================================
-- 16. Cron jobs
-- =============================================================

-- Reset daily trip counts at midnight
SELECT cron.schedule(
  'reset-fleet-daily-trips',
  '0 0 * * *',
  $$UPDATE fleet_driver_assignments SET daily_trips_count = 0 WHERE is_active = true;$$
);

-- Deactivate expired fleet owner accounts at 1am
SELECT cron.schedule(
  'deactivate-expired-fleet-owners',
  '5 1 * * *',
  $$
    UPDATE fleet_owners
    SET is_active = false
    WHERE subscription_expiry < now()
      AND is_active = true;
  $$
);

-- Fleet daily summary notifications at 8am (calls Edge Function)
SELECT cron.schedule(
  'fleet-daily-summary',
  '0 8 * * *',
  $$
    SELECT net.http_post(
      url     := current_setting('app.supabase_url') || '/functions/v1/fleet-daily-summary',
      headers := jsonb_build_object(
                   'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
                   'Content-Type',  'application/json'
                 ),
      body    := '{}'::jsonb
    );
  $$
);

-- Notify fleet owners 7 days before subscription expiry
SELECT cron.schedule(
  'fleet-expiry-warning',
  '0 9 * * *',
  $$
    SELECT net.http_post(
      url     := current_setting('app.supabase_url') || '/functions/v1/fleet-expiry-warning',
      headers := jsonb_build_object(
                   'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
                   'Content-Type',  'application/json'
                 ),
      body    := '{}'::jsonb
    );
  $$
);

-- =============================================================
-- 17. Grants
-- =============================================================
GRANT EXECUTE ON FUNCTION calculate_fleet_settlement(uuid, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION find_nearby_drivers(double precision, double precision, double precision, text) TO authenticated;
GRANT SELECT ON fleet_owner_subscription_plans TO authenticated;
