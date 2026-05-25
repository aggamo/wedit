-- =============================================================
-- Migration 007: Competition & Leaderboard
-- =============================================================

-- =============================================================
-- competition_settings table
-- One row per period_type (weekly / monthly)
-- =============================================================
CREATE TABLE IF NOT EXISTS competition_settings (
  id                    uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  period_type           text    NOT NULL UNIQUE CHECK (period_type IN ('weekly','monthly')),
  ranking_criteria      text    NOT NULL DEFAULT 'rides_count'
                       CHECK (ranking_criteria IN ('rides_count','points','rating','composite')),
  prizes                jsonb   NOT NULL DEFAULT '[
    {"rank": 1, "cash": 500,  "free_days": 7},
    {"rank": 2, "cash": 300,  "free_days": 0},
    {"rank": 3, "cash": 150,  "free_days": 0}
  ]'::jsonb,
  raffle_enabled        boolean NOT NULL DEFAULT true,
  raffle_prize_cash     numeric(10,2) NOT NULL DEFAULT 1000.00,
  raffle_prize_days     integer NOT NULL DEFAULT 0,
  raffle_winners_count  integer NOT NULL DEFAULT 1 CHECK (raffle_winners_count > 0),
  -- raffle_conditions example:
  -- {"logic": "OR", "rides_required": 25, "passenger_referrals": 5, "driver_referrals": 2}
  raffle_conditions     jsonb   NOT NULL DEFAULT '{
    "logic": "OR",
    "rides_required": 25,
    "passenger_referrals": 5,
    "driver_referrals": 2
  }'::jsonb,
  -- How many trailing digits of plate number to show on leaderboard
  plate_digits_visible  integer NOT NULL DEFAULT 2 CHECK (plate_digits_visible >= 0),
  -- Day of week for weekly period start: 1=Monday … 7=Sunday
  week_start_day        integer NOT NULL DEFAULT 1 CHECK (week_start_day BETWEEN 1 AND 7),
  is_active             boolean NOT NULL DEFAULT true,
  updated_by            uuid    REFERENCES profiles(id),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER competition_settings_updated_at
  BEFORE UPDATE ON competition_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- competition_periods table
-- =============================================================
CREATE TABLE IF NOT EXISTS competition_periods (
  id                uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  period_type       text        NOT NULL CHECK (period_type IN ('weekly','monthly')),
  started_at        timestamptz NOT NULL,
  ended_at          timestamptz,
  settings_snapshot jsonb,      -- copy of competition_settings at period close
  status            text        NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','closed','rewarded')),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comp_periods_type    ON competition_periods(period_type);
CREATE INDEX IF NOT EXISTS idx_comp_periods_status  ON competition_periods(status);

-- =============================================================
-- competition_rankings table
-- =============================================================
CREATE TABLE IF NOT EXISTS competition_rankings (
  id                       uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  period_id                uuid    NOT NULL REFERENCES competition_periods(id) ON DELETE CASCADE,
  driver_id                uuid    NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  period_type              text    NOT NULL CHECK (period_type IN ('weekly','monthly')),
  rank                     integer CHECK (rank > 0),
  score                    numeric NOT NULL DEFAULT 0,
  rides_count              integer NOT NULL DEFAULT 0,
  avg_rating               numeric(3,2) NOT NULL DEFAULT 5.00,
  passenger_referrals_count integer NOT NULL DEFAULT 0,
  driver_referrals_count   integer NOT NULL DEFAULT 0,
  is_raffle_eligible       boolean NOT NULL DEFAULT false,
  computed_at              timestamptz NOT NULL DEFAULT now(),
  UNIQUE(period_id, driver_id)
);

CREATE INDEX IF NOT EXISTS idx_comp_rankings_period  ON competition_rankings(period_id);
CREATE INDEX IF NOT EXISTS idx_comp_rankings_driver  ON competition_rankings(driver_id);
CREATE INDEX IF NOT EXISTS idx_comp_rankings_rank    ON competition_rankings(period_id, rank ASC);
CREATE INDEX IF NOT EXISTS idx_comp_rankings_raffle  ON competition_rankings(period_id, is_raffle_eligible) WHERE is_raffle_eligible = true;

-- =============================================================
-- competition_winners table
-- =============================================================
CREATE TABLE IF NOT EXISTS competition_winners (
  id         uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  period_id  uuid    NOT NULL REFERENCES competition_periods(id) ON DELETE CASCADE,
  driver_id  uuid    NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  win_type   text    NOT NULL CHECK (win_type IN ('rank_prize','raffle')),
  rank       integer,
  cash_prize numeric(10,2) NOT NULL DEFAULT 0,
  free_days  integer       NOT NULL DEFAULT 0,
  is_paid    boolean NOT NULL DEFAULT false,
  paid_at    timestamptz,
  paid_by    uuid    REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comp_winners_period  ON competition_winners(period_id);
CREATE INDEX IF NOT EXISTS idx_comp_winners_driver  ON competition_winners(driver_id);
CREATE INDEX IF NOT EXISTS idx_comp_winners_unpaid  ON competition_winners(is_paid) WHERE is_paid = false;

-- =============================================================
-- Seed: default competition settings (weekly + monthly)
-- =============================================================
INSERT INTO competition_settings (period_type, ranking_criteria, is_active)
VALUES
  ('weekly',  'rides_count', true),
  ('monthly', 'composite',   true)
ON CONFLICT (period_type) DO NOTHING;

-- =============================================================
-- Seed: create initial active periods
-- =============================================================
INSERT INTO competition_periods (period_type, started_at, status)
VALUES
  ('weekly',  date_trunc('week', now()), 'active'),
  ('monthly', date_trunc('month', now()), 'active')
ON CONFLICT DO NOTHING;

-- =============================================================
-- Function: mask_plate_number
-- Shows only the last `digits_visible` characters, rest → '*'
-- e.g. mask_plate_number('ABC1234', 2) → '*****34'
-- =============================================================
CREATE OR REPLACE FUNCTION mask_plate_number(plate text, digits_visible integer)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  plate_len  integer;
  masked_len integer;
BEGIN
  plate_len  := length(plate);
  IF digits_visible >= plate_len THEN
    RETURN plate;
  END IF;
  masked_len := plate_len - digits_visible;
  RETURN repeat('*', masked_len) || substr(plate, masked_len + 1);
END;
$$;

-- =============================================================
-- Function: refresh_competition_rankings
-- Recalculates scores and ranks for all active competition periods
-- =============================================================
CREATE OR REPLACE FUNCTION refresh_competition_rankings()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_period          competition_periods%ROWTYPE;
  v_settings        competition_settings%ROWTYPE;
  v_raffle_cond     jsonb;
  v_logic           text;
  v_rides_required  integer;
  v_pass_referrals  integer;
  v_driv_referrals  integer;
BEGIN
  -- Iterate over all active periods
  FOR v_period IN
    SELECT * FROM competition_periods WHERE status = 'active'
  LOOP
    -- Load corresponding settings
    SELECT * INTO v_settings
    FROM competition_settings
    WHERE period_type = v_period.period_type AND is_active = true;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    v_raffle_cond    := v_settings.raffle_conditions;
    v_logic          := COALESCE(v_raffle_cond->>'logic', 'OR');
    v_rides_required := COALESCE((v_raffle_cond->>'rides_required')::integer, 25);
    v_pass_referrals := COALESCE((v_raffle_cond->>'passenger_referrals')::integer, 5);
    v_driv_referrals := COALESCE((v_raffle_cond->>'driver_referrals')::integer, 2);

    -- Upsert rankings for this period
    INSERT INTO competition_rankings (
      period_id,
      driver_id,
      period_type,
      score,
      rides_count,
      avg_rating,
      passenger_referrals_count,
      driver_referrals_count,
      is_raffle_eligible,
      computed_at
    )
    SELECT
      v_period.id                           AS period_id,
      d.id                                  AS driver_id,
      v_period.period_type                  AS period_type,
      -- Score calculation based on ranking_criteria
      CASE v_settings.ranking_criteria
        WHEN 'rides_count'  THEN completed_rides::numeric
        WHEN 'points'       THEN COALESCE(p.points, 0)::numeric
        WHEN 'rating'       THEN COALESCE(d.rating, 5.00)::numeric * 10
        WHEN 'composite'    THEN
          -- composite: 50% rides, 30% rating, 20% referrals
          (completed_rides::numeric * 0.5)
          + (COALESCE(d.rating, 5.00)::numeric * 10 * 0.3)
          + (COALESCE(pass_refs, 0)::numeric + COALESCE(driv_refs, 0)::numeric) * 2 * 0.2
        ELSE completed_rides::numeric
      END                                   AS score,
      completed_rides                       AS rides_count,
      COALESCE(d.rating, 5.00)              AS avg_rating,
      COALESCE(pass_refs, 0)                AS passenger_referrals_count,
      COALESCE(driv_refs, 0)                AS driver_referrals_count,
      -- Raffle eligibility
      CASE
        WHEN v_logic = 'OR' THEN
          completed_rides >= v_rides_required
          OR COALESCE(pass_refs, 0) >= v_pass_referrals
          OR COALESCE(driv_refs, 0) >= v_driv_referrals
        WHEN v_logic = 'AND' THEN
          completed_rides >= v_rides_required
          AND COALESCE(pass_refs, 0) >= v_pass_referrals
          AND COALESCE(driv_refs, 0) >= v_driv_referrals
        ELSE false
      END                                   AS is_raffle_eligible,
      now()                                 AS computed_at
    FROM drivers d
    JOIN profiles p ON p.id = d.id
    -- Count completed rides in this period
    JOIN LATERAL (
      SELECT COUNT(*) AS completed_rides
      FROM rides r
      WHERE r.driver_id = d.id
        AND r.status = 'completed'
        AND r.completed_at >= v_period.started_at
        AND (v_period.ended_at IS NULL OR r.completed_at < v_period.ended_at)
    ) rc ON true
    -- Count passenger referrals in this period
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS pass_refs
      FROM referrals ref
      WHERE ref.referrer_id = d.id
        AND ref.referrer_type = 'passenger'
        AND ref.status = 'rewarded'
        AND ref.completed_at >= v_period.started_at
        AND (v_period.ended_at IS NULL OR ref.completed_at < v_period.ended_at)
    ) pr ON true
    -- Count driver referrals in this period
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS driv_refs
      FROM referrals ref
      WHERE ref.referrer_id = d.id
        AND ref.referrer_type = 'driver'
        AND ref.status = 'rewarded'
        AND ref.completed_at >= v_period.started_at
        AND (v_period.ended_at IS NULL OR ref.completed_at < v_period.ended_at)
    ) dr ON true
    WHERE d.status = 'active'
    ON CONFLICT (period_id, driver_id)
    DO UPDATE SET
      score                    = EXCLUDED.score,
      rides_count              = EXCLUDED.rides_count,
      avg_rating               = EXCLUDED.avg_rating,
      passenger_referrals_count = EXCLUDED.passenger_referrals_count,
      driver_referrals_count   = EXCLUDED.driver_referrals_count,
      is_raffle_eligible       = EXCLUDED.is_raffle_eligible,
      computed_at              = EXCLUDED.computed_at;

    -- Update ranks using RANK() window function
    UPDATE competition_rankings cr
    SET rank = ranked.new_rank
    FROM (
      SELECT
        id,
        RANK() OVER (PARTITION BY period_id ORDER BY score DESC) AS new_rank
      FROM competition_rankings
      WHERE period_id = v_period.id
    ) ranked
    WHERE cr.id = ranked.id AND cr.period_id = v_period.id;

  END LOOP;
END;
$$;

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE competition_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_periods   ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_rankings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_winners   ENABLE ROW LEVEL SECURITY;

-- Public read for all authenticated users (leaderboard is visible)
CREATE POLICY "comp_settings_select_all"
  ON competition_settings FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "comp_periods_select_all"
  ON competition_periods FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "comp_rankings_select_all"
  ON competition_rankings FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "comp_winners_select_all"
  ON competition_winners FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only admins can modify settings
CREATE POLICY "comp_settings_admin_modify"
  ON competition_settings FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Admins can manage periods and winners
CREATE POLICY "comp_periods_admin_all"
  ON competition_periods FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "comp_winners_admin_all"
  ON competition_winners FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Service role / admin can upsert rankings
CREATE POLICY "comp_rankings_admin_upsert"
  ON competition_rankings FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
