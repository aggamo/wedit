-- =============================================================
-- Migration 003: Rides, Offers, Ratings
-- =============================================================

-- =============================================================
-- rides table
-- =============================================================
CREATE TABLE IF NOT EXISTS rides (
  id                  uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  passenger_id        uuid        NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  driver_id           uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  vehicle_type        text        NOT NULL
                     CHECK (vehicle_type IN ('sedan','suv','vip','minibus')),
  -- Pickup location
  pickup_lat          double precision NOT NULL,
  pickup_lng          double precision NOT NULL,
  pickup_address      text,
  -- Dropoff location
  dropoff_lat         double precision NOT NULL,
  dropoff_lng         double precision NOT NULL,
  dropoff_address     text,
  -- Status lifecycle: requested → offered → accepted → started → completed / cancelled
  status              text        NOT NULL DEFAULT 'requested'
                     CHECK (status IN ('requested','offered','accepted','started','completed','cancelled')),
  estimated_price     numeric(10,2),
  final_price         numeric(10,2),
  payment_method      text
                     CHECK (payment_method IN ('chapa','telebirr','cash','bank')),
  points_earned       integer     NOT NULL DEFAULT 0 CHECK (points_earned >= 0),
  points_redeemed     integer     NOT NULL DEFAULT 0 CHECK (points_redeemed >= 0),
  cancellation_reason text,
  cancelled_by        uuid        REFERENCES profiles(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  completed_at        timestamptz
);

CREATE INDEX IF NOT EXISTS idx_rides_passenger     ON rides(passenger_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver        ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status        ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_created_at    ON rides(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rides_vehicle_type  ON rides(vehicle_type);

CREATE TRIGGER rides_updated_at
  BEFORE UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Set completed_at when status transitions to 'completed'
CREATE OR REPLACE FUNCTION set_ride_completed_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    NEW.completed_at = now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER rides_set_completed_at
  BEFORE UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION set_ride_completed_at();

-- =============================================================
-- ride_offers table
-- =============================================================
CREATE TABLE IF NOT EXISTS ride_offers (
  id                    uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id               uuid        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  driver_id             uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  offered_price         numeric(10,2) NOT NULL,
  eta_minutes           integer     CHECK (eta_minutes > 0),
  distance_to_pickup_km numeric(8,2),
  status                text        NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','accepted','rejected','expired')),
  created_at            timestamptz NOT NULL DEFAULT now(),
  expires_at            timestamptz NOT NULL DEFAULT (now() + interval '30 seconds')
);

CREATE INDEX IF NOT EXISTS idx_ride_offers_ride    ON ride_offers(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_driver  ON ride_offers(driver_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_status  ON ride_offers(status);
CREATE INDEX IF NOT EXISTS idx_ride_offers_expires ON ride_offers(expires_at);

-- Auto-expire pending offers after their expiry time
CREATE OR REPLACE FUNCTION expire_old_offers()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE ride_offers
  SET status = 'expired'
  WHERE status = 'pending' AND expires_at < now();
END;
$$;

-- =============================================================
-- ratings table
-- =============================================================
CREATE TABLE IF NOT EXISTS ratings (
  id          uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id     uuid    NOT NULL UNIQUE REFERENCES rides(id) ON DELETE CASCADE,
  rated_by    uuid    NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  rated_user  uuid    NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  score       integer NOT NULL CHECK (score >= 1 AND score <= 5),
  comment     text,
  -- Structured categories e.g. {"cleanliness":5,"punctuality":4,"communication":5}
  categories  jsonb   NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ratings_no_self_rate CHECK (rated_by != rated_user)
);

CREATE INDEX IF NOT EXISTS idx_ratings_rated_user  ON ratings(rated_user);
CREATE INDEX IF NOT EXISTS idx_ratings_rated_by    ON ratings(rated_by);
CREATE INDEX IF NOT EXISTS idx_ratings_ride        ON ratings(ride_id);

-- =============================================================
-- Function: find_nearby_drivers
-- Returns drivers within radius_meters, ordered by distance,
-- with preferred-destination drivers prioritised.
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
DECLARE
  ride_vec_lat   double precision;
  ride_vec_lng   double precision;
  ride_vec_norm  double precision;
BEGIN
  -- Normalised direction vector of the ride request (pickup location only; we don't
  -- know dropoff at this stage so we can't compute a direction vector for the ride).
  -- Preferred-destination prioritisation is handled via a scalar boost instead.
  RETURN QUERY
  WITH candidate_drivers AS (
    SELECT
      dl.driver_id,
      dl.lat,
      dl.lng,
      dl.heading,
      -- earth_distance returns meters
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
    JOIN vehicles v ON v.driver_id = dl.driver_id
    WHERE
      dl.is_online = true
      AND d.status = 'active'
      AND v.type = p_vehicle_type
      AND v.is_active = true
      AND earth_distance(
            ll_to_earth(center_lat, center_lng),
            ll_to_earth(dl.lat, dl.lng)
          ) <= radius_meters
  ),
  scored AS (
    SELECT
      cd.driver_id,
      cd.lat,
      cd.lng,
      cd.heading,
      cd.dist_m,
      -- Priority boost: if driver has preferred_dest_enabled and the ride pickup is
      -- within preferred_dest_radius_km of their preferred destination, score them up.
      CASE
        WHEN cd.preferred_dest_enabled
             AND cd.preferred_dest_lat IS NOT NULL
             AND cd.preferred_dest_lng IS NOT NULL
             AND earth_distance(
                   ll_to_earth(cd.preferred_dest_lat, cd.preferred_dest_lng),
                   ll_to_earth(center_lat, center_lng)
                 ) <= (cd.preferred_dest_radius_km * 1000)
        THEN cd.dist_m - 1000  -- subtract 1 km equivalent to boost ranking
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
-- Function: calculate_estimated_price
-- =============================================================
CREATE OR REPLACE FUNCTION calculate_estimated_price(
  distance_km     double precision,
  p_vehicle_type  text
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  base_fare      numeric;
  price_per_km   numeric;
BEGIN
  CASE p_vehicle_type
    WHEN 'sedan'   THEN base_fare := 25; price_per_km := 8;
    WHEN 'suv'     THEN base_fare := 35; price_per_km := 12;
    WHEN 'vip'     THEN base_fare := 60; price_per_km := 20;
    WHEN 'minibus' THEN base_fare := 20; price_per_km := 6;
    ELSE
      RAISE EXCEPTION 'Unknown vehicle type: %', p_vehicle_type;
  END CASE;

  RETURN round((base_fare + (price_per_km * distance_km))::numeric, 2);
END;
$$;

-- =============================================================
-- Trigger: update driver rating after new rating inserted
-- =============================================================
CREATE OR REPLACE FUNCTION update_driver_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_avg_rating numeric(3,2);
BEGIN
  -- Recalculate average rating for the rated user
  SELECT AVG(score)::numeric(3,2)
  INTO v_avg_rating
  FROM ratings
  WHERE rated_user = NEW.rated_user;

  -- Update driver rating (only applies if the rated_user is a driver)
  UPDATE drivers
  SET
    rating     = COALESCE(v_avg_rating, 5.00),
    total_rides = total_rides + 1
  WHERE id = NEW.rated_user;

  -- Also increment total_rides on profiles
  UPDATE profiles
  SET total_rides = total_rides + 1
  WHERE id = NEW.rated_user;

  RETURN NEW;
END;
$$;

CREATE TRIGGER update_driver_rating_trigger
  AFTER INSERT ON ratings
  FOR EACH ROW EXECUTE FUNCTION update_driver_rating();

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE rides       ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings     ENABLE ROW LEVEL SECURITY;

-- ---- rides ----
-- Passengers see their own rides
CREATE POLICY "rides_select_passenger_own"
  ON rides FOR SELECT
  USING (auth.uid() = passenger_id);

-- Passengers can create rides
CREATE POLICY "rides_insert_passenger"
  ON rides FOR INSERT
  WITH CHECK (auth.uid() = passenger_id);

-- Passengers can update their own rides (e.g. cancel)
CREATE POLICY "rides_update_passenger_own"
  ON rides FOR UPDATE
  USING (auth.uid() = passenger_id);

-- Drivers see requested rides (to bid on) or rides assigned to them
CREATE POLICY "rides_select_driver"
  ON rides FOR SELECT
  USING (
    auth.uid() = driver_id
    OR (
      status = 'requested'
      AND EXISTS (SELECT 1 FROM drivers WHERE id = auth.uid() AND status = 'active')
    )
  );

-- Drivers can update rides they are assigned to (e.g. start, complete)
CREATE POLICY "rides_update_driver_own"
  ON rides FOR UPDATE
  USING (auth.uid() = driver_id);

-- Admins see all rides
CREATE POLICY "rides_admin_all"
  ON rides FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ---- ride_offers ----
-- Drivers see their own offers
CREATE POLICY "ride_offers_select_driver_own"
  ON ride_offers FOR SELECT
  USING (auth.uid() = driver_id);

-- Drivers can create offers
CREATE POLICY "ride_offers_insert_driver"
  ON ride_offers FOR INSERT
  WITH CHECK (
    auth.uid() = driver_id
    AND EXISTS (SELECT 1 FROM drivers WHERE id = auth.uid() AND status = 'active')
  );

-- Drivers can update their own offers
CREATE POLICY "ride_offers_update_driver_own"
  ON ride_offers FOR UPDATE
  USING (auth.uid() = driver_id);

-- Passengers see offers on their rides
CREATE POLICY "ride_offers_select_passenger"
  ON ride_offers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rides
      WHERE rides.id = ride_offers.ride_id AND rides.passenger_id = auth.uid()
    )
  );

-- Passengers can accept/reject offers on their rides
CREATE POLICY "ride_offers_update_passenger"
  ON ride_offers FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM rides
      WHERE rides.id = ride_offers.ride_id AND rides.passenger_id = auth.uid()
    )
  );

-- Admins see all
CREATE POLICY "ride_offers_admin_all"
  ON ride_offers FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ---- ratings ----
-- Users can read ratings about themselves
CREATE POLICY "ratings_select_about_self"
  ON ratings FOR SELECT
  USING (auth.uid() = rated_user OR auth.uid() = rated_by);

-- Users can insert a rating if they participated in the ride
CREATE POLICY "ratings_insert_ride_participant"
  ON ratings FOR INSERT
  WITH CHECK (
    auth.uid() = rated_by
    AND EXISTS (
      SELECT 1 FROM rides
      WHERE rides.id = ratings.ride_id
        AND rides.status = 'completed'
        AND (rides.passenger_id = auth.uid() OR rides.driver_id = auth.uid())
    )
  );

-- Admins see all ratings
CREATE POLICY "ratings_admin_all"
  ON ratings FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
