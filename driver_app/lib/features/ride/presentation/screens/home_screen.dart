import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../leaderboard/presentation/widgets/leaderboard_home_widget.dart';
import '../../domain/entities/ride_entity.dart';
import '../providers/ride_provider.dart';
import '../widgets/ride_request_dialog.dart';
import '../widgets/street_hail_dialog.dart';
import '../widgets/surge_toggle_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  Timer? _locationTimer;
  Position? _currentPosition;
  bool _dialogShowing = false;
  final Set<String> _shownRequestIds = {};

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(9.0280, 38.7469),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _currentPosition = position);
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    } catch (_) {}

    // Periodic location updates every 5 seconds when online
    _locationTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _updateLocation());
  }

  Future<void> _updateLocation() async {
    final isOnline = ref.read(onlineStatusProvider);
    if (!isOnline) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) setState(() => _currentPosition = position);
      ref.read(rideNotifierProvider.notifier).updateLocation(
            position.latitude,
            position.longitude,
            position.heading,
          );
    } catch (_) {}
  }

  void _toggleOnlineStatus() async {
    final current = ref.read(onlineStatusProvider);
    final newStatus = !current;
    ref.read(onlineStatusProvider.notifier).state = newStatus;
    await ref
        .read(rideNotifierProvider.notifier)
        .setOnlineStatus(newStatus);
  }

  void _handleIncomingRequest(BuildContext context,
      List<dynamic> requests) {
    if (_dialogShowing || requests.isEmpty) return;

    for (final request in requests) {
      if (!_shownRequestIds.contains(request.rideId) &&
          !request.isExpired) {
        _shownRequestIds.add(request.rideId);
        _showRideRequest(context, request);
        break;
      }
    }
  }

  Future<void> _startStreetHail(BuildContext context) async {
    final params = await showStreetHailDialog(context);
    if (params == null || !mounted) return;

    Position? pos = _currentPosition;
    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (_) {}
    }
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تحديد موقعك الحالي')),
        );
      }
      return;
    }

    final ride = await ref.read(rideNotifierProvider.notifier).startStreetHailRide(
          passengerPhone: params.passengerPhone,
          vehicleType: params.vehicleType,
          startLat: pos.latitude,
          startLng: pos.longitude,
          destination: params.destination,
        );

    if (ride != null && mounted) {
      context.go('/street-hail/${ride.id}', extra: {
        'passengerPhone': params.passengerPhone,
        'vehicleType': params.vehicleType,
        'startLat': pos.latitude,
        'startLng': pos.longitude,
      });
    } else {
      final err = ref.read(rideNotifierProvider).error;
      if (mounted && err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    }
  }

  Future<void> _showRideRequest(
      BuildContext context, dynamic request) async {
    _dialogShowing = true;
    final isSurge = ref.read(surgeModeProvider);
    final result = await showRideRequestDialog(context, request, surgeEnabled: isSurge);
    _dialogShowing = false;

    if (result != null && mounted) {
      await ref
          .read(rideNotifierProvider.notifier)
          .submitOffer(request.rideId, result.price,
              isSystemPrice: result.isSystemPrice,
              isSurgeOffer: result.isSurgeOffer);
      if (mounted) {
        context.go('/ride/${request.rideId}/navigate');
      }
    } else {
      ref
          .read(rideNotifierProvider.notifier)
          .declineRequest(request.rideId);
    }
  }

  Future<void> _showCallCenterRideDialog(
      BuildContext context, RideEntity ride) async {
    _dialogShowing = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.headset_mic, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'طلب من الكول سنتر',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price
            if (ride.estimatedPrice != null && ride.estimatedPrice! > 0)
              ListTile(
                leading: const Icon(Icons.payments, color: Colors.green),
                title: Text(
                  '${ride.estimatedPrice!.toStringAsFixed(0)} ETB',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('سعر المنصة — غير قابل للتفاوض',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              )
            else
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.orange),
                title: const Text('يُحسب لاحقاً',
                    style: TextStyle(fontFamily: 'Cairo')),
                subtitle: const Text('السعر يُحدد عند الإنهاء',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: Text(ride.pickupAddress,
                  style: const TextStyle(fontFamily: 'Cairo')),
              subtitle: const Text('موقع الراكب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            ),
            if (ride.dropoffAddress.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.blue),
                title: Text(ride.dropoffAddress,
                    style: const TextStyle(fontFamily: 'Cairo')),
                subtitle: const Text('الوجهة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              ),
            if (ride.passengerPhone != null)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: Text(ride.passengerPhone!,
                    style: const TextStyle(fontFamily: 'Cairo')),
                subtitle: const Text('هاتف الراكب',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تجاهل',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('قبول الرحلة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
    _dialogShowing = false;
    if (confirmed == true && mounted) {
      context.go('/ride/${ride.id}/navigate');
    } else if (confirmed == false) {
      ref.read(rideDatasourceProvider).declineCallCenterRide(ride.id);
    }
  }

  Future<void> _showAiCallRideDialog(
      BuildContext context, RideEntity ride) async {
    _dialogShowing = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text(
              'طلب من المساعد الصوتي',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price
            if (ride.estimatedPrice != null && ride.estimatedPrice! > 0)
              ListTile(
                leading: const Icon(Icons.payments, color: Colors.green),
                title: Text(
                  '${ride.estimatedPrice!.toStringAsFixed(0)} ETB',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('سعر المنصة — غير قابل للتفاوض',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              )
            else
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.orange),
                title: const Text('يُحسب لاحقاً',
                    style: TextStyle(fontFamily: 'Cairo')),
                subtitle: const Text('السعر يُحدد عند الإنهاء',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: Text(ride.pickupAddress,
                  style: const TextStyle(fontFamily: 'Cairo')),
              subtitle: const Text('موقع الراكب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            ),
            if (ride.dropoffAddress.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.blue),
                title: Text(ride.dropoffAddress,
                    style: const TextStyle(fontFamily: 'Cairo')),
                subtitle: const Text('الوجهة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              ),
            if (ride.passengerPhone != null)
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: Text(ride.passengerPhone!,
                    style: const TextStyle(fontFamily: 'Cairo')),
                subtitle: const Text('هاتف الراكب (اتصل للتأكيد)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تجاهل',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('قبول الرحلة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
    _dialogShowing = false;
    if (confirmed == true && mounted) {
      context.go('/ride/${ride.id}/navigate');
    } else if (confirmed == false) {
      ref.read(rideDatasourceProvider).declineCallCenterRide(ride.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(onlineStatusProvider);
    final driver = ref.watch(currentDriverProvider);
    final incomingRequests = ref.watch(incomingRequestsProvider);
    final currentRide = ref.watch(currentRideProvider);

    // Listen for incoming requests
    ref.listen(incomingRequestsProvider, (_, next) {
      next.whenData((requests) {
        _handleIncomingRequest(context, requests);
      });
    });

    // If we have an active ride, navigate to appropriate screen
    ref.listen(currentRideProvider, (_, next) {
      next.whenData((ride) {
        if (ride != null && mounted) {
          if (ride.isCallCenter &&
              (ride.isAccepted || ride.isDriverArrived) &&
              !_shownRequestIds.contains(ride.id)) {
            _shownRequestIds.add(ride.id);
            _showCallCenterRideDialog(context, ride);
          } else if (ride.isAiCall &&
              (ride.isAccepted || ride.isDriverArrived) &&
              !_shownRequestIds.contains(ride.id)) {
            _shownRequestIds.add(ride.id);
            _showAiCallRideDialog(context, ride);
          } else if (ride.isAccepted || ride.isDriverArrived) {
            if (!context.location.startsWith('/ride/')) {
              context.go('/ride/${ride.id}/navigate');
            }
          } else if (ride.isInProgress) {
            if (!context.location.startsWith('/ride/')) {
              context.go('/ride/${ride.id}/in-progress');
            }
          }
        }
      });
    });

    final markers = <Marker>{};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: LatLng(
              _currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isOnline
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: isOnline ? 'متصل' : 'غير متصل',
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'wedit',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'سائق',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: Colors.grey[700],
                onPressed: () => context.go('/home/notifications'),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen Google Map
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                  ),
                );
              }
            },
          ),

          // Bottom info card (visible when online)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomInfoCard(isOnline: isOnline),
          ),

          // Online/Offline FAB
          Positioned(
            bottom: isOnline ? 220 : 40,
            left: 0,
            right: 0,
            child: Center(
              child: _OnlineToggleFAB(
                isOnline: isOnline,
                onToggle: _toggleOnlineStatus,
              ),
            ),
          ),

          // Location re-center button
          Positioned(
            bottom: isOnline ? 280 : 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              backgroundColor: Colors.white,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(
                      LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
                    ),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: Colors.grey),
            ),
          ),

          // Quick Ride (Street Hail) FAB
          Positioned(
            bottom: isOnline ? 340 : 160,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'street-hail',
              backgroundColor: AppTheme.primaryColor,
              onPressed: () => _startStreetHail(context),
              icon: const Icon(Icons.hail, color: Colors.white),
              label: const Text(
                'ركوب سريع',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Online Toggle FAB
// ---------------------------------------------------------------------------
class _OnlineToggleFAB extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onToggle;

  const _OnlineToggleFAB({
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOnline ? AppTheme.onlineColor : AppTheme.offlineColor,
          boxShadow: [
            BoxShadow(
              color: (isOnline ? AppTheme.onlineColor : AppTheme.offlineColor)
                  .withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(height: 4),
            Text(
              isOnline ? 'متصل' : 'غير متصل',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Info Card
// ---------------------------------------------------------------------------
class _BottomInfoCard extends ConsumerWidget {
  final bool isOnline;

  const _BottomInfoCard({required this.isOnline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isOnline) return const SizedBox.shrink();

    final driver = ref.watch(currentDriverProvider);
    final currentRide = ref.watch(currentRideProvider);

    final hasSubscription = driver.value?.hasActiveSubscription ?? false;
    final activeRideCount =
        currentRide.value != null ? 1 : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Surge toggle
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SurgeToggleCard(),
          ),

          const SizedBox(height: 8),

          // Leaderboard mini widget
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const LeaderboardHomeWidget(),
          ),

          const Divider(height: 24),

          // Stats row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatTile(
                  label: 'أرباح اليوم',
                  value: '0 ب',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _StatTile(
                  label: 'الاشتراك',
                  value: hasSubscription ? 'نشط' : 'منتهي',
                  icon: Icons.card_membership_outlined,
                  valueColor:
                      hasSubscription ? Colors.green : Colors.red,
                ),
                _StatTile(
                  label: 'الرحلات النشطة',
                  value: '$activeRideCount',
                  icon: Icons.directions_car_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: valueColor ?? Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

// Extension for GoRouter location
extension GoRouterLocation on BuildContext {
  String get location {
    final router = GoRouter.of(this);
    return router.routerDelegate.currentConfiguration.uri.toString();
  }
}
