-- =============================================================
-- Migration 008: RLS Completion, Grants, and Admin Bypass Policies
-- =============================================================

-- =============================================================
-- Schema-level grants
-- =============================================================
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Service role gets full access (Supabase sets this by default, explicit here for clarity)
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Authenticated users can execute public functions
GRANT EXECUTE ON FUNCTION update_updated_at()                                 TO authenticated;
GRANT EXECUTE ON FUNCTION find_nearby_drivers(double precision, double precision, double precision, text) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_estimated_price(double precision, text)   TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_subscription(uuid)                       TO authenticated;
GRANT EXECUTE ON FUNCTION check_driver_subscription(uuid)                     TO authenticated;
GRANT EXECUTE ON FUNCTION award_ride_points(uuid)                             TO service_role;
GRANT EXECUTE ON FUNCTION redeem_points(uuid, integer, uuid)                  TO authenticated;
GRANT EXECUTE ON FUNCTION process_referral_reward(uuid)                       TO service_role;
GRANT EXECUTE ON FUNCTION is_ethiopian_holiday(date)                          TO authenticated;
GRANT EXECUTE ON FUNCTION mask_plate_number(text, integer)                    TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_competition_rankings()                      TO service_role;
GRANT EXECUTE ON FUNCTION expire_old_offers()                                 TO service_role;
GRANT EXECUTE ON FUNCTION expire_old_subscriptions()                          TO service_role;

-- =============================================================
-- Ensure all tables have RLS enabled (idempotent safety)
-- =============================================================
ALTER TABLE profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers               ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_documents      ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE rides                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_offers           ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings               ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_subscriptions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_transfers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments              ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_locations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications         ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints            ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals             ENABLE ROW LEVEL SECURITY;
ALTER TABLE points_transactions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_periods   ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_rankings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_winners   ENABLE ROW LEVEL SECURITY;

-- =============================================================
-- Service-role bypass policies (for Edge Functions and cron)
-- Service role bypasses RLS by default in Supabase, but these
-- explicit policies are useful for functions that run as auth'd users
-- with elevated permissions via security definer.
-- =============================================================

-- Allow service_role insert on notifications (used by Edge Functions)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notifications' AND policyname = 'notifications_service_role_insert'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "notifications_service_role_insert"
        ON notifications FOR INSERT
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to insert/update payments (used by webhook Edge Functions)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payments' AND policyname = 'payments_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "payments_service_role_all"
        ON payments FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to update ride status (used by webhook Edge Functions)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'rides' AND policyname = 'rides_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "rides_service_role_all"
        ON rides FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to upsert competition rankings
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'competition_rankings' AND policyname = 'comp_rankings_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "comp_rankings_service_role_all"
        ON competition_rankings FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to insert competition winners
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'competition_winners' AND policyname = 'comp_winners_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "comp_winners_service_role_all"
        ON competition_winners FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to manage competition periods
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'competition_periods' AND policyname = 'comp_periods_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "comp_periods_service_role_all"
        ON competition_periods FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to insert/update driver_subscriptions (auto-renew)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'driver_subscriptions' AND policyname = 'subs_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "subs_service_role_all"
        ON driver_subscriptions FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to update drivers table (status updates, etc.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'drivers' AND policyname = 'drivers_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "drivers_service_role_all"
        ON drivers FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to manage points_transactions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'points_transactions' AND policyname = 'pts_txn_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "pts_txn_service_role_all"
        ON points_transactions FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- Allow service_role to manage referrals
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'referrals' AND policyname = 'referrals_service_role_all'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "referrals_service_role_all"
        ON referrals FOR ALL
        USING (true)
        WITH CHECK (true)
    $policy$;
  END IF;
END
$$;

-- =============================================================
-- Additional missing policies: allow anon to read competition
-- data (public leaderboard visible without login)
-- =============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'competition_rankings' AND policyname = 'comp_rankings_anon_select'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "comp_rankings_anon_select"
        ON competition_rankings FOR SELECT
        USING (true)
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'competition_periods' AND policyname = 'comp_periods_anon_select'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "comp_periods_anon_select"
        ON competition_periods FOR SELECT
        USING (true)
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'competition_settings' AND policyname = 'comp_settings_anon_select'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "comp_settings_anon_select"
        ON competition_settings FOR SELECT
        USING (true)
    $policy$;
  END IF;
END
$$;

-- =============================================================
-- Future-proofing: auto-grant on new tables
-- =============================================================
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO authenticated;
