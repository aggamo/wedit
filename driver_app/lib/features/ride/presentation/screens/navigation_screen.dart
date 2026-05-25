import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final String rideId;

  const NavigationScreen({super.key, required this.rideId});

  @override
  ConsumerState<NavigationScreen> createState() =>
      _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  Position? _driverPosition;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  bool _isArriving = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _driverPosition = position);
    } catch (_) {}
  }

  void _buildRoutePolyline(LatLng from, LatLng to) {
    final polyline = Polyline(
      polylineId: const PolylineId('route_to_pickup'),
      points: [from, to],
      color: Colors.blue,
      width: 4,
      patterns: [
        PatternItem.dash(20),
        PatternItem.gap(10),
      ],
    );
    setState(() {
      _polylines
        ..clear()
        ..add(polyline);
    });
  }

  Future<void> _markArrived(String rideId) async {
    setState(() => _isArriving = true);
    await ref.read(rideNotifierProvider.notifier).markArrived(rideId);
    if (mounted) {
      setState(() => _isArriving = false);
      context.go('/ride/$rideId/in-progress');
    }
  }

  void _cancelRide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الرحلة'),
        content: const Text('هل أنت متأكد من إلغاء الرحلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('إلغاء الرحلة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRide = ref.watch(currentRideProvider);
    final rideState = ref.watch(rideNotifierProvider);

    return currentRide.when(
      data: (ride) {
        if (ride == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('لا توجد رحلة نشطة'),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('العودة للرئيسية'),
                  ),
                ],
              ),
            ),
          );
        }

        final pickupLatLng = LatLng(ride.pickupLat, ride.pickupLng);
        final driverLatLng = _driverPosition != null
            ? LatLng(_driverPosition!.latitude, _driverPosition!.longitude)
            : null;

        // Build markers and polyline
        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickupLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'نقطة الانطلاق',
              snippet: ride.pickupAddress,
            ),
          ),
        };

        if (driverLatLng != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('driver'),
              position: driverLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'موقعك'),
            ),
          );
          _buildRoutePolyline(driverLatLng, pickupLatLng);
        }

        return Scaffold(
          body: Stack(
            children: [
              // Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pickupLatLng,
                  zoom: 14,
                ),
                markers: markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: pickupLatLng, zoom: 14),
                    ),
                  );
                },
              ),

              // Top header panel
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => context.go('/home'),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              Expanded(
                                child: Text(
                                  'التوجه لنقطة الانطلاق',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.location_on,
                            iconColor: AppTheme.onlineColor,
                            text: ride.pickupAddress.isEmpty
                                ? 'نقطة الانطلاق'
                                : ride.pickupAddress,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'الوصول المتوقع: ~5 دقائق',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${ride.agreedPrice.toStringAsFixed(0)} ب',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.onlineColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom action buttons
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Arrived FAB
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isArriving
                              ? null
                              : () => _markArrived(ride.id),
                          icon: _isArriving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isArriving ? 'جاري التحديث...' : 'وصلت!',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.onlineColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: _cancelRide,
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(e.toString()),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('العودة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
