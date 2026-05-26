import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';
import '../widgets/vehicle_type_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  String _selectedVehicleType = 'sedan';
  Set<Marker> _markers = {};

  static const _initialPosition = CameraPosition(
    target: LatLng(AppConstants.addisAbabaLat, AppConstants.addisAbabaLng),
    zoom: AppConstants.defaultZoom,
  );

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  Future<void> _centerOnUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (_) {}
  }

  void _updateDriverMarkers(List<dynamic> drivers) {
    final newMarkers = <Marker>{};
    for (final driver in drivers) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('driver_${driver.driverId}'),
          position: LatLng(driver.lat, driver.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: 'سائق',
            snippet: driver.vehicleType ?? '',
          ),
        ),
      );
    }
    if (mounted) {
      setState(() => _markers = newMarkers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch nearby drivers and update markers
    ref.listen(nearbyDriversProvider, (_, next) {
      next.whenData(_updateDriverMarkers);
    });

    return Scaffold(
      body: Stack(
        children: [
          // Full screen Google Map
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Transparent AppBar
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'wedit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  // Notification bell
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => context.go(AppRoutes.notifications),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User location FAB
          Positioned(
            bottom: 220,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location_fab',
              onPressed: _centerOnUserLocation,
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            minChildSize: 0.15,
            initialChildSize: 0.35,
            maxChildSize: 0.75,
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
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Search bar (tap target)
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.destination),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.textDisabled, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: AppColors.textHint),
                            const SizedBox(width: 12),
                            Text(
                              'إلى أين؟',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Vehicle type label
                    Text(
                      'اختر نوع السيارة',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),

                    // Vehicle type cards (horizontal scrollable)
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: AppConstants.vehicleTypes.map((vt) {
                          return VehicleTypeCard(
                            vehicleType: vt,
                            isSelected: _selectedVehicleType == vt,
                            estimatedPrice: _basePrice(vt),
                            onTap: () =>
                                setState(() => _selectedVehicleType = vt),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Disclaimer
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'أرخص ما يوفر منه سائق',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  double _basePrice(String vehicleType) {
    switch (vehicleType) {
      case 'suv':
        return AppConstants.basefareSuv;
      case 'vip':
        return AppConstants.baseFareVip;
      case 'minibus':
        return AppConstants.baseFareMinibus;
      default:
        return AppConstants.baseFareSedan;
    }
  }
}
