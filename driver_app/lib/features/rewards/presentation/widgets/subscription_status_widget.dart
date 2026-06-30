import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SubscriptionStatusWidget extends StatelessWidget {
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic>? planInfo;
  final int todayRides;
  final int dailyGoal;
  final VoidCallback onFreezeTap;
  final VoidCallback onUnfreezeTap;

  const SubscriptionStatusWidget({
    super.key,
    required this.subscription,
    required this.planInfo,
    required this.todayRides,
    required this.dailyGoal,
    required this.onFreezeTap,
    required this.onUnfreezeTap,
  });

  bool get _isFrozen => subscription?['is_frozen'] == true;

  String get _planName {
    if (planInfo != null) {
      return planInfo!['name_ar'] as String? ??
          planInfo!['name'] as String? ??
          'خطة نشطة';
    }
    return subscription?['plan_name'] as String? ?? 'خطة نشطة';
  }

  @override
  Widget build(BuildContext context) {
    if (subscription == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'لا يوجد اشتراك نشط',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    final useActiveDays = subscription!['use_active_days'] == true ||
        (planInfo?['use_active_days'] == true);
    final activeDaysQuota =
        (subscription!['active_days_quota'] as num?)?.toInt() ??
            (planInfo?['active_days_quota'] as num?)?.toInt() ??
            0;
    final activeDaysUsed =
        (subscription!['active_days_used'] as num?)?.toInt() ?? 0;
    final activeDaysRemaining =
        useActiveDays ? (activeDaysQuota - activeDaysUsed) : null;

    final statusMessage = _buildStatusMessage();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  _isFrozen ? Icons.ac_unit_rounded : Icons.card_membership_rounded,
                  color: _isFrozen ? Colors.blue : AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _planName,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isFrozen
                        ? Colors.blue.shade50
                        : AppTheme.secondaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isFrozen ? 'مجمد' : 'نشط',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          _isFrozen ? Colors.blue : AppTheme.secondaryColor,
                    ),
                  ),
                ),
              ],
            ),

            if (useActiveDays && activeDaysRemaining != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'الأيام المتبقية: $activeDaysRemaining / $activeDaysQuota',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: activeDaysQuota > 0
                      ? (activeDaysUsed / activeDaysQuota).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Status message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusMessageColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _statusMessageColor.withOpacity(0.3), width: 1),
              ),
              child: Text(
                statusMessage,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: _statusMessageColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            // Freeze / Unfreeze button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isFrozen ? onUnfreezeTap : onFreezeTap,
                icon: Icon(
                  _isFrozen ? Icons.play_arrow_rounded : Icons.ac_unit_rounded,
                  size: 18,
                ),
                label: Text(
                  _isFrozen ? 'إلغاء التجميد' : 'تجميد الاشتراك',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _isFrozen ? AppTheme.secondaryColor : Colors.blue,
                  side: BorderSide(
                    color: _isFrozen ? AppTheme.secondaryColor : Colors.blue,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildStatusMessage() {
    if (_isFrozen) return 'الاشتراك مجمد حالياً ❄️';
    if (dailyGoal <= 0) return 'أكمل رحلاتك اليومية';
    if (todayRides >= dailyGoal) {
      return 'أنت على المسار الصحيح ✓ — اليوم سيُحتسب من رصيدك';
    }
    final remaining = dailyGoal - todayRides;
    if (remaining == 1) {
      return 'تبقى رحلة واحدة لاحتساب اليوم من رصيدك';
    }
    return 'تبقى $remaining رحلات لاحتساب اليوم من رصيدك';
  }

  Color get _statusMessageColor {
    if (_isFrozen) return Colors.blue;
    if (dailyGoal <= 0) return Colors.grey;
    if (todayRides >= dailyGoal) return AppTheme.secondaryColor;
    return AppTheme.tertiaryColor;
  }
}
