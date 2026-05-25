import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ride_offer_entity.dart';
import '../providers/ride_provider.dart';
import '../widgets/driver_offer_card.dart';

enum _SortMode { price, eta }

class RideOffersScreen extends ConsumerStatefulWidget {
  final String rideId;

  const RideOffersScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideOffersScreen> createState() => _RideOffersScreenState();
}

class _RideOffersScreenState extends ConsumerState<RideOffersScreen> {
  _SortMode _sortMode = _SortMode.price;
  Timer? _countdownTimer;
  int _secondsRemaining = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        if (mounted) {
          _onTimeout();
        }
      } else {
        if (mounted) setState(() => _secondsRemaining--);
      }
    });
  }

  void _onTimeout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('انتهت المهلة'),
        content: const Text('لم يتم العثور على سائق. هل تريد المحاولة مجدداً؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: const Text('لا، الرجوع'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _secondsRemaining = 300);
              _startCountdown();
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  List<RideOfferEntity> _sortedOffers(List<RideOfferEntity> offers) {
    final sorted = List<RideOfferEntity>.from(offers);
    if (_sortMode == _SortMode.price) {
      sorted.sort((a, b) => a.offeredPrice.compareTo(b.offeredPrice));
    } else {
      sorted.sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
    }
    return sorted;
  }

  Future<void> _acceptOffer(String offerId) async {
    final notifier = ref.read(rideStateProvider.notifier);
    final ride = await notifier.acceptOffer(offerId);

    if (ride != null && mounted) {
      context.go('/ride/${ride.id}/tracking');
    } else {
      final error = ref.read(rideStateProvider).error;
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الرحلة'),
        content: const Text('هل أنت متأكد من إلغاء طلب الرحلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusCancelled),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(rideStateProvider.notifier);
      await notifier.cancelRide(widget.rideId, 'إلغاء من قِبل الراكب');
      if (mounted) context.go('/home');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offersAsync = ref.watch(rideOffersProvider(widget.rideId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('عروض السائقين'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _secondsRemaining > 60
                    ? AppColors.secondary.withOpacity(0.15)
                    : AppColors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 14,
                    color: _secondsRemaining > 60
                        ? AppColors.secondary
                        : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCountdown(_secondsRemaining),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _secondsRemaining > 60
                          ? AppColors.secondary
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelRide,
        ),
      ),
      body: Column(
        children: [
          // Sort toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('ترتيب حسب:',
                    style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('السعر'),
                  selected: _sortMode == _SortMode.price,
                  onSelected: (_) =>
                      setState(() => _sortMode = _SortMode.price),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('وقت الوصول'),
                  selected: _sortMode == _SortMode.eta,
                  onSelected: (_) =>
                      setState(() => _sortMode = _SortMode.eta),
                ),
              ],
            ),
          ),

          // Offers list
          Expanded(
            child: offersAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'جاري البحث عن سائقين...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'يرجى الانتظار',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('حدث خطأ في جلب العروض'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(rideOffersProvider(widget.rideId)),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (offers) {
                if (offers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_car_outlined,
                            size: 64, color: AppColors.textDisabled),
                        const SizedBox(height: 16),
                        const Text(
                          'لا يوجد سائقون متاحون الآن',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'جاري البحث...',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.invalidate(rideOffersProvider(widget.rideId)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('تحديث'),
                        ),
                      ],
                    ),
                  );
                }

                final sorted = _sortedOffers(offers);

                return ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final offer = sorted[index];
                    return DriverOfferCard(
                      offer: offer,
                      onAccept: () => _acceptOffer(offer.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
