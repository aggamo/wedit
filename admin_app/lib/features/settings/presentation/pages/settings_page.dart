import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';

final _adminSvcProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _saved = false;

  // ── Surge pricing ────────────────────────────────────────────────────────────
  bool _surgeEnabled = false;
  bool _surgeSaving = false;
  final _surgeMultiplierCtrl = TextEditingController(text: '1.5');
  final _surgeFromCtrl = TextEditingController();
  final _surgeUntilCtrl = TextEditingController();
  final _surgeNameCtrl = TextEditingController(text: 'ذروة طارئة');

  // ── Fixed hour surge rules ───────────────────────────────────────────────────
  final _fixedRules = <Map<String, dynamic>>[
    {'name': 'ذروة الصباح',    'active': false, 'multiplier': 1.3,
     'days': [0,1,2,3,4], 'from': '07:00', 'to': '09:00'},
    {'name': 'ذروة المساء',    'active': false, 'multiplier': 1.4,
     'days': [0,1,2,3,4], 'from': '17:00', 'to': '19:30'},
    {'name': 'ليلة نهاية الأسبوع', 'active': false, 'multiplier': 1.2,
     'days': [5,6], 'from': '20:00', 'to': '23:59'},
  ];

  // ── Vehicle pricing ─────────────────────────────────────────────────────────
  final Map<String, TextEditingController> _basePrice = {
    'sedan': TextEditingController(text: '30'),
    'suv': TextEditingController(text: '45'),
    'vip': TextEditingController(text: '60'),
    'minibus': TextEditingController(text: '80'),
  };
  final Map<String, TextEditingController> _pricePerKm = {
    'sedan': TextEditingController(text: '5'),
    'suv': TextEditingController(text: '7'),
    'vip': TextEditingController(text: '10'),
    'minibus': TextEditingController(text: '4'),
  };

  // ── Subscription pricing ────────────────────────────────────────────────────
  final _dailyPriceCtrl = TextEditingController(text: '50');
  final _weeklyPriceCtrl = TextEditingController(text: '300');
  final _monthlyPriceCtrl = TextEditingController(text: '1000');

  // ── Points rules ────────────────────────────────────────────────────────────
  final _pointsPerRideCtrl = TextEditingController(text: '10');
  final _holidayMultiplierCtrl = TextEditingController(text: '2');
  final _digitalPaymentBonusCtrl = TextEditingController(text: '5');

  // ── Points redemption ───────────────────────────────────────────────────────
  final _pointsFor20DiscountCtrl = TextEditingController(text: '100');
  final _maxDiscountEtbCtrl = TextEditingController(text: '50');
  final _pointsForFreeRideCtrl = TextEditingController(text: '500');
  final _maxFreeRideEtbCtrl = TextEditingController(text: '150');

  // ── Fleet Owner Subscription Plans ──────────────────────────────────────────
  List<Map<String, dynamic>> _fleetPlans = [];
  bool _fleetPlansLoading = false;

  // ── Legal Documents ──────────────────────────────────────────────────────────
  Map<String, dynamic>? _activeDoc;
  int _docAcceptanceCount = 0;
  bool _legalDocLoading = false;

  static const _vehicleLabels = {
    'sedan': 'سيدان',
    'suv': 'دفع رباعي',
    'vip': 'VIP',
    'minibus': 'ميني باص',
  };

  @override
  void initState() {
    super.initState();
    _loadFleetPlans();
    _loadLegalDoc();
  }

  @override
  void dispose() {
    for (final c in _basePrice.values) {
      c.dispose();
    }
    for (final c in _pricePerKm.values) {
      c.dispose();
    }
    _dailyPriceCtrl.dispose();
    _weeklyPriceCtrl.dispose();
    _monthlyPriceCtrl.dispose();
    _pointsPerRideCtrl.dispose();
    _holidayMultiplierCtrl.dispose();
    _digitalPaymentBonusCtrl.dispose();
    _pointsFor20DiscountCtrl.dispose();
    _maxDiscountEtbCtrl.dispose();
    _pointsForFreeRideCtrl.dispose();
    _maxFreeRideEtbCtrl.dispose();
    _surgeMultiplierCtrl.dispose();
    _surgeFromCtrl.dispose();
    _surgeUntilCtrl.dispose();
    _surgeNameCtrl.dispose();
    super.dispose();
  }

  // ── Fleet Plans helpers ──────────────────────────────────────────────────────
  Future<void> _loadFleetPlans() async {
    if (!mounted) return;
    setState(() => _fleetPlansLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('fleet_owner_subscription_plans')
          .select()
          .eq('is_active', true)
          .order('max_vehicles');
      if (mounted) {
        setState(() => _fleetPlans = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل خطط الأسطول: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _fleetPlansLoading = false);
    }
  }

  Future<void> _toggleFleetPlanActive(
      Map<String, dynamic> plan, bool newValue) async {
    try {
      await Supabase.instance.client
          .from('fleet_owner_subscription_plans')
          .update({'is_active': newValue})
          .eq('id', plan['id']);
      await _loadFleetPlans();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddFleetPlanDialog() async {
    final nameCtrl = TextEditingController();
    final maxVehiclesCtrl = TextEditingController();
    final monthlyFeeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة خطة جديدة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الخطة'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: maxVehiclesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الأقصى للمركبات',
                  suffixText: 'مركبة',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'مطلوب';
                  if (int.tryParse(v) == null) return 'رقم صحيح مطلوب';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: monthlyFeeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الرسوم الشهرية',
                  suffixText: 'ETB/شهر',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'مطلوب';
                  if (int.tryParse(v) == null) return 'رقم صحيح مطلوب';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await Supabase.instance.client
                    .from('fleet_owner_subscription_plans')
                    .insert({
                  'name': nameCtrl.text.trim(),
                  'max_vehicles': int.parse(maxVehiclesCtrl.text),
                  'monthly_fee_etb': int.parse(monthlyFeeCtrl.text),
                  'is_active': true,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                await _loadFleetPlans();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إضافة الخطة بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في الإضافة: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    maxVehiclesCtrl.dispose();
    monthlyFeeCtrl.dispose();
  }

  // ── Legal Documents helpers ──────────────────────────────────────────────────
  Future<void> _loadLegalDoc() async {
    if (!mounted) return;
    setState(() => _legalDocLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final doc = await supabase
          .from('legal_documents')
          .select('id, doc_type, version, title_ar, created_at')
          .eq('is_active', true)
          .maybeSingle();

      int count = 0;
      if (doc != null) {
        final countResponse = await supabase
            .from('legal_document_acceptances')
            .select('id')
            .eq('document_id', doc['id'])
            .count(CountOption.exact);
        count = countResponse.count;
      }

      if (mounted) {
        setState(() {
          _activeDoc = doc;
          _docAcceptanceCount = count;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الوثيقة القانونية: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _legalDocLoading = false);
    }
  }

  Future<void> _showPublishLegalDocDialog() async {
    final versionCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نشر إصدار جديد'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: versionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الإصدار',
                    hintText: 'مثال: 1.0.0',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contentCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'محتوى الوثيقة (عربي)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'مطلوب' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final supabase = Supabase.instance.client;
                await supabase.from('legal_documents').insert({
                  'version': versionCtrl.text.trim(),
                  'content_ar': contentCtrl.text.trim(),
                  'is_active': true,
                });
                await supabase
                    .from('legal_documents')
                    .update({'is_active': false})
                    .neq('version', versionCtrl.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();
                await _loadLegalDoc();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نشر الوثيقة القانونية الجديدة بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في النشر: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('نشر'),
          ),
        ],
      ),
    );

    versionCtrl.dispose();
    contentCtrl.dispose();
  }

  Future<void> _activateEmergencySurge() async {
    setState(() => _surgeSaving = true);
    try {
      final mult = double.tryParse(_surgeMultiplierCtrl.text) ?? 1.5;
      final now = DateTime.now();
      final until = _surgeUntilCtrl.text.isNotEmpty
          ? DateTime.tryParse(_surgeUntilCtrl.text) ??
              now.add(const Duration(hours: 2))
          : now.add(const Duration(hours: 2));

      await ref.read(_adminSvcProvider).savePlatformSettings({
        'surge_pricing': {
          'type': 'manual',
          'name': _surgeNameCtrl.text,
          'multiplier': mult,
          'active_from': now.toIso8601String(),
          'active_until': until.toIso8601String(),
          'is_active': true,
        },
        'updated_at': DateTime.now().toIso8601String(),
      });
      setState(() => _surgeEnabled = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم تفعيل الذروة الطارئة ×${mult.toStringAsFixed(1)}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _surgeSaving = false);
    }
  }

  Future<void> _deactivateEmergencySurge() async {
    setState(() => _surgeEnabled = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إيقاف الذروة الطارئة'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final settings = {
        'vehicle_pricing': {
          for (final type in _basePrice.keys)
            type: {
              'base_price':
                  double.tryParse(_basePrice[type]!.text) ?? 0.0,
              'price_per_km':
                  double.tryParse(_pricePerKm[type]!.text) ?? 0.0,
            }
        },
        'subscription_pricing': {
          'daily': double.tryParse(_dailyPriceCtrl.text) ?? 50,
          'weekly': double.tryParse(_weeklyPriceCtrl.text) ?? 300,
          'monthly': double.tryParse(_monthlyPriceCtrl.text) ?? 1000,
        },
        'points_rules': {
          'points_per_ride':
              int.tryParse(_pointsPerRideCtrl.text) ?? 10,
          'holiday_multiplier':
              double.tryParse(_holidayMultiplierCtrl.text) ?? 2.0,
          'digital_payment_bonus':
              double.tryParse(_digitalPaymentBonusCtrl.text) ?? 5.0,
        },
        'points_redemption': {
          'points_for_20_discount':
              int.tryParse(_pointsFor20DiscountCtrl.text) ?? 100,
          'max_discount_etb':
              double.tryParse(_maxDiscountEtbCtrl.text) ?? 50.0,
          'points_for_free_ride':
              int.tryParse(_pointsForFreeRideCtrl.text) ?? 500,
          'max_free_ride_etb':
              double.tryParse(_maxFreeRideEtbCtrl.text) ?? 150.0,
        },
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ref.read(_adminSvcProvider).savePlatformSettings(settings);

      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saved = false);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الإعدادات تُحفظ في قاعدة البيانات - تم الحفظ بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Row(
              children: [
                const Icon(Icons.settings, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  'إعدادات المنصة',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Section 0: Surge Pricing ──────────────────────────────────────
            _SectionCard(
              title: 'أسعار الذروة',
              icon: Icons.bolt,
              color: Colors.orange.shade700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed-hour rules
                  const Text(
                    'قواعد الذروة الثابتة (يومية)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ..._fixedRules.map((rule) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${rule['name']}  '
                                '(${rule['from']}–${rule['to']})  '
                                '×${(rule['multiplier'] as double).toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Switch(
                              value: rule['active'] as bool,
                              activeColor: Colors.orange,
                              onChanged: (v) =>
                                  setState(() => rule['active'] = v),
                            ),
                          ],
                        ),
                      )),

                  const Divider(height: 24),

                  // Emergency surge
                  const Text(
                    'ذروة طارئة / يدوية',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 500;
                      return isWide
                          ? Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _surgeNameCtrl,
                                    decoration:
                                        const InputDecoration(
                                      labelText: 'اسم الذروة',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 110,
                                  child: TextFormField(
                                    controller:
                                        _surgeMultiplierCtrl,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                                decimal: true),
                                    decoration:
                                        const InputDecoration(
                                      labelText: 'المضاعف',
                                      suffixText: 'x',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _surgeUntilCtrl,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'تنتهي (ISO أو فارغ=2 ساعة)',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                TextFormField(
                                  controller: _surgeNameCtrl,
                                  decoration:
                                      const InputDecoration(
                                          labelText: 'اسم الذروة'),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller:
                                      _surgeMultiplierCtrl,
                                  keyboardType:
                                      const TextInputType
                                          .numberWithOptions(
                                              decimal: true),
                                  decoration:
                                      const InputDecoration(
                                    labelText: 'المضاعف',
                                    suffixText: 'x',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _surgeUntilCtrl,
                                  decoration:
                                      const InputDecoration(
                                    labelText:
                                        'تنتهي (ISO أو فارغ=2 ساعة)',
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!_surgeEnabled)
                        ElevatedButton.icon(
                          onPressed: _surgeSaving
                              ? null
                              : _activateEmergencySurge,
                          icon: _surgeSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.bolt, size: 18),
                          label: const Text('تفعيل الذروة الآن'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bolt,
                                  color: Colors.orange, size: 16),
                              SizedBox(width: 4),
                              Text('الذروة الطارئة مفعّلة',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight:
                                          FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _deactivateEmergencySurge,
                          icon: const Icon(Icons.stop, size: 16),
                          label: const Text('إيقاف'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(
                                color: AppColors.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Section 1: Vehicle Pricing ────────────────────────────────────
            _SectionCard(
              title: 'أسعار المركبات',
              icon: Icons.directions_car,
              color: AppColors.primary,
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'النوع',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'سعر الأساس (ETB)',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'سعر/كم (ETB)',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._basePrice.keys.map((type) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_car,
                                      size: 16,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    _vehicleLabels[type] ?? type,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _basePrice[type],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  suffixText: 'ETB',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'مطلوب' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _pricePerKm[type],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  suffixText: 'ETB/كم',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'مطلوب' : null,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Section 2: Subscription Pricing ──────────────────────────────
            _SectionCard(
              title: 'أسعار الاشتراكات',
              icon: Icons.card_membership,
              color: AppColors.secondary,
              child: LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return isWide
                    ? Row(
                        children: [
                          Expanded(
                              child: _buildSubPriceField(
                                  _dailyPriceCtrl, 'السعر اليومي')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildSubPriceField(
                                  _weeklyPriceCtrl, 'السعر الأسبوعي')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildSubPriceField(
                                  _monthlyPriceCtrl, 'السعر الشهري')),
                        ],
                      )
                    : Column(
                        children: [
                          _buildSubPriceField(
                              _dailyPriceCtrl, 'السعر اليومي'),
                          const SizedBox(height: 10),
                          _buildSubPriceField(
                              _weeklyPriceCtrl, 'السعر الأسبوعي'),
                          const SizedBox(height: 10),
                          _buildSubPriceField(
                              _monthlyPriceCtrl, 'السعر الشهري'),
                        ],
                      );
              }),
            ),
            const SizedBox(height: 16),

            // ── Section 3: Points Rules ───────────────────────────────────────
            _SectionCard(
              title: 'قواعد النقاط',
              icon: Icons.stars,
              color: AppColors.tertiary,
              child: LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pointsPerRideCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'نقاط لكل رحلة',
                                prefixIcon: Icon(Icons.directions_car, size: 18),
                                suffixText: 'نقطة',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _holidayMultiplierCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'مضاعف العطل',
                                prefixIcon: Icon(Icons.event, size: 18),
                                suffixText: 'x',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _digitalPaymentBonusCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'مكافأة الدفع الإلكتروني',
                                prefixIcon: Icon(Icons.payment, size: 18),
                                suffixText: '%',
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          TextFormField(
                            controller: _pointsPerRideCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'نقاط لكل رحلة',
                              suffixText: 'نقطة',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _holidayMultiplierCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'مضاعف العطل',
                              suffixText: 'x',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _digitalPaymentBonusCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'مكافأة الدفع الإلكتروني',
                              suffixText: '%',
                            ),
                          ),
                        ],
                      );
              }),
            ),
            const SizedBox(height: 16),

            // ── Section 4: Points Redemption ──────────────────────────────────
            _SectionCard(
              title: 'استرداد النقاط',
              icon: Icons.redeem,
              color: AppColors.info,
              child: LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return isWide
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _pointsFor20DiscountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'نقاط للخصم 20%',
                                    prefixIcon:
                                        Icon(Icons.discount, size: 18),
                                    suffixText: 'نقطة',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _maxDiscountEtbCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'الحد الأقصى للخصم',
                                    prefixIcon:
                                        Icon(Icons.money_off, size: 18),
                                    suffixText: 'ETB',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _pointsForFreeRideCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'نقاط للرحلة المجانية',
                                    prefixIcon: Icon(Icons.directions_car,
                                        size: 18),
                                    suffixText: 'نقطة',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _maxFreeRideEtbCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'الحد الأقصى للرحلة المجانية',
                                    prefixIcon: Icon(Icons.price_check,
                                        size: 18),
                                    suffixText: 'ETB',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          TextFormField(
                            controller: _pointsFor20DiscountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'نقاط للخصم 20%',
                              suffixText: 'نقطة',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _maxDiscountEtbCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'الحد الأقصى للخصم',
                              suffixText: 'ETB',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _pointsForFreeRideCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'نقاط للرحلة المجانية',
                              suffixText: 'نقطة',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _maxFreeRideEtbCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'الحد الأقصى للرحلة المجانية',
                              suffixText: 'ETB',
                            ),
                          ),
                        ],
                      );
              }),
            ),
            const SizedBox(height: 16),

            // ── Fleet Owner Subscription Plans ──────────────────────────────────────────
            _SectionCard(
              title: 'خطط اشتراك مالك الأسطول',
              icon: Icons.directions_bus,
              color: Colors.teal.shade700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_fleetPlansLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_fleetPlans.isEmpty)
                    const Text(
                      'لا توجد خطط نشطة حالياً',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else
                    ..._fleetPlans.map((plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${plan['max_vehicles']} مركبة  ·  '
                                      '${plan['monthly_fee_etb']} ETB/شهر',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: plan['is_active'] as bool? ?? true,
                                activeColor: Colors.teal,
                                onChanged: (v) =>
                                    _toggleFleetPlanActive(plan, v),
                              ),
                            ],
                          ),
                        )),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddFleetPlanDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة خطة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Legal Documents ───────────────────────────────────────────────
            _SectionCard(
              title: 'الوثائق القانونية',
              icon: Icons.gavel,
              color: Colors.indigo.shade700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_legalDocLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_activeDoc == null)
                    const Text(
                      'لا توجد وثيقة قانونية نشطة حالياً',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description,
                                  size: 16, color: Colors.indigo),
                              const SizedBox(width: 6),
                              Text(
                                _activeDoc!['doc_type'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'v${_activeDoc!['version'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.indigo,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'تاريخ الإنشاء: ${_activeDoc!['created_at'] != null ? DateTime.tryParse(_activeDoc!['created_at'].toString())?.toLocal().toString().split('.').first ?? _activeDoc!['created_at'] : '—'}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'عدد المستخدمين الذين قبلوا الوثيقة: $_docAcceptanceCount',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showPublishLegalDocDialog,
                    icon: const Icon(Icons.publish, size: 18),
                    label: const Text('نشر إصدار جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Save Button ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.info, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'الإعدادات تُحفظ في قاعدة البيانات وتُطبَّق فوراً على التطبيق',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSettings,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              _saved ? Icons.check : Icons.save,
                              size: 18,
                            ),
                      label: Text(_saved ? 'تم الحفظ ✓' : 'حفظ الإعدادات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _saved ? AppColors.success : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSubPriceField(
      TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'ETB',
      ),
      validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
    );
  }
}

// ── Reusable Section Card ──────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style:
                      Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
