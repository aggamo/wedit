-- =============================================================
-- Migration 006: Referrals & Points System
-- =============================================================

-- =============================================================
-- referrals table
-- =============================================================
CREATE TABLE IF NOT EXISTS referrals (
  id              uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id     uuid        NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  -- Each user can only be referred once
  referred_id     uuid        NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE RESTRICT,
  referrer_type   text        NOT NULL CHECK (referrer_type IN ('passenger','driver')),
  status          text        NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','completed','rewarded')),
  reward_points   integer     NOT NULL DEFAULT 0 CHECK (reward_points >= 0),
  referred_points integer     NOT NULL DEFAULT 0 CHECK (referred_points >= 0),
  completed_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT referrals_no_self_refer CHECK (referrer_id != referred_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer  ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred  ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status    ON referrals(status);

-- =============================================================
-- points_transactions table
-- =============================================================
CREATE TABLE IF NOT EXISTS points_transactions (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount      integer     NOT NULL, -- positive = earned, negative = redeemed/expiry
  type        text        NOT NULL
             CHECK (type IN ('earned','redeemed','bonus','referral','expiry')),
  description text,
  ride_id     uuid        REFERENCES rides(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pts_txn_user     ON points_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_pts_txn_type     ON points_transactions(type);
CREATE INDEX IF NOT EXISTS idx_pts_txn_ride     ON points_transactions(ride_id) WHERE ride_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pts_txn_created  ON points_transactions(created_at DESC);

-- =============================================================
-- Helper: is_ethiopian_holiday(check_date)
-- Ethiopian holidays (Gregorian calendar approximations):
--   Jan  7  - Ethiopian Christmas (Genna)
--   Jan 19  - Ethiopian Epiphany (Timkat)
--   Mar  2  - Victory of Adwa
--   May  1  - International Labour Day
--   May  5  - Ethiopian Patriots' Victory Day (Arbegnoch)
--   May 28  - Downfall of the Derg
--   Sep 11  - Ethiopian New Year (Enkutatash)
--   Sep 27  - Meskel (Finding of the True Cross)
--   Oct 11  - (approximate) Eid al-Adha - varies yearly; using fixed approx
--   Nov 11  - (approximate) Mawlid - varies yearly; using fixed approx
-- =============================================================
CREATE OR REPLACE FUNCTION is_ethiopian_holiday(check_date date DEFAULT CURRENT_DATE)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  m int := EXTRACT(MONTH FROM check_date);
  d int := EXTRACT(DAY FROM check_date);
BEGIN
  RETURN (m = 1  AND d = 7)   -- Genna
      OR (m = 1  AND d = 19)  -- Timkat
      OR (m = 3  AND d = 2)   -- Victory of Adwa
      OR (m = 5  AND d = 1)   -- Labour Day
      OR (m = 5  AND d = 5)   -- Patriots' Victory
      OR (m = 5  AND d = 28)  -- Downfall of Derg
      OR (m = 9  AND d = 11)  -- Enkutatash
      OR (m = 9  AND d = 27)  -- Meskel
      OR (m = 10 AND d = 11)  -- Eid al-Adha (approx)
      OR (m = 11 AND d = 11); -- Mawlid (approx)
END;
$$;

-- =============================================================
-- Function: award_ride_points
-- Called after a ride is completed
-- =============================================================
CREATE OR REPLACE FUNCTION award_ride_points(p_ride_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ride        rides%ROWTYPE;
  v_base_points integer := 10;
  v_total_points integer;
  v_description text;
BEGIN
  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ride % not found', p_ride_id;
  END IF;
  IF v_ride.status != 'completed' THEN
    RAISE EXCEPTION 'Ride % is not completed', p_ride_id;
  END IF;

  v_total_points := v_base_points;

  -- Electronic payment bonus: +5% rounded (= 1 extra point for base 10)
  IF v_ride.payment_method IN ('chapa', 'telebirr') THEN
    v_total_points := v_total_points + CEIL(v_base_points * 0.05)::integer;
  END IF;

  -- Holiday multiplier
  IF is_ethiopian_holiday(v_ride.completed_at::date) THEN
    v_total_points := v_total_points * 2;
    v_description := 'Holiday bonus ride points (×2)';
  ELSE
    v_description := 'Ride completion points';
  END IF;

  -- Update ride record with points earned
  UPDATE rides SET points_earned = v_total_points WHERE id = p_ride_id;

  -- Insert transaction record
  INSERT INTO points_transactions (user_id, amount, type, description, ride_id)
  VALUES (v_ride.passenger_id, v_total_points, 'earned', v_description, p_ride_id);

  -- Update passenger profile points and total_rides
  UPDATE profiles
  SET
    points     = points + v_total_points,
    total_rides = total_rides + 1
  WHERE id = v_ride.passenger_id;
END;
$$;

-- =============================================================
-- Function: redeem_points
-- Returns discount amount in ETB
-- =============================================================
CREATE OR REPLACE FUNCTION redeem_points(
  p_user_id  uuid,
  p_points   integer,
  p_ride_id  uuid
)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
  v_current_points integer;
  v_discount       numeric(10,2) := 0;
  v_description    text;
BEGIN
  -- Get current balance
  SELECT points INTO v_current_points FROM profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  IF v_current_points < p_points THEN
    RAISE EXCEPTION 'Insufficient points: have %, need %', v_current_points, p_points;
  END IF;

  -- Determine discount tier
  IF p_points >= 500 THEN
    -- 500+ points: free ride (max 150 ETB)
    v_discount := LEAST(150.00, (SELECT estimated_price FROM rides WHERE id = p_ride_id));
    v_description := 'Free ride redemption (500 points)';
  ELSIF p_points >= 100 THEN
    -- 100–499 points: 20% discount (max 50 ETB)
    v_discount := LEAST(50.00,
      COALESCE((SELECT estimated_price * 0.20 FROM rides WHERE id = p_ride_id), 50.00)
    );
    v_description := 'Discount redemption (100 points)';
  ELSE
    RAISE EXCEPTION 'Minimum 100 points required for redemption, got %', p_points;
  END IF;

  -- Deduct points from profile
  UPDATE profiles
  SET points = points - p_points
  WHERE id = p_user_id;

  -- Record transaction (negative amount = deduction)
  INSERT INTO points_transactions (user_id, amount, type, description, ride_id)
  VALUES (p_user_id, -p_points, 'redeemed', v_description, p_ride_id);

  -- Record on ride
  UPDATE rides
  SET points_redeemed = p_points
  WHERE id = p_ride_id;

  RETURN v_discount;
END;
$$;

-- =============================================================
-- Function: process_referral_reward
-- Called when referred user completes their first ride
-- =============================================================
CREATE OR REPLACE FUNCTION process_referral_reward(p_referral_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_referral     referrals%ROWTYPE;
  v_referrer_pts integer := 50;
  v_referred_pts integer := 20;
BEGIN
  SELECT * INTO v_referral FROM referrals WHERE id = p_referral_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Referral % not found', p_referral_id;
  END IF;
  IF v_referral.status = 'rewarded' THEN
    RETURN; -- Already processed
  END IF;

  -- Award referrer
  UPDATE profiles SET points = points + v_referrer_pts WHERE id = v_referral.referrer_id;
  INSERT INTO points_transactions (user_id, amount, type, description)
  VALUES (v_referral.referrer_id, v_referrer_pts, 'referral',
          'Referral reward: friend completed first ride');

  -- Award referred user
  UPDATE profiles SET points = points + v_referred_pts WHERE id = v_referral.referred_id;
  INSERT INTO points_transactions (user_id, amount, type, description)
  VALUES (v_referral.referred_id, v_referred_pts, 'referral',
          'Welcome bonus: joined via referral');

  -- Mark referral as rewarded
  UPDATE referrals
  SET
    status          = 'rewarded',
    reward_points   = v_referrer_pts,
    referred_points = v_referred_pts,
    completed_at    = now()
  WHERE id = p_referral_id;
END;
$$;

-- =============================================================
-- Trigger: After ride completed → award points
-- =============================================================
CREATE OR REPLACE FUNCTION on_ride_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_referral_id uuid;
  v_ride_count  integer;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    PERFORM award_ride_points(NEW.id);

    -- Check if this is the referred user's first ride, and if so reward referral
    SELECT total_rides INTO v_ride_count
    FROM profiles WHERE id = NEW.passenger_id;

    -- If this is the first completed ride (total_rides was just incremented to 1)
    IF v_ride_count = 1 THEN
      SELECT id INTO v_referral_id
      FROM referrals
      WHERE referred_id = NEW.passenger_id
        AND status IN ('pending','completed')
      LIMIT 1;

      IF v_referral_id IS NOT NULL THEN
        PERFORM process_referral_reward(v_referral_id);
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER rides_on_completed
  AFTER UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION on_ride_completed();

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE referrals             ENABLE ROW LEVEL SECURITY;
ALTER TABLE points_transactions   ENABLE ROW LEVEL SECURITY;

-- ---- referrals ----
CREATE POLICY "referrals_select_own"
  ON referrals FOR SELECT
  USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

CREATE POLICY "referrals_insert_own"
  ON referrals FOR INSERT
  WITH CHECK (auth.uid() = referrer_id);

CREATE POLICY "referrals_admin_all"
  ON referrals FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ---- points_transactions ----
CREATE POLICY "pts_txn_select_own"
  ON points_transactions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "pts_txn_admin_all"
  ON points_transactions FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
