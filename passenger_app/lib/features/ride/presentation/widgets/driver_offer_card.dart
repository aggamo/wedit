import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ride_offer_entity.dart';

class DriverOfferCard extends StatelessWidget {
  final RideOfferEntity offer;
  final VoidCallback onAccept;

  const DriverOfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
  });

  String _maskedPlate(String plate) {
    if (plate.length <= 4) return plate;
    return '${plate.substring(0, 2)}**${plate.substring(plate.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: offer.isSystemPrice
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          if (offer.isSystemPrice)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'بسعر النظام',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: offer.driverAvatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: offer.driverAvatarUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildAvatarPlaceholder(theme),
                      errorWidget: (_, __, ___) =>
                          _buildAvatarPlaceholder(theme),
                    )
                  : _buildAvatarPlaceholder(theme),
            ),
            const SizedBox(width: 12),
            // Driver info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.driverName,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _RatingStars(rating: offer.driverRating),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.directions_car,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        offer.vehicleModel,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _parseColor(offer.vehicleColor),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.grey.shade300, width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        offer.vehicleColor,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.confirmation_number,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _maskedPlate(offer.vehiclePlate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.access_time,
                          size: 14, color: AppColors.secondary),
                      const SizedBox(width: 2),
                      Text(
                        '${offer.etaMinutes} د',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price + Accept button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${offer.offeredPrice.toStringAsFixed(0)} ب',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    minimumSize: const Size(70, 36),
                  ),
                  child: const Text('قبول'),
                ),
              ],
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.primary.withOpacity(0.1),
      child: const Icon(Icons.person, color: AppColors.primary, size: 32),
    );
  }

  Color _parseColor(String colorName) {
    const colorMap = {
      'أبيض': Colors.white,
      'أسود': Colors.black,
      'رمادي': Colors.grey,
      'أحمر': Colors.red,
      'أزرق': Colors.blue,
      'فضي': Colors.blueGrey,
      'white': Colors.white,
      'black': Colors.black,
      'grey': Colors.grey,
      'silver': Colors.blueGrey,
    };
    return colorMap[colorName.toLowerCase()] ?? Colors.grey;
  }
}

class _RatingStars extends StatelessWidget {
  final double rating;

  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 14, color: AppColors.tertiary),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.tertiary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
