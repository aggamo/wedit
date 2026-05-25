import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class RideCompletedScreen extends ConsumerStatefulWidget {
  final String rideId;

  const RideCompletedScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideCompletedScreen> createState() =>
      _RideCompletedScreenState();
}

class _RideCompletedScreenState extends ConsumerState<RideCompletedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _pointsSlideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _pointsSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rideAsync = ref.watch(currentRideProvider(widget.rideId));

    return Scaffold(
      body: SafeArea(
        child: rideAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildBody(context, theme, null),
          data: (ride) => _buildBody(context, theme, ride.finalPrice),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ThemeData theme, double? finalPrice) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Green checkmark animation
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'وصلت بأمان!',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'نشكرك على استخدام wedit',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // Ride summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    icon: Icons.radio_button_on,
                    iconColor: AppColors.secondary,
                    label: 'من',
                    value: 'موقع الانطلاق',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    icon: Icons.location_on,
                    iconColor: AppColors.error,
                    label: 'إلى',
                    value: 'الوجهة',
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    icon: Icons.straighten,
                    iconColor: AppColors.primary,
                    label: 'المسافة',
                    value: '~5 كم',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    icon: Icons.timer,
                    iconColor: AppColors.primary,
                    label: 'المدة',
                    value: '~15 دقيقة',
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    icon: Icons.payments,
                    iconColor: AppColors.tertiary,
                    label: 'المبلغ المدفوع',
                    value: finalPrice != null
                        ? '${finalPrice.toStringAsFixed(0)} ب'
                        : '---',
                    valueStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.secondary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'تم الدفع نقداً',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Points earned
          SlideTransition(
            position: _pointsSlideAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.tertiary.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars,
                      color: AppColors.tertiary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '+${AppConstants.pointsPerRide} نقطة',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.tertiaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'مضافة لرصيدك',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.tertiaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.push('/ride/${widget.rideId}/rate'),
              icon: const Icon(Icons.star_border),
              label: const Text('تقييم رحلتك'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(Icons.home_outlined),
              label: const Text('رحلة أخرى'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall),
        const Spacer(),
        Text(
          value,
          style: valueStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
