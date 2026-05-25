import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PreferredDestinationScreen extends ConsumerStatefulWidget {
  const PreferredDestinationScreen({super.key});

  @override
  ConsumerState<PreferredDestinationScreen> createState() =>
      _PreferredDestinationScreenState();
}

class _PreferredDestinationScreenState
    extends ConsumerState<PreferredDestinationScreen> {
  GoogleMapController? _mapController;
  LatLng _centerPosition = const LatLng(
      AppConstants.defaultLat, AppConstants.defaultLng);
  double _radiusKm = 5.0;
  bool _isSaving = false;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
    zoom: 13,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _saveDestination() async {
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final driverId = supabase.auth.currentUser?.id;
      if (driverId == null) throw Exception('Not authenticated');

      await supabase.from(AppConstants.driversTable).update({
        'preferred_dest_lat': _centerPosition.latitude,
        'preferred_dest_lng': _centerPosition.longitude,
        'preferred_dest_radius_km': _radiusKm,
        'preferred_dest_enabled': true,
      }).eq('id', driverId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الوجهة المفضلة'),
            backgroundColor: AppTheme.onlineColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radiusMeters = _radiusKm * 1000;

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('preferred_area'),
        center: _centerPosition,
        radius: radiusMeters,
        fillColor: AppTheme.primaryColor.withOpacity(0.15),
        strokeColor: AppTheme.primaryColor.withOpacity(0.6),
        strokeWidth: 2,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('الوجهة المفضلة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            circles: circles,
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              setState(() {
                _centerPosition = position.target;
              });
            },
          ),

          // Fixed center pin (doesn't move with map)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Icon(
                    Icons.location_pin,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ),

          // Instruction text at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.primaryColor, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اسحب الخريطة لتحديد وجهتك المفضلة',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current location display
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_centerPosition.latitude.toStringAsFixed(4)}, '
                          '${_centerPosition.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Radius slider
                  Row(
                    children: [
                      const Icon(Icons.radar,
                          color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'نطاق الوجهة:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_radiusKm.toStringAsFixed(0)} كم',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '${_radiusKm.toStringAsFixed(0)} كم',
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      setState(() => _radiusKm = value);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveDestination,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving
                            ? 'جاري الحفظ...'
                            : 'حفظ الوجهة المفضلة',
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
  }
}
