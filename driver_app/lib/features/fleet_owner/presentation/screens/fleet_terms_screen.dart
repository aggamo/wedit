import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetTermsScreen extends ConsumerStatefulWidget {
  final String userRole; // 'fleet_owner' or 'fleet_driver'

  const FleetTermsScreen({super.key, required this.userRole});

  @override
  ConsumerState<FleetTermsScreen> createState() => _FleetTermsScreenState();
}

class _FleetTermsScreenState extends ConsumerState<FleetTermsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge &&
          _scrollController.position.pixels != 0 &&
          !_hasScrolledToEnd) {
        setState(() => _hasScrolledToEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await ref
          .read(fleetRepositoryProvider)
          .acceptTerms(userId, widget.userRole);
      if (mounted) {
        context.go(widget.userRole == 'fleet_owner' ? '/fleet' : '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القواعد والشروط'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: const _TermsContent(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!_hasScrolledToEnd)
                  const Text(
                    'يرجى قراءة الشروط كاملاً للمتابعة',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _hasScrolledToEnd && !_isAccepting ? _accept : null,
                    child: _isAccepting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('أوافق على القواعد والشروط'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('القواعد والشروط لاستخدام ميزة "مالك الأسطول"',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('الإصدار 1.0 — منصة Wedit',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
        const Divider(height: 24),

        _section('مقدمة',
            'هذه القواعد والشروط تحكم العلاقة بين مالك الأسطول (Fleet Owner) والسائق التابع (Fleet Driver) عند استخدام ميزة إدارة الأسطول في منصة Wedit. عند الموافقة إلكترونياً عبر التطبيق، يقر الطرفان بأنهما قرآها وفهماها ووافقا عليها.'),

        _section('القسم الأول: تعريفات', '''
• المنصة: تطبيق Wedit وكافة الخدمات المرتبطة به.
• مالك الأسطول: مستخدم بدور fleet_owner، يملك سيارة أو أكثر ويعين سائقين للعمل عليها.
• السائق التابع: مستخدم بدور driver، تم تعيينه من قبل مالك الأسطول للعمل على سيارة محددة.
• السيارة: مركبة مسجلة في المنصة ضمن قائمة سيارات الأسطول.
• نموذج العمل: طريقة تقسيم الإيرادات (نسبة مئوية أو إيجار ثابت).
• دورة التسوية: الفترة الزمنية (يوم/أسبوع/شهر) لاحتساب المستحقات.'''),

        _section('القسم الثاني: التزامات السائق التابع', '''
2.1 الالتزامات التشغيلية:
• الالتزام بنموذج العمل المتفق عليه والموثق في التطبيق.
• التوقف تلقائياً عند بلوغ حد الرحلات اليومية وعدم تجاوزه بأي وسيلة.
• الحفاظ على السيارة وإبلاغ المالك فوراً عن أي عطل أو حادث.
• الالتزام بقوانين السير والمرور في إثيوبيا، وعدم القيادة تحت تأثير الكحول أو المخدرات.
• الموافقة على مشاركة الموقع الحي (GPS) مع المالك أثناء العمل. إيقاف خاصية الموقع عمداً يُعدّ خرقاً للاتفاقية.
• عدم مشاركة الحساب أو تسجيل الدخول من جهاز آخر.

2.2 الالتزامات المالية:
• دفع مستحقات المالك خلال 24 ساعة من انتهاء دورة التسوية.
• رفع صورة وصل الدفع عند طلب المالك. تقديم إيصال غير صحيح إخلال بالاتفاقية.
• عدم المطالبة بأرباح إضافية غير متفق عليها في التطبيق.

2.3 السلوك المهني:
• الالتزام بالسلوك اللائق مع الركاب وعدم التمييز.
• الإدراك بأن التقييمات تؤثر على فرص استلام الطلبات.

2.4 إنهاء العلاقة:
• يحق للمالك فصل السائق في أي وقت عبر التطبيق.
• يمكن للسائق الانسحاب مع الالتزام بتسوية المستحقات المتراكمة.
• يحق للمنصة تعليق حساب السائق أو حظره في حال الخرق الجسيم.'''),

        _section('القسم الثالث: التزامات مالك الأسطول', '''
3.1 الالتزامات التشغيلية:
• تسجيل سيارة صالحة فنياً وقانونياً (أورنينا وتأمين ساريا).
• تعطيل السيارة فوراً عبر التطبيق عند توقفها عن الخدمة.
• تحديد حد رحلات يومي معقول (لا يُستخدم للتحايل على حقوق السائق).
• الإقرار بصحة جميع بياناته الشخصية والضريبية في المنصة.

3.2 الالتزامات المالية:
• دفع رسوم اشتراك المنصة في موعدها. عند انتهاء الاشتراك تُعلَّق الميزات المتقدمة.
• عدم تحميل السائق رسوم اشتراك المنصة إلا باتفاق كتابي صريح خارج التطبيق.
• وضوح نموذج العمل في التطبيق قبل بدء عمل السائق. لا يجوز التغيير بأثر رجعي.
• استخدام زر "تنازل" في صفحة التسوية عند إعفاء السائق من إيجار يوم معين.

3.3 التعامل مع السائق:
• عدم التمييز بين السائقين بصورة غير موضوعية.
• الإقرار بأن السائق يعمل بشكل مستقل وليس موظفاً.
• إشعار السائق فوراً (عبر الإشعار التلقائي في التطبيق) عند تعطيل السيارة أو فصله.

3.4 الخصوصية والبيانات:
• استخدام بيانات التتبع لأغراض إدارة الأسطول فقط.
• عدم مشاركة معلومات السائقين مع أي طرف ثالث بدون موافقتهم.'''),

        _section('القسم الرابع: أحكام عامة', '''
4.1 العلاقة التعاقدية:
المنصة ليست طرفاً في النزاعات المالية ولكنها توفر آلية توثيقها. المنصة لا تُعدّ وسيطاً للتوظيف.

4.2 حل النزاعات:
1. التواصل المباشر بين الطرفين خلال 3 أيام عمل.
2. رفع تذكرة دعم للمنصة — توصية غير ملزمة بناءً على البيانات المسجلة.
3. اللجوء إلى المحاكم المختصة في أديس أبابا، إثيوبيا.

4.3 عقوبات المنصة:
1. إنذار كتابي عبر التطبيق.
2. تعليق مؤقت حتى 30 يوماً.
3. حظر دائم مع إتاحة تسوية الأرصدة.
4. إبلاغ الجهات المختصة في حالة الاحتيال.

4.4 تعديل الاتفاقية:
يُشعَر المستخدمون قبل 15 يوماً من نفاذ أي تعديل عبر التطبيق. الاستمرار في الاستخدام يُعدّ قبولاً بالشروط المعدلة.

4.5 الإقرار والموافقة الإلكترونية:
بالنقر على "أوافق" يقر المستخدم بأنه قرأ وفهم جميع البنود، ويتحمل كامل المسؤولية عن الامتثال لها.'''),

        const Divider(height: 24),
        Text(
          'الجهة المصدرة: منصة Wedit — إدارة الشؤون القانونية والامتثال\nsupport@wedit.com',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.6)),
        ],
      ),
    );
  }
}
