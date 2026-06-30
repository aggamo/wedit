import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class RideInProgressScreen extends ConsumerStatefulWidget {
  final String rideId;

  const RideInProgressScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideInProgressScreen> createState() =>
      _RideInProgressScreenState();
}

class _RideInProgressScreenState
    extends ConsumerState<RideInProgressScreen> {
  GoogleMapController? _mapController;
  bool _isCompleting = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _completeRide(String rideId) async {
    setState(() => _isCompleting = true);
    await ref.read(rideNotifierProvider.notifier).completeRide(rideId);
    if (mounted) {
      setState(() => _isCompleting = false);
      context.go('/home');
    }
  }

  Future<void> _callPassenger(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('رقم الهاتف غير متاح')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showSOS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text('SOS - طوارئ'),
          ],
        ),
        content: const Text(
          'هل تحتاج مساعدة؟ سيتم إرسال موقعك لفريق الدعم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال طلب الطوارئ'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إرسال SOS',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _buildStars(double rating) {
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    final empty = 5 - full - (half ? 1 : 0);
    return ('★' * full) + (half ? '½' : '') + ('☆' * empty);
  }

  @override
  Widget build(BuildContext context) {
    final currentRide = ref.watch(currentRideProvider);

    return currentRide.when(
      data: (ride) {
        if (ride == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      size: 80, color: AppTheme.onlineColor),
                  const SizedBox(height: 16),
                  const Text(
                    'تمت الرحلة!',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('العودة للرئيسية'),
                  ),
                ],
              ),
            ),
          );
        }

        final destLatLng =
            LatLng(ride.dropoffLat, ride.dropoffLng);

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('destination'),
            position: destLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'الوجهة',
              snippet: ride.dropoffAddress,
            ),
          ),
        };

        return Scaffold(
          body: Stack(
            children: [
              // Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: destLatLng,
                  zoom: 14,
                ),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(
                      LatLngBounds(
                        southwest: LatLng(
                          ride.dropoffLat - 0.05,
                          ride.dropoffLng - 0.05,
                        ),
                        northeast: LatLng(
                          ride.dropoffLat + 0.05,
                          ride.dropoffLng + 0.05,
                        ),
                      ),
                      80,
                    ),
                  );
                },
              ),

              // Active ride badge at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppTheme.primaryColor.withOpacity(0.9),
                  child: SafeArea(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.circle,
                              color: Colors.greenAccent, size: 10),
                          const SizedBox(width: 8),
                          const Text(
                            'الرحلة جارية',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          // SOS button
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: _showSOS,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.emergency,
                                        color: Colors.white,
                                        size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'SOS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom passenger info card
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Passenger info row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                            child: const Icon(Icons.person, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ride.passengerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _buildStars(
                                          ride.passengerRating),
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${ride.passengerRating.toStringAsFixed(1)})',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Call button
                          ElevatedButton.icon(
                            onPressed: () =>
                                _callPassenger(ride.passengerPhone),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('اتصال'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.onlineColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Destination
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_on,
                                color: Colors.red, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الوجهة',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  ride.dropoffAddress.isEmpty
                                      ? 'الوجهة المحددة'
                                      : ride.dropoffAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${ride.agreedPrice.toStringAsFixed(0)} ب',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onlineColor,
                                ),
                              ),
                              const Text(
                                'السعر المتفق',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Complete ride button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCompleting
                              ? null
                              : () => _completeRide(ride.id),
                          icon: _isCompleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.flag),
                          label: Text(
                            _isCompleting ? 'جاري الإنهاء...' : 'وصلنا!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.onlineColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                          ),
                        ),
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
