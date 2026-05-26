import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ride_offer_entity.dart';
import '../providers/ride_provider.dart';
import '../widgets/driver_offer_card.dart';

class RideOffersScreen extends ConsumerStatefulWidget {
  final String rideId;
  final double systemPrice;

  const RideOffersScreen({
    super.key,
    required this.rideId,
    this.systemPrice = 0,
  });

  @override
  ConsumerState<RideOffersScreen> createState() => _RideOffersScreenState();
}

class _RideOffersScreenState extends ConsumerState<RideOffersScreen> {
  static const _initialSeconds = 45;

  Timer? _countdownTimer;
  int _secondsRemaining = _initialSeconds;
  bool _awaitingSystemPrice = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _onTimeout();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _onTimeout() {
    // Auto-extend if still waiting for first offer
    final offersAsync = ref.read(rideOffersProvider(widget.rideId));
    final hasOffers = offersAsync.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );

    if (!hasOffers) {
      // No offers yet — auto-extend 45 more seconds silently
      setState(() => _secondsRemaining = _initialSeconds);
      _startCountdown();
    } else {
      // Offers exist but no selection — show dialog
      _showTimeoutDialog();
    }
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('انتهت المهلة'),
        content: const Text(
            'لم تختر سائقاً بعد. هل تريد الاستمرار في الانتظار؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: const Text('إلغاء الطلب'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _secondsRemaining = _initialSeconds);
              _startCountdown();
            },
            child: const Text('الاستمرار'),
          ),
        ],
      ),
    );
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

  Future<void> _acceptSystemPrice(List<RideOfferEntity> offers) async {
    final notifier = ref.read(rideStateProvider.notifier);
    final ride =
        await notifier.acceptSystemPrice(widget.rideId, offers);

    if (ride != null && mounted) {
      context.go('/ride/${ride.id}/tracking');
    } else {
      // No system-price offer yet — set waiting flag and notify user
      setState(() => _awaitingSystemPrice = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'في انتظار سائق يقبل بسعر النظام... سيتم الإسناد تلقائياً عند وصوله'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Auto-accept when a system-price offer arrives while flag is set
  void _checkAutoAccept(List<RideOfferEntity> offers) {
    if (!_awaitingSystemPrice) return;
    final systemOffer = offers.cast<RideOfferEntity?>().firstWhere(
          (o) => o!.isSystemPrice && o.status == 'pending',
          orElse: () => null,
        );
    if (systemOffer != null) {
      _awaitingSystemPrice = false;
      _acceptOffer(systemOffer.id);
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
      _countdownTimer?.cancel();
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

    // Auto-accept logic
    offersAsync.whenData((offers) => _checkAutoAccept(offers));

    final double resolvedSystemPrice = widget.systemPrice > 0
        ? widget.systemPrice
        : ref.watch(rideStateProvider).currentRide?.agreedPrice ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelRide,
        ),
        title: const Text('جاري البحث عن سائق'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Top status bar ──────────────────────────────────────────────────
          Container(
            color: AppColors.surfaceVariant,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Countdown
                _CountdownWidget(seconds: _secondsRemaining),

                // Pulse indicator
                offersAsync.when(
                  data: (offers) => _DriversCountBadge(count: offers.length),
                  loading: () => const _SearchingIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // ── Accept system price button (always visible) ─────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _SystemPriceButton(
              systemPrice: resolvedSystemPrice,
              isWaiting: _awaitingSystemPrice,
              onTap: () => offersAsync.whenData(
                  (offers) => _acceptSystemPrice(offers)),
            ),
          ),

          // ── Offers list ─────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('عروض السائقين',
                    style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                offersAsync.whenData(
                      (offers) => offers.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${offers.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ) ??
                    const SizedBox.shrink(),
              ],
            ),
          ),

          Expanded(
            child: offersAsync.when(
              loading: () => const _SearchingState(),
              error: (e, _) => _ErrorState(
                onRetry: () =>
                    ref.invalidate(rideOffersProvider(widget.rideId)),
              ),
              data: (offers) {
                if (offers.isEmpty) {
                  return const _WaitingForOffersState();
                }

                // Sort: system-price offers first, then by price ascending
                final sorted = List<RideOfferEntity>.from(offers)
                  ..sort((a, b) {
                    if (a.isSystemPrice && !b.isSystemPrice) return -1;
                    if (!a.isSystemPrice && b.isSystemPrice) return 1;
                    return a.offeredPrice.compareTo(b.offeredPrice);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CountdownWidget extends StatelessWidget {
  final int seconds;
  const _CountdownWidget({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final isUrgent = seconds <= 10;
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 18,
          color: isUrgent ? AppColors.error : AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          '$seconds ثانية',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isUrgent ? AppColors.error : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DriversCountBadge extends StatelessWidget {
  final int count;
  const _DriversCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 16,
            color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$count عرض وصل',
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SearchingIndicator extends StatelessWidget {
  const _SearchingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 6),
        Text('جاري البحث...', style: TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _SystemPriceButton extends StatelessWidget {
  final double systemPrice;
  final bool isWaiting;
  final VoidCallback onTap;

  const _SystemPriceButton({
    required this.systemPrice,
    required this.isWaiting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isWaiting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: isWaiting
              ? null
              : const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1565C0)],
                ),
          color: isWaiting ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isWaiting
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWaiting
                      ? 'في انتظار أول سائق يقبل السعر...'
                      : 'قبول بسعر النظام',
                  style: TextStyle(
                    color: isWaiting ? Colors.grey : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isWaiting)
                  Text(
                    'أسرع قبول — أول سائق يقبل يأخذ الرحلة',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            if (systemPrice > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isWaiting ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${systemPrice.toStringAsFixed(0)} ب',
                  style: TextStyle(
                    color: isWaiting ? Colors.grey : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchingState extends StatelessWidget {
  const _SearchingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('جاري البحث عن سائقين...',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}

class _WaitingForOffersState extends StatelessWidget {
  const _WaitingForOffersState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined,
              size: 64, color: AppColors.textDisabled),
          SizedBox(height: 16),
          Text('لم تصل عروض بعد',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
          SizedBox(height: 8),
          Text('ستظهر هنا فور وصولها',
              style:
                  TextStyle(color: AppColors.textHint, fontSize: 13)),
          SizedBox(height: 16),
          Text(
            'يمكنك قبول سعر النظام أعلاه في أي وقت',
            style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('حدث خطأ في جلب العروض'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
