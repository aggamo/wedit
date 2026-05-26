import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class VehicleTypeCard extends StatelessWidget {
  final String vehicleType;
  final bool isSelected;
  final double? estimatedPrice;
  final String? etaLabel;
  final VoidCallback onTap;

  const VehicleTypeCard({
    super.key,
    required this.vehicleType,
    required this.isSelected,
    this.estimatedPrice,
    this.etaLabel,
    required this.onTap,
  });

  String get _displayName {
    switch (vehicleType) {
      case 'sedan':
        return 'سيدان';
      case 'suv':
        return 'دفع رباعي';
      case 'vip':
        return 'VIP';
      case 'minibus':
        return 'ميني باص';
      default:
        return vehicleType;
    }
  }

  IconData get _icon {
    switch (vehicleType) {
      case 'sedan':
        return Icons.directions_car;
      case 'suv':
        return Icons.directions_car_filled;
      case 'vip':
        return Icons.star_rounded;
      case 'minibus':
        return Icons.airport_shuttle;
      default:
        return Icons.directions_car;
    }
  }

  Color get _accentColor {
    switch (vehicleType) {
      case 'sedan':
        return AppColors.primary;
      case 'suv':
        return Colors.teal;
      case 'vip':
        return Colors.amber.shade700;
      case 'minibus':
        return Colors.deepPurple;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Vehicle icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(isSelected ? 0.15 : 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                color: accent,
                size: 24,
              ),
            ),

            const SizedBox(height: 6),

            // Vehicle name
            Text(
              _displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? accent : AppColors.textPrimary,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Estimated price
            if (estimatedPrice != null) ...[
              const SizedBox(height: 3),
              Text(
                '~${estimatedPrice!.toStringAsFixed(0)} ب',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? accent
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : null,
                ),
              ),
            ],

            // ETA label (optional)
            if (etaLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                etaLabel!,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
