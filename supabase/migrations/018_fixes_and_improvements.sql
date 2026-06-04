-- =============================================================
-- Migration 018: Bug Fixes + Structural Improvements
-- =============================================================

-- =============================================================
-- Section 1: Add distance_km to rides
-- Required by lifetime_stats trigger and point earning rules
-- =============================================================
ALTER TABLE rides ADD COLUMN IF NOT EXISTS distance_km numeric(8,2);

-- =============================================================
-- Section 2: Fix update_lifetime_stats_on_ride trigger
-- Previous version used fare_amount and driver_rating which
-- do not exist in rides table.
-- =============================================================
CREATE OR REPLACE FUNCTION update_lifetime_stats_on_ride()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO driver_lifetime_stats (
      driver_id, total_rides, total_km, total_income_etb,
      first_ride_at, last_ride_at
    ) VALUES (
      NEW.driver_id,
      1,
      COALESCE(NEW.distance_km, 0),
      COALESCE(NEW.final_price, 0),
      NEW.completed_at,
      NEW.completed_at
    )
    ON CONFLICT (driver_id) DO UPDATE SET
      total_rides      = driver_lifetime_stats.total_rides + 1,
      total_km         = driver_lifetime_stats.total_km + COALESCE(NEW.distance_km, 0),
      total_income_etb = driver_lifetime_stats.total_income_etb + COALESCE(NEW.final_price, 0),
      first_ride_at    = COALESCE(driver_lifetime_stats.first_ride_at, NEW.completed_at),
      last_ride_at     = NEW.completed_at,
      updated_at       = now();
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger is already created in 017 with same name — REPLACE is enough above.

-- =============================================================
-- Section 3: Add trigger on ratings to count 5-star rides
-- total_5star_rides cannot be populated from rides trigger
-- because score lives in a separate ratings table.
-- =============================================================
CREATE OR REPLACE FUNCTION update_lifetime_5star_on_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_driver_id uuid;
BEGIN
  -- Find the driver who received this rating
  SELECT driver_id INTO v_driver_id
  FROM rides
  WHERE id = NEW.ride_id;

  -- Only count ratings given to the driver (rated_user = driver)
  IF NEW.rated_user = v_driver_id AND NEW.score = 5 THEN
    INSERT INTO driver_lifetime_stats (driver_id, total_5star_rides)
    VALUES (v_driver_id, 1)
    ON CONFLICT (driver_id) DO UPDATE SET
      total_5star_rides = driver_lifetime_stats.total_5star_rides + 1,
      updated_at        = now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ratings_update_5star_stats ON ratings;
CREATE TRIGGER ratings_update_5star_stats
  AFTER INSERT ON ratings
  FOR EACH ROW EXECUTE FUNCTION update_lifetime_5star_on_rating();

-- =============================================================
-- Section 4: Atomic point update functions
-- Replace SELECT+UPDATE pattern (race condition) with
-- single-statement UPDATE RETURNING.
-- =============================================================
CREATE OR REPLACE FUNCTION increment_driver_points(p_driver_id uuid, p_amount integer)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE profiles
  SET points = points + p_amount
  WHERE id = p_driver_id
  RETURNING points;
$$;

CREATE OR REPLACE FUNCTION deduct_driver_points(p_driver_id uuid, p_amount integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new integer;
BEGIN
  UPDATE profiles
  SET points = GREATEST(0, points - p_amount)
  WHERE id = p_driver_id AND points >= p_amount
  RETURNING points INTO v_new;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'رصيدك غير كافٍ';
  END IF;

  RETURN v_new;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_driver_points(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION deduct_driver_points(uuid, integer) TO authenticated, service_role;

-- =============================================================
-- Section 5: Remove denormalized freeze counters
-- Monthly freeze count is now computed from subscription_freezes
-- on-demand, eliminating counter drift bugs.
-- =============================================================
ALTER TABLE driver_subscriptions
  DROP COLUMN IF EXISTS freeze_count_month,
  DROP COLUMN IF EXISTS freeze_month_reset_at;

-- =============================================================
-- Section 6: Enforce one active subscription per driver
-- First expire duplicate actives (keep newest per driver),
-- then add partial unique index.
-- =============================================================
UPDATE driver_subscriptions
SET status = 'expired'
WHERE status = 'active'
  AND id NOT IN (
    SELECT DISTINCT ON (driver_id) id
    FROM driver_subscriptions
    WHERE status = 'active'
    ORDER BY driver_id, created_at DESC
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_subs_one_active_per_driver
  ON driver_subscriptions(driver_id)
  WHERE status = 'active';

-- =============================================================
-- Section 7: driver_activity_days
-- Denormalized daily summary updated via trigger on every
-- completed ride. Eliminates expensive COUNT queries in
-- process-active-days cron and personal goal calculation.
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_activity_days (
  id            uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id     uuid          NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  activity_date date          NOT NULL,
  rides_count   integer       NOT NULL DEFAULT 0,
  active_hours  numeric(4,2)  NOT NULL DEFAULT 0,
  income_etb    numeric(10,2) NOT NULL DEFAULT 0,
  qualified     boolean       NOT NULL DEFAULT false,
  created_at    timestamptz   NOT NULL DEFAULT now(),
  UNIQUE(driver_id, activity_date)
);

CREATE INDEX IF NOT EXISTS idx_activity_days_driver_date
  ON driver_activity_days(driver_id, activity_date DESC);

CREATE OR REPLACE FUNCTION update_activity_day_on_ride()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO driver_activity_days (driver_id, activity_date, rides_count, income_etb)
    VALUES (
      NEW.driver_id,
      (NEW.completed_at AT TIME ZONE 'UTC')::date,
      1,
      COALESCE(NEW.final_price, 0)
    )
    ON CONFLICT (driver_id, activity_date) DO UPDATE SET
      rides_count = driver_activity_days.rides_count + 1,
      income_etb  = driver_activity_days.income_etb + COALESCE(EXCLUDED.income_etb, 0);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rides_update_activity_day ON rides;
CREATE TRIGGER rides_update_activity_day
  AFTER UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION update_activity_day_on_ride();

-- RLS
ALTER TABLE driver_activity_days ENABLE ROW LEVEL SECURITY;

CREATE POLICY "activity_days_driver_select"
  ON driver_activity_days FOR SELECT
  USING (driver_id = auth.uid());

CREATE POLICY "activity_days_admin_all"
  ON driver_activity_days FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- =============================================================
-- Section 8: driver_level_state dormant columns
-- Replaces hard level-down penalty with a dormant flag.
-- Driver retains their level but loses benefits until active.
-- =============================================================
ALTER TABLE driver_level_state
  ADD COLUMN IF NOT EXISTS is_dormant   boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS dormant_since date;

-- =============================================================
-- Section 9: achievements — evaluation_scope
-- Lets check-achievements filter by event type for efficiency.
-- =============================================================
ALTER TABLE achievements
  ADD COLUMN IF NOT EXISTS evaluation_scope text
  DEFAULT 'any'
  CHECK (evaluation_scope IN ('ride','streak','rating','subscription','manual','any'));

UPDATE achievements SET evaluation_scope = 'ride'   WHERE trigger_type = 'ride_count';
UPDATE achievements SET evaluation_scope = 'streak' WHERE trigger_type = 'streak_days';
UPDATE achievements SET evaluation_scope = 'rating' WHERE trigger_type = 'rating_avg';
UPDATE achievements SET evaluation_scope = 'any'    WHERE trigger_type = 'xp_total';
UPDATE achievements SET evaluation_scope = 'manual' WHERE trigger_type = 'admin_manual';

-- =============================================================
-- Section 10: achievements — add referral_count trigger type
-- =============================================================
ALTER TABLE achievements DROP CONSTRAINT IF EXISTS achievements_trigger_type_check;
ALTER TABLE achievements ADD CONSTRAINT achievements_trigger_type_check
  CHECK (trigger_type IN (
    'ride_count','streak_days','xp_total','rating_avg',
    'referral_count','admin_manual'
  ));

INSERT INTO achievements
  (name_ar, trigger_type, trigger_value, reward_points, reward_xp, is_hidden, evaluation_scope, is_active)
VALUES
  ('أول صديق',      'referral_count', 1,  50,  100,  false, 'any', true),
  ('فريق wedit',    'referral_count', 5,  200, 500,  false, 'any', true),
  ('بناء المجتمع',  'referral_count', 20, 500, 2000, false, 'any', true)
ON CONFLICT DO NOTHING;

-- =============================================================
-- Section 11: Pity system for reward_boxes
-- After pity_threshold consecutive non-rare opens,
-- guarantee the pity_prize_id on next open.
-- =============================================================
ALTER TABLE reward_boxes
  ADD COLUMN IF NOT EXISTS pity_threshold integer,
  ADD COLUMN IF NOT EXISTS pity_prize_id  uuid REFERENCES box_prizes(id);

CREATE TABLE IF NOT EXISTS driver_box_pity (
  driver_id             uuid    NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  box_id                uuid    NOT NULL REFERENCES reward_boxes(id) ON DELETE CASCADE,
  opens_since_last_rare integer NOT NULL DEFAULT 0,
  PRIMARY KEY (driver_id, box_id)
);

ALTER TABLE driver_box_pity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "box_pity_driver_select"
  ON driver_box_pity FOR SELECT
  USING (driver_id = auth.uid());

CREATE POLICY "box_pity_admin_all"
  ON driver_box_pity FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- =============================================================
-- Section 12: gamification_seasons
-- Season 1 seeded as active starting now.
-- =============================================================
CREATE TABLE IF NOT EXISTS gamification_seasons (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  season_number  integer     UNIQUE NOT NULL,
  name_ar        text        NOT NULL,
  started_at     timestamptz NOT NULL,
  ended_at       timestamptz,
  status         text        DEFAULT 'upcoming'
    CHECK (status IN ('upcoming','active','ended')),
  rewards_summary jsonb      DEFAULT '{}',
  reset_xp       boolean     DEFAULT false,
  reset_level    boolean     DEFAULT false,
  reset_streak   boolean     DEFAULT false
);

INSERT INTO gamification_seasons (season_number, name_ar, started_at, status)
VALUES (1, 'الموسم الأول', now(), 'active')
ON CONFLICT (season_number) DO NOTHING;

ALTER TABLE gamification_seasons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "seasons_public_select"
  ON gamification_seasons FOR SELECT
  USING (true);

CREATE POLICY "seasons_admin_all"
  ON gamification_seasons FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- =============================================================
-- Section 13: Additional subscription_settings
-- =============================================================
INSERT INTO subscription_settings (key, value, description_ar)
VALUES
  ('active_day_min_revenue_etb', '100', 'الحد الأدنى للدخل لاحتساب اليوم النشط')
ON CONFLICT (key) DO NOTHING;

-- =============================================================
-- Section 14: Fix peak_hour time_range seed
-- Standardise slot key to "time_slots" with "days_of_week".
-- =============================================================
UPDATE point_earning_rules
SET time_range = '{
  "time_slots": [
    {"start_time":"07:00","end_time":"09:00","days_of_week":[1,2,3,4,5]},
    {"start_time":"17:00","end_time":"20:00","days_of_week":[1,2,3,4,5]}
  ]
}'::jsonb
WHERE rule_key = 'peak_hour';
