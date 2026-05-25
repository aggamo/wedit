-- =============================================================
-- Migration 001: Profiles
-- Extends auth.users with app-specific profile data
-- =============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "cube";
CREATE EXTENSION IF NOT EXISTS "earthdistance" CASCADE;

-- =============================================================
-- profiles table (extends auth.users)
-- =============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id             uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone          text        UNIQUE,
  full_name      text,
  role           text        NOT NULL DEFAULT 'passenger'
                             CHECK (role IN ('passenger', 'driver', 'admin')),
  avatar_url     text,
  points         integer     NOT NULL DEFAULT 0 CHECK (points >= 0),
  total_rides    integer     NOT NULL DEFAULT 0 CHECK (total_rides >= 0),
  referral_code  text        UNIQUE DEFAULT upper(substr(md5(random()::text), 1, 8)),
  preferred_language text    DEFAULT 'ar'
                             CHECK (preferred_language IN ('ar','am','en','om','ti','so')),
  fcm_token      text,
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_role      ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_phone     ON profiles(phone);
CREATE INDEX IF NOT EXISTS idx_profiles_referral  ON profiles(referral_code);
CREATE INDEX IF NOT EXISTS idx_profiles_active    ON profiles(is_active);

-- =============================================================
-- Generic updated_at trigger function (reused by all tables)
-- =============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- Auto-create profile when a new auth.user is created
-- =============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, role)
  VALUES (
    NEW.id,
    NEW.phone,
    COALESCE(NEW.raw_user_meta_data->>'role', 'passenger')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can view their own profile
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Admins can view and manage all profiles
CREATE POLICY "profiles_admin_all"
  ON profiles FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Drivers can see basic info of other authenticated users (needed for ride matching)
CREATE POLICY "profiles_authenticated_select_basic"
  ON profiles FOR SELECT
  USING (auth.role() = 'authenticated');
