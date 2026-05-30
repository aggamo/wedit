import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetLiveTrackingScreen extends ConsumerStatefulWidget {
  const FleetLiveTrackingScreen({super.key});

  @override
  ConsumerState<FleetLiveTrackingScreen> createState() =>
      _FleetLiveTrackingScreenState();
}

class _FleetLiveTrackingScreenState
    extends ConsumerState<FleetLiveTrackingScreen> {
  final ownerId = Supabase.instance.client.auth.currentUser!.id;
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(fleetAssignmentsProvider(ownerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع السائقين الحي'),
        automaticallyImplyLeading: false,
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (assignments) {
          final driverIds = assignments.map((a) => a.driverId).toList();
          return _MapView(
            driverIds: driverIds,
            assignments: assignments,
            onMapCreated: (ctrl) => _mapController = ctrl,
          );
        },
      ),
    );
  }
}

class _MapView extends ConsumerWidget {
  final List<String> driverIds;
  final List<dynamic> assignments;
  final void Function(GoogleMapController) onMapCreated;

  const _MapView({
    required this.driverIds,
    required this.assignments,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync =
        ref.watch(fleetDriverLocationsProvider(driverIds));

    return locationsAsync.when(
      loading: () => const GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(9.0249, 38.7469), // Addis Ababa
          zoom: 12,
        ),
      ),
      error: (e, _) => Center(child: Text('خطأ في التتبع: $e')),
      data: (locations) {
        final markers = <Marker>{};
        for (final loc in locations) {
          final driverId = loc['driver_id'] as String;
          final a = assignments.firstWhere(
            (a) => a.driverId == driverId,
            orElse: () => null,
          );
          final name = a != null
              ? (a.driverName.isEmpty ? a.driverPhone : a.driverName)
              : driverId;

          markers.add(
            Marker(
              markerId: MarkerId(driverId),
              position: LatLng(
                (loc['lat'] as num).toDouble(),
                (loc['lng'] as num).toDouble(),
              ),
              infoWindow: InfoWindow(
                title: name as String,
                snippet: 'آخر تحديث: ${_formatTime(loc['updated_at'])}',
              ),
            ),
          );
        }

        return GoogleMap(
          onMapCreated: onMapCreated,
          initialCameraPosition: const CameraPosition(
            target: LatLng(9.0249, 38.7469),
            zoom: 12,
          ),
          markers: markers,
        );
      },
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp.toString());
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}
