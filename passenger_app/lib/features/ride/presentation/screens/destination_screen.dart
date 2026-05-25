import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class _PopularPlace {
  final String name;
  final String subtitle;
  final double lat;
  final double lng;
  final IconData icon;

  const _PopularPlace({
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lng,
    required this.icon,
  });
}

const _popularPlaces = [
  _PopularPlace(
    name: 'مطار بولي الدولي',
    subtitle: 'بولي، أديس أبابا',
    lat: 8.9779,
    lng: 38.7993,
    icon: Icons.flight,
  ),
  _PopularPlace(
    name: 'ميدان المكسيك',
    subtitle: 'كرالو، أديس أبابا',
    lat: 9.0168,
    lng: 38.7524,
    icon: Icons.location_city,
  ),
  _PopularPlace(
    name: 'ميركاتو',
    subtitle: 'أديس كتيما، أديس أبابا',
    lat: 9.0354,
    lng: 38.7357,
    icon: Icons.store,
  ),
  _PopularPlace(
    name: 'بياتزا',
    subtitle: 'تكلي هيمانوت، أديس أبابا',
    lat: 9.0393,
    lng: 38.7484,
    icon: Icons.location_on,
  ),
  _PopularPlace(
    name: 'مسجد الأنوار',
    subtitle: 'أديس أبابا',
    lat: 9.0252,
    lng: 38.7469,
    icon: Icons.mosque,
  ),
  _PopularPlace(
    name: 'جامعة أديس أبابا',
    subtitle: 'الحرم الجامعي الرئيسي',
    lat: 9.0465,
    lng: 38.7612,
    icon: Icons.school,
  ),
  _PopularPlace(
    name: 'مستشفى بلاك ليون',
    subtitle: 'غولي، أديس أبابا',
    lat: 9.0427,
    lng: 38.7631,
    icon: Icons.local_hospital,
  ),
];

class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key});

  @override
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  final _searchController = TextEditingController();
  List<_PopularPlace> _filteredPlaces = _popularPlaces;
  String _selectedVehicleType = 'sedan';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPlaces = _popularPlaces
          .where((p) =>
              p.name.contains(query) || p.subtitle.toLowerCase().contains(query))
          .toList();
    });
  }

  void _onPlaceSelected(_PopularPlace place) {
    _showEstimateBottomSheet(place);
  }

  void _showEstimateBottomSheet(_PopularPlace destination) {
    final rnd = Random();
    final distanceKm = 2.0 + rnd.nextDouble() * 8.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EstimateSheet(
        destination: destination,
        distanceKm: distanceKm,
        selectedVehicleType: _selectedVehicleType,
        onVehicleTypeChanged: (vt) =>
            setState(() => _selectedVehicleType = vt),
        onRequestRide: () => _requestRide(destination, distanceKm),
      ),
    );
  }

  Future<void> _requestRide(_PopularPlace destination, double distanceKm) async {
    Navigator.pop(context); // close bottom sheet

    final rideNotifier = ref.read(rideStateProvider.notifier);
    final ride = await rideNotifier.requestRide(
      pickupLat: AppConstants.addisAbabaLat,
      pickupLng: AppConstants.addisAbabaLng,
      pickupAddress: 'موقعك الحالي',
      destinationLat: destination.lat,
      destinationLng: destination.lng,
      destinationAddress: destination.name,
      vehicleType: _selectedVehicleType,
    );

    if (ride != null && mounted) {
      context.go('/ride/${ride.id}/offers');
    } else {
      final error = ref.read(rideStateProvider).error;
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إلى أين؟'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن الوجهة...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filteredPlaces = _popularPlaces);
                        },
                      )
                    : null,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              children: [
                // Popular places
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Text(
                    'أماكن شائعة في أديس أبابا',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                ..._filteredPlaces.map(
                  (place) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Icon(place.icon,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(place.name,
                        style: theme.textTheme.bodyMedium),
                    subtitle: Text(place.subtitle,
                        style: theme.textTheme.bodySmall),
                    onTap: () => _onPlaceSelected(place),
                  ),
                ),

                const Divider(height: 24),

                // Recent destinations (empty state)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Text(
                    'الوجهات الأخيرة',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history,
                            size: 48, color: AppColors.textDisabled),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد وجهات سابقة',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateSheet extends ConsumerWidget {
  final _PopularPlace destination;
  final double distanceKm;
  final String selectedVehicleType;
  final ValueChanged<String> onVehicleTypeChanged;
  final VoidCallback onRequestRide;

  const _EstimateSheet({
    required this.destination,
    required this.distanceKm,
    required this.selectedVehicleType,
    required this.onVehicleTypeChanged,
    required this.onRequestRide,
  });

  double _estimate(String vt) {
    switch (vt) {
      case 'suv':
        return 75.0 + distanceKm * 18.0;
      case 'vip':
        return 120.0 + distanceKm * 25.0;
      case 'minibus':
        return 40.0 + distanceKm * 10.0;
      default:
        return 50.0 + distanceKm * 12.0;
    }
  }

  String _vehicleName(String vt) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rideState = ref.watch(rideStateProvider);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(destination.name,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'المسافة: ~${distanceKm.toStringAsFixed(1)} كم',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Vehicle type price list
            ...AppConstants.vehicleTypes.map((vt) {
              final isSelected = vt == selectedVehicleType;
              return GestureDetector(
                onTap: () => onVehicleTypeChanged(vt),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDisabled,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_vehicleName(vt),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          )),
                      const Spacer(),
                      Text(
                        '~${_estimate(vt).toStringAsFixed(0)} ب',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Request ride button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: rideState.isLoading ? null : onRequestRide,
                child: rideState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('اطلب رحلة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
