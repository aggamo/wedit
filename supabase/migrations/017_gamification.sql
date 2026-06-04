-- =============================================================
-- Migration 017: Gamification System
-- نظام المكافآت والتحفيز للسائقين
-- =============================================================

-- =============================================================
-- Section 1: subscription_plans
-- يجب إنشاؤها أولاً لأن driver_subscriptions تشير إليها
-- =============================================================
CREATE TABLE IF NOT EXISTS subscription_plans (
  id                uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  plan_key          text          UNIQUE NOT NULL,
  name_ar           text          NOT NULL,
  price_etb         numeric(10,2) NOT NULL DEFAULT 0,
  duration_days     integer,
  no_expiry         boolean       DEFAULT false,
  use_active_days   boolean       DEFAULT false,
  active_days_total integer,
  is_active         boolean       DEFAULT true,
  features          jsonb         DEFAULT '{}',
  commission_rate   numeric(5,4)  DEFAULT 0,
  sort_order        integer       DEFAULT 0,
  updated_by        uuid          REFERENCES profiles(id),
  created_at        timestamptz   DEFAULT now(),
  updated_at        timestamptz   DEFAULT now()
);

CREATE TRIGGER subscription_plans_updated_at
  BEFORE UPDATE ON subscription_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Seed subscription plans
INSERT INTO subscription_plans
  (plan_key, name_ar, price_etb, duration_days, no_expiry, use_active_days, active_days_total, features, commission_rate, sort_order)
VALUES
  ('trial',  'تجربة مجانية', 0,    14,   false, false, NULL, '{}',                                                   0, 1),
  ('daily',  'يومي',          65,   NULL, false, true,  1,    '{}',                                                   0, 2),
  ('weekly', 'أسبوعي',        300,  NULL, false, true,  7,    '{}',                                                   0, 3),
  ('flex',   'فليكس باس',     400,  NULL, true,  true,  10,   '{}',                                                   0, 4),
  ('basic',  'أساسي',         600,  NULL, false, true,  30,   '{}',                                                   0, 5),
  ('pro',    'احترافي',       1250, NULL, false, true,  30,   '{"xp_multiplier":1.5,"priority_boost":true}',         0, 6),
  ('fleet',  'أسطول',         0,    NULL, false, true,  NULL, '{}',                                                   0, 7)
ON CONFLICT (plan_key) DO NOTHING;

-- =============================================================
-- Section 2: ALTER driver_subscriptions — إضافة أعمدة الخطط الجديدة
-- =============================================================
ALTER TABLE driver_subscriptions
  ADD COLUMN IF NOT EXISTS subscription_plan_id   uuid    REFERENCES subscription_plans(id),
  ADD COLUMN IF NOT EXISTS is_trial               boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS active_days_used       integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS active_days_quota      integer,
  ADD COLUMN IF NOT EXISTS is_frozen              boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS frozen_days_total      integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS freeze_count_month     integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS freeze_month_reset_at  date    DEFAULT CURRENT_DATE;

-- =============================================================
-- Section 3: subscription_settings — إعدادات نظام الاشتراك
-- =============================================================
CREATE TABLE IF NOT EXISTS subscription_settings (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  key            text        UNIQUE NOT NULL,
  value          jsonb       NOT NULL,
  description_ar text,
  updated_by     uuid        REFERENCES profiles(id),
  updated_at     timestamptz DEFAULT now()
);

CREATE TRIGGER subscription_settings_updated_at
  BEFORE UPDATE ON subscription_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Seed settings
INSERT INTO subscription_settings (key, value) VALUES
  ('trial_duration_days',         '14'),
  ('freeze_min_days',             '1'),
  ('freeze_max_days_per_freeze',  '30'),
  ('freeze_max_times_per_month',  '2'),
  ('active_day_min_rides',        '3'),
  ('active_day_min_hours',        '2'),
  ('inactive_xp_penalty_per_day', '10'),
  ('inactive_level_decay_days',   '30'),
  ('late_sub_xp_penalty_pct',     '50'),
  ('late_sub_grace_days',         '3'),
  ('points_expiry_type',          '"never"'),
  ('points_expiry_days',          '0'),
  ('personal_goal_window_days',   '14'),
  ('personal_goal_multiplier',    '1.25')
ON CONFLICT (key) DO NOTHING;

-- =============================================================
-- Section 4: freeze_reasons — أسباب التجميد
-- =============================================================
CREATE TABLE IF NOT EXISTS freeze_reasons (
  id         uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  label_ar   text    NOT NULL,
  is_active  boolean DEFAULT true,
  sort_order integer DEFAULT 0
);

INSERT INTO freeze_reasons (label_ar, sort_order) VALUES
  ('مرض',             1),
  ('صيانة مركبة',     2),
  ('إجازة',           3),
  ('سفر',             4),
  ('ظروف شخصية',      5),
  ('سبب آخر',         6);

-- =============================================================
-- Section 5: subscription_freezes — سجل عمليات تجميد الاشتراك
-- =============================================================
CREATE TABLE IF NOT EXISTS subscription_freezes (
  id               uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id        uuid        NOT NULL REFERENCES profiles(id),
  subscription_id  uuid        NOT NULL REFERENCES driver_subscriptions(id),
  reason_id        uuid        REFERENCES freeze_reasons(id),
  custom_reason    text,
  frozen_at        timestamptz NOT NULL DEFAULT now(),
  unfrozen_at      timestamptz,
  admin_override_by uuid       REFERENCES profiles(id),
  created_at       timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_freezes_driver ON subscription_freezes(driver_id);
CREATE INDEX IF NOT EXISTS idx_freezes_active ON subscription_freezes(driver_id) WHERE unfrozen_at IS NULL;

-- =============================================================
-- Section 6: level_definitions — تعريفات مستويات السائقين
-- =============================================================
CREATE TABLE IF NOT EXISTS level_definitions (
  id             uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  level_key      text    UNIQUE NOT NULL,
  name_ar        text    NOT NULL,
  min_xp         bigint  NOT NULL,
  badge_icon     text,
  badge_color    text,
  benefits       jsonb   DEFAULT '{}',
  sort_order     integer NOT NULL,
  can_downgrade  boolean DEFAULT true,
  is_active      boolean DEFAULT true
);

INSERT INTO level_definitions (level_key, name_ar, min_xp, badge_icon, badge_color, benefits, sort_order, can_downgrade, is_active) VALUES
  ('bronze',    'برونزي',  0,      'shield', '#CD7F32', '{}',                                                                          1, true,  true),
  ('silver',    'فضي',     1500,   'shield', '#C0C0C0', '{}',                                                                          2, true,  true),
  ('gold',      'ذهبي',    7500,   'shield', '#FFD700', '{"priority_boost_hours":2}',                                                  3, true,  true),
  ('platinum',  'بلاتيني', 30000,  'shield', '#E5E4E2', '{"priority_boost_hours":4,"draw_weekly":true}',                              4, true,  true),
  ('legendary', 'أسطوري',  120000, 'crown',  '#9B59B6', '{"priority_boost_hours":8,"draw_weekly":true,"draw_monthly":true}',          5, false, true)
ON CONFLICT (level_key) DO NOTHING;

-- =============================================================
-- Section 7: driver_level_state — حالة مستوى كل سائق
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_level_state (
  driver_id           uuid        PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  level_id            uuid        REFERENCES level_definitions(id),
  xp                  bigint      NOT NULL DEFAULT 0,
  level_achieved_at   timestamptz DEFAULT now(),
  last_activity_date  date
);

-- =============================================================
-- Section 8: driver_xp_transactions — معاملات نقاط الخبرة
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_xp_transactions (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id   uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount      integer     NOT NULL,
  type        text        NOT NULL CHECK (type IN (
                'ride','rating_bonus','streak_bonus','achievement',
                'penalty_inactive','penalty_late_sub','admin_grant',
                'admin_deduct','level_up_bonus'
              )),
  description text,
  ride_id     uuid        REFERENCES rides(id) ON DELETE SET NULL,
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_xp_txn_driver  ON driver_xp_transactions(driver_id);
CREATE INDEX IF NOT EXISTS idx_xp_txn_created ON driver_xp_transactions(created_at DESC);

-- =============================================================
-- Section 9: point_earning_rules — قواعد اكتساب نقاط المكافآت
-- =============================================================
CREATE TABLE IF NOT EXISTS point_earning_rules (
  id                  uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  rule_key            text        UNIQUE NOT NULL,
  name_ar             text        NOT NULL,
  rule_type           text        NOT NULL CHECK (rule_type IN (
                        'per_ride','per_km','per_etb','rating_bonus','peak_hour','seasonal','campaign'
                      )),
  points_value        numeric(10,4) NOT NULL,
  min_threshold       numeric,
  rating_threshold    numeric,
  vehicle_multipliers jsonb       DEFAULT '{"sedan":1,"suv":1,"vip":1,"minibus":1}',
  ride_type_filter    text[],
  time_range          jsonb,
  valid_from          timestamptz,
  valid_until         timestamptz,
  is_active           boolean     DEFAULT true,
  sort_order          integer     DEFAULT 0,
  updated_by          uuid        REFERENCES profiles(id),
  updated_at          timestamptz DEFAULT now()
);

CREATE TRIGGER point_earning_rules_updated_at
  BEFORE UPDATE ON point_earning_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Seed earning rules
INSERT INTO point_earning_rules (rule_key, name_ar, rule_type, points_value, min_threshold, rating_threshold, time_range, is_active) VALUES
  ('per_ride',     'نقاط لكل رحلة',         'per_ride',    5,   NULL, NULL, NULL,
    '{"slots":[{"from":"00:00","to":"23:59"}]}'::jsonb, true),
  ('per_km',       'نقاط لكل كيلومتر',       'per_km',      1,   0,    NULL, NULL,   true),
  ('per_etb',      'نقاط لكل ريال',           'per_etb',     0.5, NULL, NULL, NULL,   true),
  ('rating_bonus', 'مكافأة التقييم الكامل',  'rating_bonus',3,   NULL, 5.0,  NULL,   true),
  ('peak_hour',    'ساعة الذروة',             'peak_hour',   2,   NULL, NULL,
    '{"slots":[{"from":"07:00","to":"09:00"},{"from":"17:00","to":"20:00"}],"days":[1,2,3,4,5]}'::jsonb, true)
ON CONFLICT (rule_key) DO NOTHING;

-- =============================================================
-- Section 10: xp_earning_rules — قواعد اكتساب نقاط الخبرة
-- =============================================================
CREATE TABLE IF NOT EXISTS xp_earning_rules (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  rule_key       text        UNIQUE NOT NULL,
  name_ar        text        NOT NULL,
  rule_type      text        NOT NULL CHECK (rule_type IN (
                   'per_ride','rating_bonus','streak_bonus','plan_multiplier','seasonal'
                 )),
  xp_value       integer     NOT NULL,
  condition_data jsonb,
  is_active      boolean     DEFAULT true,
  updated_at     timestamptz DEFAULT now()
);

CREATE TRIGGER xp_earning_rules_updated_at
  BEFORE UPDATE ON xp_earning_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Seed XP rules
INSERT INTO xp_earning_rules (rule_key, name_ar, rule_type, xp_value, condition_data, is_active) VALUES
  ('per_ride',  'XP لكل رحلة',             'per_ride',     10, NULL,                    true),
  ('rating_5',  'XP للتقييم الكامل',       'rating_bonus',  5, '{"min_rating":5}',      true),
  ('rating_1',  'خصم XP للتقييم السيء',    'rating_bonus', -3, '{"max_rating":2}',      true)
ON CONFLICT (rule_key) DO NOTHING;

-- =============================================================
-- Section 11: driver_streaks — سلاسل النشاط اليومي للسائقين
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_streaks (
  driver_id        uuid        PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  current_streak   integer     DEFAULT 0,
  longest_streak   integer     DEFAULT 0,
  last_active_date date,
  streak_frozen    boolean     DEFAULT false,
  streak_frozen_at timestamptz,
  updated_at       timestamptz DEFAULT now()
);

CREATE TRIGGER driver_streaks_updated_at
  BEFORE UPDATE ON driver_streaks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- Section 12: streak_configs — إعدادات شروط السلاسل والمكافآت
-- =============================================================
CREATE TABLE IF NOT EXISTS streak_configs (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  period_type text        UNIQUE NOT NULL CHECK (period_type IN ('daily','weekly','monthly')),
  min_rides   integer     NOT NULL DEFAULT 3,
  is_active   boolean     DEFAULT true,
  milestones  jsonb       DEFAULT '[]',
  updated_at  timestamptz DEFAULT now()
);

CREATE TRIGGER streak_configs_updated_at
  BEFORE UPDATE ON streak_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Seed streak configs
INSERT INTO streak_configs (period_type, min_rides, is_active, milestones) VALUES
  ('daily',   3,  true, '[
    {"days":7,"reward_points":50,"xp":100,"message":"أسبوع متواصل! 🔥"},
    {"days":30,"reward_points":200,"xp":500,"message":"شهر كامل! أنت جاد"}
  ]'::jsonb),
  ('weekly',  15, true, '[]'::jsonb),
  ('monthly', 60, true, '[]'::jsonb)
ON CONFLICT (period_type) DO NOTHING;

-- =============================================================
-- Section 13: reward_boxes — صناديق المكافآت
-- =============================================================
CREATE TABLE IF NOT EXISTS reward_boxes (
  id         uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name_ar    text        NOT NULL,
  box_type   text        NOT NULL CHECK (box_type IN ('streak','achievement','campaign','raffle','admin')),
  is_active  boolean     DEFAULT true,
  expires_at timestamptz,
  created_by uuid        REFERENCES profiles(id),
  created_at timestamptz DEFAULT now()
);

-- =============================================================
-- Section 14: box_prizes — جوائز صناديق المكافآت
-- =============================================================
CREATE TABLE IF NOT EXISTS box_prizes (
  id                      uuid     PRIMARY KEY DEFAULT uuid_generate_v4(),
  box_id                  uuid     NOT NULL REFERENCES reward_boxes(id) ON DELETE CASCADE,
  prize_type              text     NOT NULL CHECK (prize_type IN (
                            'etb','reward_points','xp','subscription_days',
                            'priority_hours','freeze_day','badge'
                          )),
  value                   numeric  NOT NULL,
  quantity_available      integer,
  quantity_used           integer  DEFAULT 0,
  weight                  integer  NOT NULL DEFAULT 10,
  fallback_prize_id       uuid     REFERENCES box_prizes(id),
  requires_admin_approval boolean  DEFAULT false,
  description_ar          text
);

-- =============================================================
-- Section 15: driver_box_openings — سجل فتح الصناديق
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_box_openings (
  id                 uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id          uuid        NOT NULL REFERENCES profiles(id),
  box_id             uuid        NOT NULL REFERENCES reward_boxes(id),
  prize_id           uuid        NOT NULL REFERENCES box_prizes(id),
  opened_at          timestamptz DEFAULT now(),
  prize_delivered    boolean     DEFAULT false,
  admin_approved_by  uuid        REFERENCES profiles(id),
  admin_approved_at  timestamptz
);

CREATE INDEX IF NOT EXISTS idx_box_openings_driver  ON driver_box_openings(driver_id);
CREATE INDEX IF NOT EXISTS idx_box_openings_pending ON driver_box_openings(prize_delivered) WHERE prize_delivered = false;

-- =============================================================
-- Section 16: achievements — الإنجازات والشارات
-- =============================================================
CREATE TABLE IF NOT EXISTS achievements (
  id                       uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name_ar                  text        NOT NULL,
  description_ar           text,
  trigger_type             text        NOT NULL CHECK (trigger_type IN (
                             'ride_count','streak_days','xp_total','rating_avg',
                             'referrals','admin_manual'
                           )),
  trigger_value            numeric,
  is_repeatable            boolean     DEFAULT false,
  repeat_period            text        CHECK (repeat_period IN ('monthly','weekly')),
  reward_points            integer     DEFAULT 0,
  reward_xp                integer     DEFAULT 0,
  reward_box_id            uuid        REFERENCES reward_boxes(id),
  badge_icon               text,
  is_hidden                boolean     DEFAULT true,
  is_visible_to_passenger  boolean     DEFAULT false,
  is_active                boolean     DEFAULT true,
  created_by               uuid        REFERENCES profiles(id),
  created_at               timestamptz DEFAULT now()
);

-- Seed achievements
-- مخفية (is_hidden = true)
INSERT INTO achievements
  (name_ar, description_ar, trigger_type, trigger_value, reward_points, reward_xp, is_hidden, is_active)
VALUES
  ('محترف المدينة',   NULL,                     'ride_count',  100,  50,  200,  true,  true),
  ('سائق الفجر',      NULL,                     'admin_manual', NULL, 20,  50,   true,  true),
  ('نجمة اليوم',      NULL,                     'rating_avg',   5,   30,  100,  true,  true),
  ('مئوية ذهبية',     NULL,                     'ride_count',  1000, 200, 1000, true,  true),
  ('الأسبوع الكامل',  NULL,                     'streak_days',  7,   50,  100,  true,  true),
  ('شهر بلا توقف',    NULL,                     'streak_days',  30,  200, 500,  true,  true),
  ('ألف رحلة',        'أكملت 500 رحلة',         'ride_count',  500,  100, 500,  false, true),
-- مرئية (is_hidden = false)
  ('البداية الجيدة',  'أكمل 10 رحلات للحصول على الشارة', 'ride_count', 10, 20, 50,  false, true),
  ('نصف المئة',       '50 رحلة ناجحة',          'ride_count',   50,  30,  100,  false, true),
  ('أيام متواصلة',    '14 يوماً متواصلاً',       'streak_days',  14,  80,  200,  false, true);

-- =============================================================
-- Section 17: driver_achievements — إنجازات السائقين المحققة
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_achievements (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id      uuid        NOT NULL REFERENCES profiles(id),
  achievement_id uuid        NOT NULL REFERENCES achievements(id),
  earned_at      timestamptz DEFAULT now(),
  period_key     text,
  UNIQUE (driver_id, achievement_id, period_key)
);

CREATE INDEX IF NOT EXISTS idx_driver_achievements_driver ON driver_achievements(driver_id);

-- =============================================================
-- Section 18: redemption_options — خيارات استبدال النقاط
-- =============================================================
CREATE TABLE IF NOT EXISTS redemption_options (
  id           uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name_ar      text        NOT NULL,
  option_type  text        NOT NULL CHECK (option_type IN (
                 'subscription_days','freeze_days','priority_hours','etb','xp'
               )),
  points_cost  integer     NOT NULL,
  value        numeric     NOT NULL,
  is_active    boolean     DEFAULT true,
  valid_from   timestamptz,
  valid_until  timestamptz,
  updated_by   uuid        REFERENCES profiles(id)
);

-- Seed redemption options
INSERT INTO redemption_options (name_ar, option_type, points_cost, value, is_active) VALUES
  ('يوم اشتراك مجاني',  'subscription_days', 100, 1,  true),
  ('يوم تجميد مجاني',   'freeze_days',        50,  1,  true),
  ('24 ساعة أولوية',    'priority_hours',     200, 24, true),
  ('50 ETB نقدي',       'etb',                500, 50, false);

-- =============================================================
-- Section 19: driver_redemptions — سجل عمليات الاستبدال
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_redemptions (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id      uuid        NOT NULL REFERENCES profiles(id),
  option_id      uuid        NOT NULL REFERENCES redemption_options(id),
  points_spent   integer     NOT NULL,
  value_received numeric     NOT NULL,
  redeemed_at    timestamptz DEFAULT now(),
  status         text        DEFAULT 'completed' CHECK (status IN ('pending','completed','rejected')),
  admin_notes    text
);

CREATE INDEX IF NOT EXISTS idx_redemptions_driver ON driver_redemptions(driver_id);

-- =============================================================
-- Section 20: driver_goal_state — أهداف السائق اليومية والأسبوعية
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_goal_state (
  driver_id           uuid          PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  daily_goal_rides    integer       NOT NULL DEFAULT 5,
  daily_goal_etb      numeric(10,2) NOT NULL DEFAULT 500,
  weekly_goal_rides   integer       NOT NULL DEFAULT 25,
  monthly_goal_rides  integer       NOT NULL DEFAULT 100,
  computed_at         date          DEFAULT CURRENT_DATE
);

-- =============================================================
-- Section 21: admin_audit_log — سجل التدقيق الإداري
-- =============================================================
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id                uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id          uuid        NOT NULL REFERENCES profiles(id),
  target_driver_id  uuid        REFERENCES profiles(id),
  action_type       text        NOT NULL CHECK (action_type IN (
                      'grant_sub_days','revoke_sub_days',
                      'grant_reward_points','deduct_reward_points',
                      'grant_xp','deduct_xp','grant_prize',
                      'freeze_override','unfreeze_override',
                      'level_override','achievement_grant','other'
                    )),
  before_value      jsonb,
  after_value       jsonb,
  reason            text        NOT NULL,
  created_at        timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_driver  ON admin_audit_log(target_driver_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_admin   ON admin_audit_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON admin_audit_log(created_at DESC);

-- =============================================================
-- Section 22: Functions — دوال النظام
-- =============================================================

-- ------------------------------------------------------------
-- Function: update_driver_level_after_xp
-- تحديث مستوى السائق تلقائياً بعد كل معاملة XP
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_driver_level_after_xp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_new_xp    bigint;
  v_level_id  uuid;
BEGIN
  -- Upsert driver_level_state, accumulating XP
  INSERT INTO driver_level_state (driver_id, xp, level_achieved_at)
  VALUES (NEW.driver_id, NEW.amount, now())
  ON CONFLICT (driver_id) DO UPDATE
    SET xp = driver_level_state.xp + NEW.amount;

  -- Retrieve updated XP total
  SELECT xp INTO v_new_xp
  FROM driver_level_state
  WHERE driver_id = NEW.driver_id;

  -- Prevent XP from going below 0
  IF v_new_xp < 0 THEN
    UPDATE driver_level_state
    SET xp = 0
    WHERE driver_id = NEW.driver_id;
    v_new_xp := 0;
  END IF;

  -- Find the highest qualifying level
  SELECT id INTO v_level_id
  FROM level_definitions
  WHERE min_xp <= v_new_xp
    AND is_active = true
  ORDER BY min_xp DESC
  LIMIT 1;

  -- Update level and optionally last_activity_date
  UPDATE driver_level_state
  SET
    level_id           = v_level_id,
    level_achieved_at  = CASE
                           WHEN level_id IS DISTINCT FROM v_level_id THEN now()
                           ELSE level_achieved_at
                         END,
    last_activity_date = CASE
                           WHEN NEW.amount > 0 THEN CURRENT_DATE
                           ELSE last_activity_date
                         END
  WHERE driver_id = NEW.driver_id;

  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------
-- Function: unfreeze_subscription
-- إلغاء تجميد اشتراك السائق مع تمديد تاريخ الانتهاء
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION unfreeze_subscription(p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_freeze        subscription_freezes%ROWTYPE;
  v_sub           driver_subscriptions%ROWTYPE;
  v_plan          subscription_plans%ROWTYPE;
  v_frozen_days   integer;
BEGIN
  -- Find the most recent active freeze for this driver
  SELECT *
  INTO v_freeze
  FROM subscription_freezes
  WHERE driver_id = p_driver_id
    AND unfrozen_at IS NULL
  ORDER BY frozen_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'لا يوجد تجميد نشط للسائق %', p_driver_id;
  END IF;

  -- Mark freeze as ended
  UPDATE subscription_freezes
  SET unfrozen_at = now()
  WHERE id = v_freeze.id;

  -- Calculate frozen days (ceiling of fractional days)
  v_frozen_days := CEIL(EXTRACT(EPOCH FROM (now() - v_freeze.frozen_at)) / 86400.0);

  -- Get associated subscription
  SELECT * INTO v_sub
  FROM driver_subscriptions
  WHERE id = v_freeze.subscription_id;

  -- Get the plan to check no_expiry flag
  SELECT * INTO v_plan
  FROM subscription_plans
  WHERE id = v_sub.subscription_plan_id;

  -- Update subscription: unfreeze, accumulate frozen days
  UPDATE driver_subscriptions
  SET
    is_frozen        = false,
    frozen_days_total = frozen_days_total + v_frozen_days,
    -- Extend ends_at only for plans that have an expiry
    ends_at          = CASE
                         WHEN (v_plan.no_expiry IS FALSE OR v_plan.no_expiry IS NULL)
                              AND ends_at IS NOT NULL
                         THEN ends_at + (v_frozen_days || ' days')::interval
                         ELSE ends_at
                       END
  WHERE id = v_freeze.subscription_id;

  -- Unfreeze streak
  UPDATE driver_streaks
  SET
    streak_frozen    = false,
    streak_frozen_at = NULL
  WHERE driver_id = p_driver_id;
END;
$$;

-- ------------------------------------------------------------
-- Function: get_driver_leaderboard_window
-- إرجاع نافذة من لوحة المتصدرين حول مرتبة السائق
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_driver_leaderboard_window(
  p_driver_id  uuid,
  p_window_size integer DEFAULT 5
)
RETURNS TABLE (
  driver_id       uuid,
  rank            integer,
  score           numeric,
  rides_count     integer,
  full_name       text,
  level_key       text,
  window_position text
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_period_id   uuid;
  v_driver_rank integer;
BEGIN
  -- Get the active competition period (most recently started)
  SELECT id INTO v_period_id
  FROM competition_periods
  WHERE is_active = true
  ORDER BY started_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Find the driver's current rank in that period
  SELECT cr.rank INTO v_driver_rank
  FROM competition_rankings cr
  WHERE cr.period_id = v_period_id
    AND cr.driver_id = p_driver_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Return the window: rows above + driver row + rows below
  RETURN QUERY
  SELECT
    cr.driver_id,
    cr.rank,
    cr.score,
    cr.rides_count,
    p.full_name,
    ld.level_key,
    CASE
      WHEN cr.rank < v_driver_rank THEN 'above'
      WHEN cr.rank = v_driver_rank THEN 'me'
      ELSE 'below'
    END AS window_position
  FROM competition_rankings cr
  JOIN profiles p ON p.id = cr.driver_id
  LEFT JOIN driver_level_state dls ON dls.driver_id = cr.driver_id
  LEFT JOIN level_definitions ld   ON ld.id = dls.level_id
  WHERE cr.period_id = v_period_id
    AND cr.rank BETWEEN (v_driver_rank - p_window_size) AND (v_driver_rank + p_window_size)
  ORDER BY cr.rank ASC;
END;
$$;

-- =============================================================
-- Section 23: Triggers — المشغّلات
-- =============================================================

-- Trigger: تحديث مستوى السائق بعد كل إدخال XP
CREATE TRIGGER trg_update_driver_level_after_xp
  AFTER INSERT ON driver_xp_transactions
  FOR EACH ROW EXECUTE FUNCTION update_driver_level_after_xp();

-- =============================================================
-- Section 24: Row Level Security — أمان مستوى الصف
-- =============================================================

ALTER TABLE subscription_plans      ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_settings   ENABLE ROW LEVEL SECURITY;
ALTER TABLE freeze_reasons           ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_freezes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE level_definitions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_level_state      ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_xp_transactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_earning_rules     ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_earning_rules        ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_streaks          ENABLE ROW LEVEL SECURITY;
ALTER TABLE streak_configs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_boxes            ENABLE ROW LEVEL SECURITY;
ALTER TABLE box_prizes              ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_box_openings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements            ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_achievements     ENABLE ROW LEVEL SECURITY;
ALTER TABLE redemption_options      ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_redemptions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_goal_state       ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_log         ENABLE ROW LEVEL SECURITY;

-- ---- subscription_plans ----
CREATE POLICY "sub_plans_select_auth"
  ON subscription_plans FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "sub_plans_admin_all"
  ON subscription_plans FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- subscription_settings ----
CREATE POLICY "sub_settings_select_auth"
  ON subscription_settings FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "sub_settings_admin_all"
  ON subscription_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- freeze_reasons ----
CREATE POLICY "freeze_reasons_select_auth"
  ON freeze_reasons FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "freeze_reasons_admin_all"
  ON freeze_reasons FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- subscription_freezes ----
CREATE POLICY "sub_freezes_select_own"
  ON subscription_freezes FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "sub_freezes_admin_all"
  ON subscription_freezes FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- level_definitions ----
CREATE POLICY "level_defs_select_auth"
  ON level_definitions FOR SELECT
  TO authenticated USING (true);

-- ---- driver_level_state ----
CREATE POLICY "driver_level_state_select_own"
  ON driver_level_state FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "driver_level_state_admin_all"
  ON driver_level_state FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- driver_xp_transactions ----
CREATE POLICY "xp_txn_select_own"
  ON driver_xp_transactions FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "xp_txn_admin_all"
  ON driver_xp_transactions FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- point_earning_rules ----
CREATE POLICY "point_rules_select_auth"
  ON point_earning_rules FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "point_rules_admin_all"
  ON point_earning_rules FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- xp_earning_rules ----
CREATE POLICY "xp_rules_select_auth"
  ON xp_earning_rules FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "xp_rules_admin_all"
  ON xp_earning_rules FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- driver_streaks ----
CREATE POLICY "driver_streaks_select_own"
  ON driver_streaks FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "driver_streaks_admin_all"
  ON driver_streaks FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- streak_configs ----
CREATE POLICY "streak_configs_select_auth"
  ON streak_configs FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "streak_configs_admin_all"
  ON streak_configs FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- reward_boxes ----
CREATE POLICY "reward_boxes_select_auth"
  ON reward_boxes FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "reward_boxes_admin_all"
  ON reward_boxes FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- box_prizes ----
CREATE POLICY "box_prizes_select_auth"
  ON box_prizes FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "box_prizes_admin_all"
  ON box_prizes FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- driver_box_openings ----
CREATE POLICY "box_openings_select_own"
  ON driver_box_openings FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "box_openings_admin_all"
  ON driver_box_openings FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- achievements ----
CREATE POLICY "achievements_select_auth"
  ON achievements FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "achievements_admin_all"
  ON achievements FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- driver_achievements ----
CREATE POLICY "driver_achievements_select_own"
  ON driver_achievements FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "driver_achievements_admin_all"
  ON driver_achievements FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- redemption_options ----
CREATE POLICY "redemption_options_select_auth"
  ON redemption_options FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "redemption_options_admin_all"
  ON redemption_options FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- driver_redemptions ----
CREATE POLICY "driver_redemptions_select_own"
  ON driver_redemptions FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "driver_redemptions_admin_all"
  ON driver_redemptions FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- driver_goal_state ----
CREATE POLICY "driver_goal_state_select_own"
  ON driver_goal_state FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "driver_goal_state_admin_all"
  ON driver_goal_state FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ---- admin_audit_log ----
CREATE POLICY "audit_log_admin_all"
  ON admin_audit_log FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- =============================================================
-- driver_lifetime_stats
-- Denormalized running totals — updated via DB triggers.
-- Achievement checks read one row instead of scanning rides.
-- =============================================================
CREATE TABLE IF NOT EXISTS driver_lifetime_stats (
  driver_id           uuid        PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  total_rides         bigint      NOT NULL DEFAULT 0,
  total_km            numeric(12,2) NOT NULL DEFAULT 0,
  total_income_etb    numeric(14,2) NOT NULL DEFAULT 0,
  total_xp_earned     bigint      NOT NULL DEFAULT 0, -- cumulative only (never subtracted)
  best_streak         integer     NOT NULL DEFAULT 0,
  total_subscriptions integer     NOT NULL DEFAULT 0,
  total_5star_rides   bigint      NOT NULL DEFAULT 0,
  total_peak_rides    bigint      NOT NULL DEFAULT 0,
  first_ride_at       timestamptz,
  last_ride_at        timestamptz,
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lifetime_stats_rides ON driver_lifetime_stats(total_rides DESC);

-- Trigger: rides completed → update ride/km/income stats
CREATE OR REPLACE FUNCTION update_lifetime_stats_on_ride()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO driver_lifetime_stats (
      driver_id, total_rides, total_km, total_income_etb,
      total_5star_rides, first_ride_at, last_ride_at
    ) VALUES (
      NEW.driver_id,
      1,
      COALESCE(NEW.distance_km, 0),
      COALESCE(NEW.fare_amount, 0),
      CASE WHEN NEW.driver_rating = 5 THEN 1 ELSE 0 END,
      NEW.completed_at,
      NEW.completed_at
    )
    ON CONFLICT (driver_id) DO UPDATE SET
      total_rides      = driver_lifetime_stats.total_rides + 1,
      total_km         = driver_lifetime_stats.total_km + COALESCE(NEW.distance_km, 0),
      total_income_etb = driver_lifetime_stats.total_income_etb + COALESCE(NEW.fare_amount, 0),
      total_5star_rides = driver_lifetime_stats.total_5star_rides +
                          CASE WHEN NEW.driver_rating = 5 THEN 1 ELSE 0 END,
      first_ride_at    = COALESCE(driver_lifetime_stats.first_ride_at, NEW.completed_at),
      last_ride_at     = NEW.completed_at,
      updated_at       = now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER rides_update_lifetime_stats
  AFTER UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION update_lifetime_stats_on_ride();

-- Trigger: positive XP earned → accumulate total_xp_earned
CREATE OR REPLACE FUNCTION update_lifetime_xp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.amount > 0 THEN
    INSERT INTO driver_lifetime_stats (driver_id, total_xp_earned)
    VALUES (NEW.driver_id, NEW.amount)
    ON CONFLICT (driver_id) DO UPDATE SET
      total_xp_earned = driver_lifetime_stats.total_xp_earned + NEW.amount,
      updated_at      = now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER xp_update_lifetime_stats
  AFTER INSERT ON driver_xp_transactions
  FOR EACH ROW EXECUTE FUNCTION update_lifetime_xp();

-- Trigger: new active subscription → increment counter
CREATE OR REPLACE FUNCTION update_lifetime_subscriptions()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'active' THEN
    INSERT INTO driver_lifetime_stats (driver_id, total_subscriptions)
    VALUES (NEW.driver_id, 1)
    ON CONFLICT (driver_id) DO UPDATE SET
      total_subscriptions = driver_lifetime_stats.total_subscriptions + 1,
      updated_at          = now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER subs_update_lifetime_stats
  AFTER INSERT ON driver_subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_lifetime_subscriptions();

-- =============================================================
-- RLS for driver_lifetime_stats
-- =============================================================
ALTER TABLE driver_lifetime_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "lifetime_stats_select_own"
  ON driver_lifetime_stats FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "lifetime_stats_admin_all"
  ON driver_lifetime_stats FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
