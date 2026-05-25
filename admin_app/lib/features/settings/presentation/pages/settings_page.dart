import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const _vehicleLabels = {
    'sedan': 'سيدان',
    'suv': 'دفع رباعي',
    'vip': 'VIP',
    'minibus': 'ميني باص',
  };

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
    super.dispose();
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
