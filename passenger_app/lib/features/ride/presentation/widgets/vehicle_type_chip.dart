import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class VehicleTypeChip extends StatelessWidget {
  final String vehicleType;
  final bool isSelected;
  final double? estimatedPrice;
  final VoidCallback onTap;

  const VehicleTypeChip({
    super.key,
    required this.vehicleType,
    required this.isSelected,
    this.estimatedPrice,
    required this.onTap,
  });

  String get _displayName {
    switch (vehicleType) {
      case 'sedan':
        return 'سيدان';
      case 'suv':
        return 'SUV';
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
        return Icons.star;
      case 'minibus':
        return Icons.airport_shuttle;
      default:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelectedColor = AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? isSelectedColor.withOpacity(0.1)
              : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? isSelectedColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              color: isSelected ? isSelectedColor : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              _displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? isSelectedColor : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (estimatedPrice != null) ...[
              const SizedBox(height: 2),
              Text(
                '~${estimatedPrice!.toStringAsFixed(0)} ب',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? isSelectedColor
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
