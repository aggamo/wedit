import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ride_entity.dart';
import '../providers/ride_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(rideHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلاتي السابقة'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('خطأ في تحميل الرحلات'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(rideHistoryProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (rides) {
          if (rides.isEmpty) {
            return const _EmptyHistoryState();
          }
          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              return RideHistoryCard(ride: rides[index]);
            },
          );
        },
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            'لم تقم بأي رحلات بعد',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ رحلتك الأولى الآن!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class RideHistoryCard extends StatelessWidget {
  final RideEntity ride;

  const RideHistoryCard({super.key, required this.ride});

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.rideStatusCompleted:
        return AppColors.statusCompleted;
      case AppConstants.rideStatusCancelled:
        return AppColors.statusCancelled;
      case AppConstants.rideStatusStarted:
        return AppColors.statusStarted;
      case AppConstants.rideStatusAccepted:
        return AppColors.statusAccepted;
      default:
        return AppColors.statusPending;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppConstants.rideStatusCompleted:
        return 'مكتملة';
      case AppConstants.rideStatusCancelled:
        return 'ملغاة';
      case AppConstants.rideStatusStarted:
        return 'جارية';
      case AppConstants.rideStatusAccepted:
        return 'مقبولة';
      default:
        return 'قيد الانتظار';
    }
  }

  IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType) {
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'الأمس';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: date, vehicle type, status badge
            Row(
              children: [
                Icon(_vehicleIcon(ride.vehicleType),
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 6),
                Text(
                  _vehicleTypeName(ride.vehicleType),
                  style: theme.textTheme.labelMedium,
                ),
                const Spacer(),
                Text(
                  _formatDate(ride.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(ride.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(ride.status),
                    style: TextStyle(
                      color: _statusColor(ride.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Route
            Row(
              children: [
                const Icon(Icons.radio_button_on,
                    color: AppColors.secondary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ride.pickupAddress,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Container(
                width: 1,
                height: 12,
                color: AppColors.textDisabled,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ride.destinationAddress,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Price
            if (ride.finalPrice != null || ride.offeredPrice != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${(ride.finalPrice ?? ride.offeredPrice)!.toStringAsFixed(0)} ب',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _vehicleTypeName(String vt) {
    switch (vt) {
      case 'suv':
        return 'SUV';
      case 'vip':
        return 'VIP';
      case 'minibus':
        return 'ميني باص';
      default:
        return 'سيدان';
    }
  }
}
