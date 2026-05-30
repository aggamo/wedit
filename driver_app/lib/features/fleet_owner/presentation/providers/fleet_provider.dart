import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/fleet_repository_impl.dart';
import '../../domain/entities/fleet_assignment_entity.dart';
import '../../domain/entities/fleet_settlement_entity.dart';
import '../../domain/entities/fleet_vehicle_entity.dart';

final fleetRepositoryProvider = Provider<FleetRepository>((ref) {
  return FleetRepository(Supabase.instance.client);
});

final fleetVehiclesProvider =
    FutureProvider.family<List<FleetVehicleEntity>, String>((ref, ownerId) {
  return ref.read(fleetRepositoryProvider).getVehicles(ownerId);
});

final fleetAssignmentsProvider =
    FutureProvider.family<List<FleetAssignmentEntity>, String>((ref, ownerId) {
  return ref.read(fleetRepositoryProvider).getAssignments(ownerId);
});

final fleetSettlementsProvider =
    FutureProvider.family<List<FleetSettlementEntity>, String>((ref, ownerId) {
  return ref.read(fleetRepositoryProvider).getSettlements(ownerId);
});

final fleetDashboardProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, ownerId) {
  return ref.read(fleetRepositoryProvider).getDashboardStats(ownerId);
});

// Live driver locations for fleet tracking
final fleetDriverLocationsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, List<String>>(
        (ref, driverIds) {
  if (driverIds.isEmpty) return const Stream.empty();
  return Supabase.instance.client
      .from('driver_locations')
      .stream(primaryKey: ['driver_id'])
      .inFilter('driver_id', driverIds)
      .map((data) => data.where((d) => d['is_online'] == true).toList());
});
