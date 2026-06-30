-- =============================================================
-- Migration 009: Cron Jobs & Supporting Functions
-- Requires pg_cron (enabled in Supabase Pro/Enterprise)
-- and pg_net (for HTTP calls from SQL)
-- =============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- =============================================================
-- Supporting function: notify_expiring_subscriptions
-- Finds subscriptions expiring within 3 days and sends pg_notify
-- =============================================================
CREATE OR REPLACE FUNCTION notify_expiring_subscriptions()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_sub RECORD;
BEGIN
  FOR v_sub IN
    SELECT
      ds.id         AS sub_id,
      ds.driver_id,
      ds.plan,
      ds.ends_at,
      p.fcm_token,
      p.preferred_language
    FROM driver_subscriptions ds
    JOIN profiles p ON p.id = ds.driver_id
    WHERE
      ds.status = 'active'
      AND ds.ends_at BETWEEN now() AND now() + interval '3 days'
      AND (
        ds.renewal_notified_at IS NULL
        OR ds.renewal_notified_at < now() - interval '7 days'
      )
  LOOP
    -- Send notification via pg_notify (Edge Function subscribes and fires FCM)
    PERFORM pg_notify(
      'new_notification',
      json_build_object(
        'user_id',   v_sub.driver_id,
        'title',     'Subscription Expiring Soon',
        'body',      'Your ' || v_sub.plan || ' subscription expires on '
                     || to_char(v_sub.ends_at AT TIME ZONE 'Africa/Addis_Ababa', 'YYYY-MM-DD HH24:MI')
                     || '. Renew now to keep driving.',
        'type',      'subscription',
        'data',      json_build_object(
                       'subscription_id', v_sub.sub_id,
                       'plan',            v_sub.plan,
                       'ends_at',         v_sub.ends_at
                     )
      )::text
    );

    -- Mark as notified so we don't spam
    UPDATE driver_subscriptions
    SET renewal_notified_at = now()
    WHERE id = v_sub.sub_id;
  END LOOP;
END;
$$;

-- =============================================================
-- Supporting function: auto_renew_subscriptions
-- Finds expired subscriptions with auto_renew=true and triggers
-- the renewal Edge Function via pg_notify
-- =============================================================
CREATE OR REPLACE FUNCTION auto_renew_subscriptions()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_sub RECORD;
BEGIN
  FOR v_sub IN
    SELECT
      ds.id       AS sub_id,
      ds.driver_id,
      ds.plan,
      ds.payment_method,
      ds.amount
    FROM driver_subscriptions ds
    WHERE
      ds.status = 'active'
      AND ds.auto_renew = true
      AND ds.ends_at <= now() + interval '1 hour'   -- trigger 1h before expiry
      AND ds.ends_at > now() - interval '2 hours'   -- don't re-trigger old ones
  LOOP
    -- Notify Edge Function to handle the actual payment + new subscription creation
    PERFORM pg_notify(
      'auto_renew_trigger',
      json_build_object(
        'driver_id',       v_sub.driver_id,
        'subscription_id', v_sub.sub_id,
        'plan',            v_sub.plan,
        'payment_method',  v_sub.payment_method,
        'amount',          v_sub.amount
      )::text
    );
  END LOOP;
END;
$$;

-- =============================================================
-- Supporting function: notify_leaderboard_progress
-- Notifies drivers in ranks 2-10 if they are within 5 rides of rank 1
-- =============================================================
CREATE OR REPLACE FUNCTION notify_leaderboard_progress()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_period  RECORD;
  v_leader  competition_rankings%ROWTYPE;
  v_entry   RECORD;
BEGIN
  -- Process each active period
  FOR v_period IN
    SELECT * FROM competition_periods WHERE status = 'active'
  LOOP
    -- Get rank 1 driver
    SELECT * INTO v_leader
    FROM competition_rankings
    WHERE period_id = v_period.id AND rank = 1
    LIMIT 1;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    -- Find drivers in ranks 2-10 within 5 score of leader
    FOR v_entry IN
      SELECT
        cr.driver_id,
        cr.rank,
        cr.score,
        cr.rides_count,
        p.preferred_language
      FROM competition_rankings cr
      JOIN profiles p ON p.id = cr.driver_id
      WHERE
        cr.period_id = v_period.id
        AND cr.rank BETWEEN 2 AND 10
        AND (v_leader.score - cr.score) <= 5
    LOOP
      PERFORM pg_notify(
        'new_notification',
        json_build_object(
          'user_id', v_entry.driver_id,
          'title',   'You are close to #1!',
          'body',    'You are rank #' || v_entry.rank
                     || '. Only ' || (v_leader.score - v_entry.score)::integer
                     || ' rides behind the leader. Keep going!',
          'type',    'leaderboard',
          'data',    json_build_object(
                       'period_id',   v_period.id,
                       'period_type', v_period.period_type,
                       'rank',        v_entry.rank,
                       'score',       v_entry.score,
                       'gap_to_leader', (v_leader.score - v_entry.score)
                     )
        )::text
      );
    END LOOP;
  END LOOP;
END;
$$;

-- =============================================================
-- Cron Job: Refresh competition rankings every hour
-- =============================================================
SELECT cron.schedule(
  'refresh-rankings',
  '0 * * * *',
  $$SELECT refresh_competition_rankings();$$
);

-- =============================================================
-- Cron Job: Notify about expiring subscriptions daily at 8am UTC
-- =============================================================
SELECT cron.schedule(
  'notify-expiring-subs',
  '0 8 * * *',
  $$SELECT notify_expiring_subscriptions();$$
);

-- =============================================================
-- Cron Job: Auto-renew subscriptions daily at 1am UTC
-- =============================================================
SELECT cron.schedule(
  'auto-renew-subs',
  '0 1 * * *',
  $$SELECT auto_renew_subscriptions();$$
);

-- =============================================================
-- Cron Job: Expire old ride offers every 5 minutes
-- =============================================================
SELECT cron.schedule(
  'expire-ride-offers',
  '*/5 * * * *',
  $$SELECT expire_old_offers();$$
);

-- =============================================================
-- Cron Job: Expire old driver subscriptions hourly
-- =============================================================
SELECT cron.schedule(
  'expire-subscriptions',
  '30 * * * *',
  $$SELECT expire_old_subscriptions();$$
);

-- =============================================================
-- Cron Job: Leaderboard progress notifications daily at 6pm UTC
-- =============================================================
SELECT cron.schedule(
  'leaderboard-progress',
  '0 18 * * *',
  $$SELECT notify_leaderboard_progress();$$
);

-- =============================================================
-- Cron Job: Close weekly competition every Sunday at 11:55pm UTC
-- =============================================================
SELECT cron.schedule(
  'close-weekly-competition',
  '55 23 * * 0',
  $$
    SELECT net.http_post(
      url     := current_setting('app.supabase_url') || '/functions/v1/close-competition-period',
      headers := jsonb_build_object(
                   'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
                   'Content-Type',  'application/json'
                 ),
      body    := '{"period_type":"weekly"}'::jsonb
    );
  $$
);

-- =============================================================
-- Cron Job: Close monthly competition on last day of month at 11:55pm UTC
-- Runs on days 28-31; only fires when the next day is a different month
-- =============================================================
SELECT cron.schedule(
  'close-monthly-competition',
  '55 23 28-31 * *',
  $$
    SELECT CASE
      WHEN date_trunc('month', now()) != date_trunc('month', now() + interval '1 day')
      THEN (
        SELECT net.http_post(
          url     := current_setting('app.supabase_url') || '/functions/v1/close-competition-period',
          headers := jsonb_build_object(
                       'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
                       'Content-Type',  'application/json'
                     ),
          body    := '{"period_type":"monthly"}'::jsonb
        )
      )
    END;
  $$
);

-- =============================================================
-- Grant execute on new functions to service_role
-- =============================================================
GRANT EXECUTE ON FUNCTION notify_expiring_subscriptions() TO service_role;
GRANT EXECUTE ON FUNCTION auto_renew_subscriptions()      TO service_role;
GRANT EXECUTE ON FUNCTION notify_leaderboard_progress()   TO service_role;
