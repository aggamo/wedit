import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ride_entity.dart';
import '../providers/ride_provider.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String rideId;

  const TrackingScreen({super.key, required this.rideId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  static const _initialPosition = CameraPosition(
    target: LatLng(AppConstants.addisAbabaLat, AppConstants.addisAbabaLng),
    zoom: 14,
  );

  void _updateMapFromRide(RideEntity ride) {
    final pickupLatLng = LatLng(ride.pickupLat, ride.pickupLng);
    final destLatLng =
        LatLng(ride.destinationLat, ride.destinationLng);

    setState(() {
      _markers
        ..clear()
        ..addAll([
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickupLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'نقطة الانطلاق'),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: destLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: ride.destinationAddress),
          ),
        ]);

      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [pickupLatLng, destLatLng],
            color: AppColors.primary,
            width: 4,
          ),
        );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            ride.pickupLat < ride.destinationLat
                ? ride.pickupLat
                : ride.destinationLat,
            ride.pickupLng < ride.destinationLng
                ? ride.pickupLng
                : ride.destinationLng,
          ),
          northeast: LatLng(
            ride.pickupLat > ride.destinationLat
                ? ride.pickupLat
                : ride.destinationLat,
            ride.pickupLng > ride.destinationLng
                ? ride.pickupLng
                : ride.destinationLng,
          ),
        ),
        80,
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'accepted':
        return 'السائق في طريقه';
      case 'arriving':
        return 'وصل السائق';
      case 'started':
        return 'الرحلة جارية';
      case 'completed':
        return 'وصلت بأمان!';
      default:
        return 'جاري التتبع...';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.statusAccepted;
      case 'arriving':
        return AppColors.statusPending;
      case 'started':
        return AppColors.statusStarted;
      case 'completed':
        return AppColors.statusCompleted;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _callDriver(String? phone) async {
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rideAsync = ref.watch(currentRideProvider(widget.rideId));

    // Listen for ride completion
    ref.listen(currentRideProvider(widget.rideId), (_, next) {
      next.whenData((ride) {
        if (ride.isCompleted && mounted) {
          context.go('/ride/${widget.rideId}/completed');
        }
        _updateMapFromRide(ride);
      });
    });

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          // Bottom tracking panel
          DraggableScrollableSheet(
            minChildSize: 0.22,
            initialChildSize: 0.35,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: rideAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (ride) => ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _statusColor(ride.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              ride.isStarted
                                  ? Icons.directions_car
                                  : Icons.access_time,
                              color: _statusColor(ride.status),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusText(ride.status),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _statusColor(ride.status),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (ride.isStarted) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.navigation,
                                  color: AppColors.secondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'مسار إلى ${ride.destinationAddress}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Driver info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.person,
                                color: AppColors.primary, size: 30),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سائقك',
                                  style: theme.textTheme.titleSmall,
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 14,
                                        color: AppColors.tertiary),
                                    const SizedBox(width: 4),
                                    const Text('4.8'),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ETA: ~${ride.durationMinutes ?? 5} د',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Call driver button
                          IconButton(
                            onPressed: () => _callDriver(null),
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.phone,
                                  color: Colors.white, size: 20),
                            ),
                            tooltip: 'اتصل بالسائق',
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Route info
                      _RouteInfoTile(
                        fromAddress: ride.pickupAddress,
                        toAddress: ride.destinationAddress,
                      ),

                      const SizedBox(height: 16),

                      // Cancel ride (only if not started)
                      if (!ride.isStarted && !ride.isCompleted)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final notifier =
                                ref.read(rideStateProvider.notifier);
                            final ok = await notifier.cancelRide(
                              widget.rideId,
                              'إلغاء من قِبل الراكب',
                            );
                            if (ok && mounted) context.go('/home');
                          },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('إلغاء الرحلة'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RouteInfoTile extends StatelessWidget {
  final String fromAddress;
  final String toAddress;

  const _RouteInfoTile({
    required this.fromAddress,
    required this.toAddress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.radio_button_on,
                  color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fromAddress,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: Row(
              children: [
                Container(
                  width: 1,
                  height: 16,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toAddress,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
