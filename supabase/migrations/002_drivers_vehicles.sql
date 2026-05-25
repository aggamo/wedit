-- =============================================================
-- Migration 002: Drivers & Vehicles
-- =============================================================

-- =============================================================
-- drivers table
-- =============================================================
CREATE TABLE IF NOT EXISTS drivers (
  id                        uuid        PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  national_id               text        UNIQUE,
  license_number            text        UNIQUE,
  license_expiry            date,
  status                    text        NOT NULL DEFAULT 'pending'
                                        CHECK (status IN ('pending','active','suspended','rejected')),
  rating                    numeric(3,2) NOT NULL DEFAULT 5.00
                                        CHECK (rating >= 1.00 AND rating <= 5.00),
  total_rides               integer     NOT NULL DEFAULT 0 CHECK (total_rides >= 0),
  -- Preferred destination feature: driver sets a home/preferred area
  -- System prioritises rides heading in that direction
  preferred_dest_lat        double precision,
  preferred_dest_lng        double precision,
  preferred_dest_radius_km  numeric     NOT NULL DEFAULT 5 CHECK (preferred_dest_radius_km > 0),
  preferred_dest_enabled    boolean     NOT NULL DEFAULT false,
  -- Admin review fields
  rejection_reason          text,
  approved_by               uuid        REFERENCES profiles(id),
  approved_at               timestamptz,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_drivers_status  ON drivers(status);
CREATE INDEX IF NOT EXISTS idx_drivers_rating  ON drivers(rating DESC);

CREATE TRIGGER drivers_updated_at
  BEFORE UPDATE ON drivers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- driver_documents table
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_documents (
  id           uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id    uuid        NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  type         text        NOT NULL
               CHECK (type IN ('national_id','license','vehicle_insurance','vehicle_registration')),
  file_url     text        NOT NULL,
  status       text        NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','approved','rejected')),
  reviewed_by  uuid        REFERENCES profiles(id),
  reviewed_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_driver_docs_driver  ON driver_documents(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_docs_status  ON driver_documents(status);

-- =============================================================
-- vehicles table
-- =============================================================
CREATE TABLE IF NOT EXISTS vehicles (
  id                uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id         uuid        NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  type              text        NOT NULL
                   CHECK (type IN ('sedan','suv','vip','minibus')),
  plate_number      text        NOT NULL UNIQUE,
  model             text        NOT NULL,
  year              integer     CHECK (year >= 2000 AND year <= extract(year FROM now()) + 1),
  color             text,
  seats             integer     NOT NULL DEFAULT 4 CHECK (seats > 0),
  -- JSON restrictions e.g. {"allowed_zones": ["zone_a", "zone_b"]}
  zone_restrictions jsonb       NOT NULL DEFAULT '{}',
  is_active         boolean     NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_driver   ON vehicles(driver_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_type     ON vehicles(type);
CREATE INDEX IF NOT EXISTS idx_vehicles_active   ON vehicles(is_active);
CREATE INDEX IF NOT EXISTS idx_vehicles_plate    ON vehicles(plate_number);

CREATE TRIGGER vehicles_updated_at
  BEFORE UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE drivers           ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_documents  ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles          ENABLE ROW LEVEL SECURITY;

-- ---- drivers ----
CREATE POLICY "drivers_select_own"
  ON drivers FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "drivers_update_own"
  ON drivers FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "drivers_insert_own"
  ON drivers FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "drivers_admin_all"
  ON drivers FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Passengers can see basic driver info (name, rating) for active drivers
CREATE POLICY "drivers_passenger_select_active"
  ON drivers FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND status = 'active'
  );

-- ---- driver_documents ----
CREATE POLICY "driver_docs_select_own"
  ON driver_documents FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "driver_docs_insert_own"
  ON driver_documents FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "driver_docs_admin_all"
  ON driver_documents FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ---- vehicles ----
CREATE POLICY "vehicles_select_own"
  ON vehicles FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "vehicles_insert_own"
  ON vehicles FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "vehicles_update_own"
  ON vehicles FOR UPDATE
  USING (auth.uid() = driver_id)
  WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "vehicles_admin_all"
  ON vehicles FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Authenticated users can view active vehicles (needed for ride matching display)
CREATE POLICY "vehicles_authenticated_select_active"
  ON vehicles FOR SELECT
  USING (auth.role() = 'authenticated' AND is_active = true);
