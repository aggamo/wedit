import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _referralInputController = TextEditingController();
  bool _isApplying = false;

  @override
  void dispose() {
    _referralInputController.dispose();
    super.dispose();
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الكود'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  void _shareCode(String code) {
    Share.share(
      'انضم إلى wedit باستخدام كود الإحالة: $code\n'
      'احصل على ${AppConstants.pointsPerReferral} نقطة عند تسجيلك!\n'
      'wedit - تنقّل بذكاء في أديس أبابا',
      subject: 'دعوة للانضمام إلى wedit',
    );
  }

  Future<void> _applyReferralCode(String code) async {
    if (code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال كود الإحالة')),
      );
      return;
    }

    setState(() => _isApplying = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تطبيق كود الإحالة بنجاح! +20 نقطة'),
          backgroundColor: AppColors.secondary,
        ),
      );
      _referralInputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أدعُ أصدقاءك'),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('خطأ في التحميل')),
        data: (user) {
          final referralCode = user?.referralCode ?? 'WEDIT00';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.people_alt,
                          color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'ادعُ أصدقاءك وكسب نقاطاً!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Benefits row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BenefitChip(
                            label: 'أنت',
                            points: '+${AppConstants.pointsPerReferral} نقطة',
                          ),
                          const SizedBox(width: 16),
                          const Text('|',
                              style: TextStyle(color: Colors.white54)),
                          const SizedBox(width: 16),
                          _BenefitChip(
                            label: 'صديقك',
                            points: '+20 نقطة',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Referral code card
                Text('كود الإحالة الخاص بك',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.primary.withOpacity(0.05),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        referralCode,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _copyCode(referralCode),
                        icon: const Icon(Icons.copy,
                            color: AppColors.primary),
                        tooltip: 'نسخ',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareCode(referralCode),
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة الكود'),
                  ),
                ),

                const SizedBox(height: 24),

                // Apply referral code section
                Text('أدخل كود إحالة',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _referralInputController,
                        textDirection: TextDirection.ltr,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'أدخل كود الإحالة',
                          prefixIcon: Icon(Icons.confirmation_number),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isApplying
                          ? null
                          : () => _applyReferralCode(
                              _referralInputController.text),
                      child: _isApplying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('تطبيق'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Referral history
                Text('سجل الإحالات', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                const _EmptyReferralHistory(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;
  final String points;

  const _BenefitChip({required this.label, required this.points});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          points,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _EmptyReferralHistory extends StatelessWidget {
  const _EmptyReferralHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.person_add_disabled,
                size: 40, color: AppColors.textDisabled),
            SizedBox(height: 8),
            Text(
              'لم تقم بإحالة أي صديق بعد',
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
