import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _counterAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Will be set once we know the actual points
    _counterAnim = IntTween(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  void _startAnimation(int points) {
    if (!_controller.isAnimating && _controller.value == 0) {
      final tween = IntTween(begin: 0, end: points);
      _counterAnim = tween.animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نقاطي'),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('خطأ في التحميل')),
        data: (user) {
          final points = user?.points ?? 0;
          _startAnimation(points);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Animated points counter
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.tertiary, AppColors.tertiaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tertiary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.stars, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _counterAnim,
                      builder: (_, __) {
                        return Text(
                          '${_counterAnim.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                          ),
                        );
                      },
                    ),
                    const Text(
                      'نقطة',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text('استبدل نقاطك',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),

              // Redemption card 1: 20% discount
              _RedemptionCard(
                icon: Icons.discount,
                title: 'خصم 20%',
                description:
                    '100 نقطة تساوي خصم 20% على رحلة (بحد أقصى 50 ب)',
                requiredPoints: AppConstants.pointsRedemptionDiscountThreshold,
                currentPoints: points,
                buttonLabel: 'استخدم 100 نقطة',
                onUse: () => _showRedeemDialog(
                  context,
                  title: 'خصم 20%',
                  requiredPoints: 100,
                  points: points,
                ),
              ),

              const SizedBox(height: 12),

              // Redemption card 2: free ride
              _RedemptionCard(
                icon: Icons.directions_car,
                title: 'رحلة مجانية',
                description:
                    '500 نقطة تساوي رحلة مجانية (بحد أقصى 150 ب)',
                requiredPoints:
                    AppConstants.pointsRedemptionFreeRideThreshold,
                currentPoints: points,
                buttonLabel: 'استخدم 500 نقطة',
                onUse: () => _showRedeemDialog(
                  context,
                  title: 'رحلة مجانية',
                  requiredPoints: 500,
                  points: points,
                ),
              ),

              const SizedBox(height: 24),

              Text('كيف تكسب النقاط؟',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),

              ..._earningMethods.map(
                (method) => _EarningMethodTile(
                  icon: method.$1,
                  title: method.$2,
                  points: method.$3,
                ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  static const _earningMethods = [
    (Icons.directions_car, 'إكمال رحلة', '+${AppConstants.pointsPerRide} نقطة'),
    (Icons.people, 'إحالة صديق', '+${AppConstants.pointsPerReferral} نقطة'),
    (Icons.star, 'تقييم الرحلة', '+5 نقاط'),
    (Icons.calendar_month, 'الاستخدام الأسبوعي', '+20 نقطة'),
  ];

  void _showRedeemDialog(
    BuildContext context, {
    required String title,
    required int requiredPoints,
    required int points,
  }) {
    if (points < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تحتاج ${requiredPoints - points} نقطة إضافية لاستخدام هذه المكافأة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('استبدال: $title'),
        content:
            Text('سيتم خصم $requiredPoints نقطة من رصيدك. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم استبدال النقاط بنجاح!'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int requiredPoints;
  final int currentPoints;
  final String buttonLabel;
  final VoidCallback onUse;

  const _RedemptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.requiredPoints,
    required this.currentPoints,
    required this.buttonLabel,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canRedeem = currentPoints >= requiredPoints;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canRedeem
                    ? AppColors.tertiary.withOpacity(0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: canRedeem
                    ? AppColors.tertiaryDark
                    : AppColors.textDisabled,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  if (!canRedeem)
                    Text(
                      'تحتاج ${requiredPoints - currentPoints} نقطة إضافية',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: canRedeem ? onUse : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('استخدم'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String points;

  const _EarningMethodTile({
    required this.icon,
    required this.title,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.secondary.withOpacity(0.1),
        child: Icon(icon, color: AppColors.secondary, size: 20),
      ),
      title: Text(title, style: theme.textTheme.bodyMedium),
      trailing: Text(
        points,
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
