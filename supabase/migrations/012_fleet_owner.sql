-- Migration 012: Fleet Owner Feature
-- Adds fleet owner role, fleet management tables, driver-controlled surge,
-- and legal document acceptance tracking.

-- ── 1. Add fleet_owner to profile roles ──────────────────────────────────────

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('passenger', 'driver', 'admin', 'fleet_owner'));

-- ── 2. Fleet owner subscription plans ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fleet_owner_subscription_plans (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text        NOT NULL,
  max_vehicles  integer     NOT NULL CHECK (max_vehicles > 0),
  monthly_fee_etb integer   NOT NULL CHECK (monthly_fee_etb >= 0),
  features      jsonb       NOT NULL DEFAULT '{}',
  is_active     boolean     NOT NULL DEFAULT true,
  updated_by    uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── 3. Fleet owners ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fleet_owners (
  id                    uuid        PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  company_name          text,
  tax_id                text,
  subscription_plan_id  uuid        REFERENCES fleet_owner_subscription_plans(id) ON DELETE SET NULL,
  subscription_expiry   timestamptz,
  is_active             boolean     NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fleet_owners_active ON fleet_owners(is_active);

CREATE OR REPLACE FUNCTION fleet_owners_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS fleet_owners_updated_at ON fleet_owners;
CREATE TRIGGER fleet_owners_updated_at
  BEFORE UPDATE ON fleet_owners
  FOR EACH ROW EXECUTE FUNCTION fleet_owners_set_updated_at();

-- ── 4. Fleet vehicles ─────────────────────────────────────────────────────────
-- Vehicles owned by fleet owners (separate from driver-owned vehicles in `vehicles`)

CREATE TABLE IF NOT EXISTS fleet_vehicles (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_owner_id  uuid        NOT NULL REFERENCES fleet_owners(id) ON DELETE CASCADE,
  type            text        NOT NULL CHECK (type IN ('sedan','suv','vip','minibus')),
  plate_number    text        NOT NULL UNIQUE,
  model           text        NOT NULL,
  year            integer     CHECK (year >= 2000),
  color           text,
  seats           integer     NOT NULL DEFAULT 4 CHECK (seats > 0),
  is_active       boolean     NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fleet_vehicles_owner  ON fleet_vehicles(fleet_owner_id);
CREATE INDEX IF NOT EXISTS idx_fleet_vehicles_active ON fleet_vehicles(is_active);

DROP TRIGGER IF EXISTS fleet_vehicles_updated_at ON fleet_vehicles;
CREATE TRIGGER fleet_vehicles_updated_at
  BEFORE UPDATE ON fleet_vehicles
  FOR EACH ROW EXECUTE FUNCTION fleet_owners_set_updated_at();

-- ── 5. Fleet driver invitations ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fleet_driver_invitations (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_owner_id    uuid        NOT NULL REFERENCES fleet_owners(id) ON DELETE CASCADE,
  phone             text        NOT NULL,
  invited_driver_id uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  vehicle_id        uuid        REFERENCES fleet_vehicles(id) ON DELETE SET NULL,
  temp_password     text,
  status            text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','accepted','expired')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  accepted_at       timestamptz
);

CREATE INDEX IF NOT EXISTS idx_fleet_invitations_owner  ON fleet_driver_invitations(fleet_owner_id);
CREATE INDEX IF NOT EXISTS idx_fleet_invitations_phone  ON fleet_driver_invitations(phone);
CREATE INDEX IF NOT EXISTS idx_fleet_invitations_status ON fleet_driver_invitations(status);

-- ── 6. Fleet owner settlements ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fleet_owner_settlements (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_owner_id   uuid        NOT NULL REFERENCES fleet_owners(id) ON DELETE CASCADE,
  driver_id        uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  period_start     timestamptz NOT NULL,
  period_end       timestamptz NOT NULL,
  total_fare       numeric(10,2) NOT NULL DEFAULT 0,
  owner_share      numeric(10,2) NOT NULL DEFAULT 0,
  driver_share     numeric(10,2) NOT NULL DEFAULT 0,
  settlement_cycle text        NOT NULL DEFAULT 'daily'
                               CHECK (settlement_cycle IN ('daily','weekly','monthly')),
  is_waived        boolean     NOT NULL DEFAULT false,
  receipt_url      text,
  receipt_confirmed boolean    NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_settlements_owner  ON fleet_owner_settlements(fleet_owner_id);
CREATE INDEX IF NOT EXISTS idx_settlements_driver ON fleet_owner_settlements(driver_id);
CREATE INDEX IF NOT EXISTS idx_settlements_period ON fleet_owner_settlements(period_start, period_end);

-- ── 7. Extend drivers table ───────────────────────────────────────────────────

ALTER TABLE drivers
  ADD COLUMN IF NOT EXISTS fleet_owner_id       uuid        REFERENCES fleet_owners(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS fleet_vehicle_id     uuid        REFERENCES fleet_vehicles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS revenue_share_type   text        CHECK (revenue_share_type IN
                                                              ('percentage','daily_rent','weekly_rent','monthly_rent')),
  ADD COLUMN IF NOT EXISTS revenue_share_value  numeric(10,2),
  ADD COLUMN IF NOT EXISTS max_daily_trips      integer     CHECK (max_daily_trips > 0 AND max_daily_trips <= 30),
  ADD COLUMN IF NOT EXISTS is_car_active        boolean     NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS daily_trips_count    integer     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_trips_reset_at date        NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS surge_enabled        boolean     NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_drivers_fleet_owner ON drivers(fleet_owner_id) WHERE fleet_owner_id IS NOT NULL;

-- ── 8. Add is_surge_offer to ride_offers ──────────────────────────────────────

ALTER TABLE ride_offers
  ADD COLUMN IF NOT EXISTS is_surge_offer boolean NOT NULL DEFAULT false;

-- ── 9. Legal documents (versioned) ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS legal_documents (
  id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_type    text    NOT NULL,
  version     text    NOT NULL,
  title_ar    text    NOT NULL,
  content_ar  text    NOT NULL,
  is_active   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid    REFERENCES profiles(id) ON DELETE SET NULL,
  UNIQUE(doc_type, version)
);

CREATE INDEX IF NOT EXISTS idx_legal_docs_type_active ON legal_documents(doc_type, is_active);

-- ── 10. Legal document acceptances ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS legal_document_acceptances (
  id           uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid    NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  document_id  uuid    NOT NULL REFERENCES legal_documents(id) ON DELETE CASCADE,
  accepted_at  timestamptz NOT NULL DEFAULT now(),
  user_role    text    NOT NULL,
  UNIQUE(user_id, document_id)
);

CREATE INDEX IF NOT EXISTS idx_legal_acceptances_user ON legal_document_acceptances(user_id);
CREATE INDEX IF NOT EXISTS idx_legal_acceptances_doc  ON legal_document_acceptances(document_id);

-- ── 11. get_fleet_driver_stats function ──────────────────────────────────────

CREATE OR REPLACE FUNCTION get_fleet_driver_stats(
  p_fleet_owner_id  uuid,
  p_driver_id       uuid,
  p_period_start    timestamptz,
  p_period_end      timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_total_fare   numeric := 0;
  v_ride_count   integer := 0;
  v_driver       record;
  v_share_type   text;
  v_share_value  numeric;
  v_owner_share  numeric := 0;
  v_driver_share numeric := 0;
BEGIN
  -- Verify driver belongs to this fleet owner
  SELECT revenue_share_type, revenue_share_value
  INTO v_share_type, v_share_value
  FROM drivers
  WHERE id = p_driver_id AND fleet_owner_id = p_fleet_owner_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'driver_not_in_fleet');
  END IF;

  -- Sum completed rides
  SELECT COALESCE(SUM(agreed_price), 0), COUNT(*)
  INTO v_total_fare, v_ride_count
  FROM rides
  WHERE driver_id = p_driver_id
    AND status = 'completed'
    AND completed_at >= p_period_start
    AND completed_at < p_period_end;

  -- Calculate shares
  IF v_share_type = 'percentage' AND v_share_value IS NOT NULL THEN
    v_owner_share  := round(v_total_fare * (v_share_value / 100), 2);
    v_driver_share := round(v_total_fare - v_owner_share, 2);
  ELSIF v_share_type IN ('daily_rent','weekly_rent','monthly_rent') AND v_share_value IS NOT NULL THEN
    v_owner_share  := v_share_value;
    v_driver_share := greatest(round(v_total_fare - v_share_value, 2), 0);
  ELSE
    v_owner_share  := 0;
    v_driver_share := v_total_fare;
  END IF;

  RETURN jsonb_build_object(
    'driver_id',     p_driver_id,
    'period_start',  p_period_start,
    'period_end',    p_period_end,
    'total_fare',    v_total_fare,
    'ride_count',    v_ride_count,
    'owner_share',   v_owner_share,
    'driver_share',  v_driver_share,
    'share_type',    COALESCE(v_share_type, 'none'),
    'share_value',   COALESCE(v_share_value, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_fleet_driver_stats(uuid, uuid, timestamptz, timestamptz)
  TO authenticated;

-- ── 12. Reset daily_trips_count function (called by cron or trigger) ──────────

CREATE OR REPLACE FUNCTION reset_fleet_daily_trips()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE drivers
  SET daily_trips_count = 0,
      daily_trips_reset_at = CURRENT_DATE
  WHERE fleet_owner_id IS NOT NULL
    AND daily_trips_reset_at < CURRENT_DATE;
END;
$$;

-- ── 13. RLS Policies ─────────────────────────────────────────────────────────

-- fleet_owner_subscription_plans: read by all authenticated, write by admin
ALTER TABLE fleet_owner_subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fleet_plans_read" ON fleet_owner_subscription_plans
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "fleet_plans_admin_write" ON fleet_owner_subscription_plans
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_owners: owner reads own record, admin reads all
ALTER TABLE fleet_owners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fleet_owners_read_own" ON fleet_owners
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "fleet_owners_write_own" ON fleet_owners
  FOR UPDATE TO authenticated
  USING (id = auth.uid());

CREATE POLICY "fleet_owners_insert" ON fleet_owners
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "fleet_owners_admin" ON fleet_owners
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_vehicles: fleet owner manages own vehicles, admin sees all, drivers see their vehicle
ALTER TABLE fleet_vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fleet_vehicles_owner" ON fleet_vehicles
  FOR ALL TO authenticated
  USING (
    fleet_owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR EXISTS (SELECT 1 FROM drivers WHERE id = auth.uid() AND fleet_vehicle_id = fleet_vehicles.id)
  );

-- fleet_driver_invitations: owner manages, invited driver reads own
ALTER TABLE fleet_driver_invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fleet_invitations_owner" ON fleet_driver_invitations
  FOR ALL TO authenticated
  USING (fleet_owner_id = auth.uid()
    OR invited_driver_id = auth.uid()
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- fleet_owner_settlements: owner and driver read own settlements
ALTER TABLE fleet_owner_settlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fleet_settlements_access" ON fleet_owner_settlements
  FOR ALL TO authenticated
  USING (
    fleet_owner_id = auth.uid()
    OR driver_id = auth.uid()
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- legal_documents: everyone reads active, admin writes
ALTER TABLE legal_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "legal_docs_read" ON legal_documents
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "legal_docs_admin_write" ON legal_documents
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- legal_document_acceptances: user reads/writes own
ALTER TABLE legal_document_acceptances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "legal_acceptances_own" ON legal_document_acceptances
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "legal_acceptances_admin_read" ON legal_document_acceptances
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ── 14. Seed data ─────────────────────────────────────────────────────────────

-- Default fleet subscription plans
INSERT INTO fleet_owner_subscription_plans (name, max_vehicles, monthly_fee_etb, features, is_active)
VALUES
  ('أساسي',    2,  500,  '{"daily_summary_notification": false}', true),
  ('متوسط',    5,  1000, '{"daily_summary_notification": true}',  true),
  ('متقدم',    10, 1800, '{"daily_summary_notification": true}',  true),
  ('مؤسسي',   20, 3000, '{"daily_summary_notification": true}',  true)
ON CONFLICT DO NOTHING;

-- Fleet Terms & Conditions v1.0
INSERT INTO legal_documents (doc_type, version, title_ar, content_ar, is_active)
VALUES (
  'fleet_terms',
  '1.0',
  'القواعد والشروط لاستخدام ميزة مالك الأسطول في منصة Wedit',
  E'القواعد والشروط لاستخدام ميزة "مالك الأسطول" في منصة Wedit\n\nمقدمة\nهذه القواعد والشروط (يشار إليها بـ "الاتفاقية") تحكم العلاقة بين مالك الأسطول (Fleet Owner) والسائق التابع (Fleet Driver) عند استخدام ميزة إدارة الأسطول في منصة Wedit. كما تحدد الاتفاقية الالتزامات المتبادلة، والسياسات التشغيلية والمالية، وآليات حل النزاعات.\n\nعند الموافقة على هذه الاتفاقية (إلكترونياً عبر التطبيق)، يقر الطرفان بأنهما قد قرآها وفهماها ووافقا عليها.\n\nالقسم الأول: تعريفات\nالمنصة: تطبيق Wedit (للسائقين والركاب) وكافة الخدمات المرتبطة به، بما في ذلك قاعدة البيانات وواجهات الإدارة.\n\nمالك الأسطول (Fleet Owner): مستخدم مسجل على المنصة بدور fleet_owner، يملك سيارة أو أكثر ويعين سائقين للعمل عليها.\n\nالسائق التابع (Fleet Driver): مستخدم مسجل على المنصة بدور driver، تم تعيينه من قبل مالك الأسطول للعمل على سيارة محددة.\n\nالسيارة: مركبة مملوكة لمالك الأسطول، مسجلة في المنصة ضمن قائمة fleet_vehicles.\n\nنموذج العمل: الطريقة التي يتم بها تقسيم الإيرادات بين المالك والسائق (نسبة مئوية أو إيجار ثابت).\n\nدورة التسوية: الفترة الزمنية (يوم، أسبوع، شهر) التي يتم على أساسها احتساب المستحقات المالية بين الطرفين.\n\nالقسم الثاني: شروط والتزامات السائق التابع\n\n2.1. الالتزامات التشغيلية\nالالتزام بنموذج العمل المتفق عليه: يلتزم السائق بنسبة المشاركة أو قيمة الإيجار اليومي/الأسبوعي/الشهري المحددة من قبل المالك والموثقة في التطبيق.\n\nالحد الأقصى للرحلات اليومية: إذا حدد المالك عدداً أقصى للرحلات اليومية، يتوقف السائق تلقائياً عن استقبال الطلبات عند بلوغ هذا الحد. لا يجوز للسائق تجاوز الحد بوسائل يدوية أو التواصل مع الركاب خارج التطبيق لتجاوز هذا القيد.\n\nحالة السيارة: يلتزم السائق بالحفاظ على السيارة بحالة جيدة نظافياً وفنياً، وإبلاغ المالك فوراً عن أي عطل أو حادث.\n\nالقيادة الآمنة: يلتزم السائق بقوانين السير والمرور في إثيوبيا، وبحدود السرعة، وعدم استخدام الهاتف أثناء القيادة، وعدم القيادة تحت تأثير الكحول أو المخدرات.\n\nالموافقة على التتبع الحي: يوافق السائق على مشاركة موقعه الحي (GPS) مع مالك الأسطول بشكل مستمر أثناء فترة عمله (حالة online). يتم تحديث الموقع كل 30 ثانية. إيقاف خاصية الموقع عمداً يعتبر خرقاً للاتفاقية.\n\nعدم مشاركة الحساب: لا يجوز للسائق مشاركة حسابه أو تسجيل الدخول من جهاز آخر. جميع الرحلات التي تتم عبر حسابه تعتبر مسؤوليته الكاملة.\n\n2.2. الالتزامات المالية\nتسليم مستحقات المالك: يلتزم السائق بدفع المستحق للمالك في موعد لا يتجاوز 24 ساعة من انتهاء دورة التسوية. التطبيق لا يقوم بالتحويلات المالية، ولكنه يوفر سجلاً بالمستحقات.\n\nرفع إيصال الدفع: في حال طلب المالك، يرفع السائق صورة وصل الدفع عبر التطبيق كإثبات. عدم الرفع أو تقديم إيصال غير صحيح يعتبر إخلالاً بالاتفاقية.\n\nعدم المطالبة بأرباح إضافية غير متفق عليها: يحق للسائق فقط بالحصة المتفق عليها وفق نموذج العمل.\n\n2.3. السلوك المهني\nالتعامل مع الركاب: يلتزم السائق بالسلوك المهني اللائق، وعدم التمييز بين الركاب على أساس العرق أو الدين أو الجنس، وعدم مضايقة الركاب.\n\nالتقييم: يدرك السائق أن تقييماته (من الركاب) تؤثر على فرصه في استلام الطلبات مستقبلاً.\n\n2.4. إنهاء العلاقة\nفصل السائق من قبل المالك: يحق للمالك فصل السائق في أي وقت دون إبداء أسباب، ويتم ذلك عبر زر "فصل السائق" في التطبيق.\n\nانسحاب السائق: يمكن للسائق إنهاء العلاقة مع المالك في أي وقت عن طريق إخطار المالك عبر التطبيق. يظل السائق مسؤولاً عن تسوية أي مستحقات مالية متراكمة.\n\nعقوبات المنصة: إذا ارتكب السائق خرقاً جسيماً، يحق للمنصة (بعد التحقيق) تعليق حساب السائق أو حظره.\n\nالقسم الثالث: شروط والتزامات مالك الأسطول\n\n3.1. الالتزامات التشغيلية\nتوفير سيارة صالحة للعمل: يلتزم المالك بتسجيل سيارة صالحة فنياً وقانونياً (أورنينا سارية، تأمين ساري، رخصة سير) قبل تعيين سائق عليها.\n\nتعطيل السيارة عند الحاجة: إذا كانت السيارة غير صالحة للعمل (عطل، صيانة، حادث)، يلتزم المالك بتعطيل السيارة فوراً عبر التطبيق.\n\nالالتزام بحدود عمل السائق: إذا حدد المالك حداً أقصى للرحلات اليومية، يجب أن يكون معقولاً (أقل من 30 رحلة يومياً).\n\nالموافقة على شروط المنصة: يقر المالك بأن جميع بياناته صحيحة، وأنه مسؤول عن أي أضرار تلحق بالمنصة أو بالسائق نتيجة لمعلومات غير صحيحة.\n\n3.2. الالتزامات المالية\nدفع اشتراك المنصة: يلتزم المالك بدفع رسوم الاشتراك الشهرية للمنصة. في حال انتهاء الاشتراك، يحق للمنصة تعطيل خدمات إدارة الأسطول.\n\nعدم خصم رسوم المنصة من حصة السائق: رسوم اشتراك المالك هي مسؤوليته وحده.\n\nالشفافية في تحديد نموذج العمل: يجب أن يكون نموذج العمل واضحاً ومحدداً في التطبيق قبل بدء عمل السائق. لا يجوز للمالك تغيير النموذج بأثر رجعي.\n\n3.3. التعامل مع السائق\nعدم التمييز: لا يجوز للمالك التمييز بين السائقين على أساس غير موضوعي.\n\nالموافقة على حقوق السائق: يقر المالك بأن السائق يعمل بشكل مستقل (وليس موظفاً لديه).\n\n3.4. الخصوصية والبيانات\nاستخدام بيانات التتبع: يستطيع المالك رؤية موقع السائقين التابعين له فقط أثناء عملهم. لا يجوز للمالك استخدام هذه البيانات لأغراض خارج نطاق إدارة الأسطول.\n\nالسرية: يلتزم المالك بعدم مشاركة معلومات السائقين مع أي طرف ثالث إلا بموافقة كتابية.\n\nالقسم الرابع: أحكام عامة\n\n4.1. العلاقة التعاقدية\nهذه الاتفاقية هي بين مالك الأسطول والسائق. المنصة ليست طرفاً في النزاعات المالية أو التشغيلية بينهما.\n\n4.2. حل النزاعات\nالخطوة الأولى – التواصل المباشر: في حال نشوب نزاع، يلتزم الطرفان بمحاولة حله ودياً خلال 3 أيام عمل.\n\nالخطوة الثانية – وساطة المنصة: يمكن لأي من الطرفين رفع النزاع إلى فريق دعم المنصة عبر تذكرة دعم.\n\nالخطوة الثالثة – الجهات القضائية: إذا لم يتم حل النزاع، يحق للطرفين اللجوء إلى المحاكم المختصة في أديس أبابا، إثيوبيا.\n\n4.3. عقوبات المنصة\nفي حال ثبوت خرق أي من الأطراف لبنود هذه الاتفاقية، يحق للمنصة اتخاذ الإجراءات التالية تدريجياً:\n- إنذار كتابي عبر التطبيق.\n- تعليق مؤقت للحساب لمدة تصل إلى 30 يوماً.\n- حظر دائم للحساب مع إتاحة الفرصة للسحب المالي أو تسوية الأرصدة.\n- إبلاغ الجهات المختصة في حالة الاحتيال المالي أو انتحال الهوية.\n\n4.4. تعديل الاتفاقية\nيحق للمنصة تعديل هذه الاتفاقية من وقت لآخر. يتم إشعار المستخدمين قبل 15 يوماً من سريان التعديل عبر التطبيق والبريد الإلكتروني.\n\nاستمرار استخدام ميزة الأسطول بعد تاريخ نفاذ التعديل يعتبر قبولاً بالشروط المعدلة.\n\n4.5. الإقرار والموافقة الإلكترونية\nبالنقر على زر "أوافق على القواعد والشروط" في تطبيق Wedit، يقر المستخدم بأنه:\n- قرأ وفهم جميع البنود المذكورة أعلاه.\n- يتحمل كامل المسؤولية عن الامتثال لهذه البنود.\n- يوافق على معالجة بياناته الشخصية وبيانات موقعه وفقاً لسياسة الخصوصية للمنصة.\n- يقر بأن أي انتهاك لهذه البنود قد يؤدي إلى اتخاذ إجراءات ضده بما في ذلك حظره من المنصة.\n\nللتواصل: support@wedit.com',
  true
)
ON CONFLICT (doc_type, version) DO NOTHING;
