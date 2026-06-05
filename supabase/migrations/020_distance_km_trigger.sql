-- Auto-calculate distance_km for any ride type where it is not
-- explicitly provided (call_center, AI rides, passenger app rides).
-- Street-hail rides send distance_km from the client; the WHEN guard
-- ensures we never overwrite a value the client already supplied.
--
-- Requires: earth_distance extension (enabled in migration 003).

CREATE OR REPLACE FUNCTION calculate_ride_distance_km()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.distance_km IS NULL
     AND NEW.pickup_lat  IS NOT NULL AND NEW.pickup_lng  IS NOT NULL
     AND NEW.dropoff_lat IS NOT NULL AND NEW.dropoff_lng IS NOT NULL
  THEN
    NEW.distance_km := ROUND((
      earth_distance(
        ll_to_earth(NEW.pickup_lat,  NEW.pickup_lng),
        ll_to_earth(NEW.dropoff_lat, NEW.dropoff_lng)
      ) / 1000.0
    )::numeric, 2);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER rides_auto_distance_km
  BEFORE INSERT OR UPDATE OF pickup_lat, pickup_lng, dropoff_lat, dropoff_lng
  ON rides
  FOR EACH ROW
  EXECUTE FUNCTION calculate_ride_distance_km();
