import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

class SubscriptionCard extends StatelessWidget {
  final String plan;
  final bool isSelected;
  final VoidCallback onTap;

  const SubscriptionCard({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  String get _planLabel {
    switch (plan) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return plan;
    }
  }

  double get _price {
    switch (plan) {
      case 'daily':
        return AppConstants.dailyPrice;
      case 'weekly':
        return AppConstants.weeklyPrice;
      case 'monthly':
        return AppConstants.monthlyPrice;
      default:
        return AppConstants.dailyPrice;
    }
  }

  String? get _savingsBadge {
    switch (plan) {
      case 'weekly':
        return 'وفر 14%';
      case 'monthly':
        return 'وفر 33%';
      default:
        return null;
    }
  }

  List<String> get _features {
    switch (plan) {
      case 'daily':
        return ['استقبال الطلبات ليوم كامل', 'دعم على مدار الساعة'];
      case 'weekly':
        return [
          'استقبال الطلبات لأسبوع كامل',
          'دعم ذو أولوية',
          'توفير مقارنة بالخطة اليومية',
        ];
      case 'monthly':
        return [
          'استقبال الطلبات لشهر كامل',
          'دعم ذو أولوية',
          'أفضل توفير',
          'مؤهل للمشاركة في سباق الجوائز',
        ];
      default:
        return [];
    }
  }

  IconData get _icon {
    switch (plan) {
      case 'daily':
        return Icons.wb_sunny_rounded;
      case 'weekly':
        return Icons.calendar_view_week_rounded;
      case 'monthly':
        return Icons.calendar_month_rounded;
      default:
        return Icons.subscription_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saving = _savingsBadge;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icon,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _planLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      if (saving != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.3)
                                : AppTheme.tertiaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            saving,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  ..._features.take(2).map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.8)
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.formatCurrency(_price),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
                Text(
                  '/ ${plan == 'daily' ? 'يوم' : plan == 'weekly' ? 'أسبوع' : 'شهر'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withOpacity(0.7)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
