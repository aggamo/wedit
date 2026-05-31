-- Add FCM token to profiles for push notifications
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS fcm_token text;

-- Index for quick lookup when sending targeted notifications
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token
  ON profiles (fcm_token)
  WHERE fcm_token IS NOT NULL;
