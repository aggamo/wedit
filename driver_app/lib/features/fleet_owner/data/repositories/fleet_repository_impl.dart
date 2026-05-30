import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/fleet_assignment_entity.dart';
import '../../domain/entities/fleet_settlement_entity.dart';
import '../../domain/entities/fleet_vehicle_entity.dart';
import '../models/fleet_assignment_model.dart';
import '../models/fleet_settlement_model.dart';
import '../models/fleet_vehicle_model.dart';

class FleetRepository {
  final SupabaseClient _supabase;

  FleetRepository(this._supabase);

  // ── Vehicles ──────────────────────────────────────────────────

  Future<List<FleetVehicleEntity>> getVehicles(String ownerId) async {
    final data = await _supabase
        .from('fleet_vehicles')
        .select()
        .eq('fleet_owner_id', ownerId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => FleetVehicleModel.fromJson(e)).toList();
  }

  Future<FleetVehicleEntity> addVehicle({
    required String ownerId,
    required String plateNumber,
    required String vehicleType,
    String? model,
    String? color,
    int? year,
    String? photoUrl,
  }) async {
    final data = await _supabase
        .from('fleet_vehicles')
        .insert({
          'fleet_owner_id': ownerId,
          'plate_number': plateNumber,
          'vehicle_type': vehicleType,
          'model': model,
          'color': color,
          'year': year,
          'photo_url': photoUrl,
        })
        .select()
        .single();
    return FleetVehicleModel.fromJson(data);
  }

  Future<void> updateVehicleActiveStatus(String vehicleId, bool isActive) async {
    await _supabase
        .from('fleet_vehicles')
        .update({'is_car_active': isActive})
        .eq('id', vehicleId);
  }

  // ── Assignments ───────────────────────────────────────────────

  Future<List<FleetAssignmentEntity>> getAssignments(String ownerId) async {
    final data = await _supabase
        .from('fleet_driver_assignments')
        .select('''
          *,
          profiles!driver_id(full_name, phone),
          drivers!driver_id(rating)
        ''')
        .eq('fleet_owner_id', ownerId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => FleetAssignmentModel.fromJson(e)).toList();
  }

  Future<void> updateAssignment({
    required String assignmentId,
    required String revenueShareType,
    required int revenueShareValue,
    required String settlementCycle,
    int? maxDailyTrips,
  }) async {
    await _supabase.from('fleet_driver_assignments').update({
      'revenue_share_type': revenueShareType,
      'revenue_share_value': revenueShareValue,
      'settlement_cycle': settlementCycle,
      'max_daily_trips': maxDailyTrips,
    }).eq('id', assignmentId);
  }

  Future<void> unlinkDriver(String assignmentId, String driverId) async {
    await _supabase
        .from('fleet_driver_assignments')
        .update({'is_active': false})
        .eq('id', assignmentId);

    await _supabase.from('drivers').update({
      'fleet_owner_id': null,
      'is_fleet_driver': false,
    }).eq('id', driverId);
  }

  Future<Map<String, dynamic>> inviteDriver({
    required String phone,
    required String fleetOwnerId,
    required String fleetVehicleId,
    required String revenueShareType,
    required int revenueShareValue,
    String settlementCycle = 'weekly',
    int? maxDailyTrips,
  }) async {
    final response = await _supabase.functions.invoke(
      'invite-fleet-driver',
      body: {
        'phone': phone,
        'fleet_owner_id': fleetOwnerId,
        'fleet_vehicle_id': fleetVehicleId,
        'revenue_share_type': revenueShareType,
        'revenue_share_value': revenueShareValue,
        'settlement_cycle': settlementCycle,
        'max_daily_trips': maxDailyTrips,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Settlements ───────────────────────────────────────────────

  Future<Map<String, double>> calculateSettlement({
    required String assignmentId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final data = await _supabase.rpc('calculate_fleet_settlement', params: {
      'p_assignment_id': assignmentId,
      'p_period_start': periodStart.toIso8601String(),
      'p_period_end': periodEnd.toIso8601String(),
    });
    final row = (data as List).first as Map<String, dynamic>;
    return {
      'total_fare': (row['total_fare'] as num).toDouble(),
      'owner_share': (row['owner_share'] as num).toDouble(),
      'driver_share': (row['driver_share'] as num).toDouble(),
    };
  }

  Future<List<FleetSettlementEntity>> getSettlements(String ownerId) async {
    final data = await _supabase
        .from('fleet_settlements')
        .select()
        .eq('fleet_owner_id', ownerId)
        .order('period_start', ascending: false);
    return (data as List).map((e) => FleetSettlementModel.fromJson(e)).toList();
  }

  Future<void> waiveSettlement(String settlementId) async {
    await _supabase
        .from('fleet_settlements')
        .update({'waived': true, 'owner_share': 0})
        .eq('id', settlementId);
  }

  Future<void> confirmSettlementReceipt(String settlementId) async {
    await _supabase
        .from('fleet_settlements')
        .update({'confirmed': true})
        .eq('id', settlementId);
  }

  Future<void> upsertSettlement({
    required String fleetOwnerId,
    required String assignmentId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double totalFare,
    required double ownerShare,
    required double driverShare,
  }) async {
    await _supabase.from('fleet_settlements').upsert({
      'fleet_owner_id': fleetOwnerId,
      'assignment_id': assignmentId,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'total_fare': totalFare,
      'owner_share': ownerShare,
      'driver_share': driverShare,
    });
  }

  // ── Dashboard stats ───────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats(String ownerId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final assignments = await _supabase
        .from('fleet_driver_assignments')
        .select('driver_id')
        .eq('fleet_owner_id', ownerId)
        .eq('is_active', true);

    final driverIds =
        (assignments as List).map((a) => a['driver_id'] as String).toList();

    int todayRides = 0;
    double todayFare = 0;
    double monthFare = 0;

    if (driverIds.isNotEmpty) {
      final todayRidesData = await _supabase
          .from('rides')
          .select('final_price')
          .inFilter('driver_id', driverIds)
          .eq('status', 'completed')
          .gte('completed_at', todayStart.toIso8601String());

      final monthRidesData = await _supabase
          .from('rides')
          .select('final_price')
          .inFilter('driver_id', driverIds)
          .eq('status', 'completed')
          .gte('completed_at', monthStart.toIso8601String());

      todayRides = (todayRidesData as List).length;
      todayFare = (todayRidesData).fold(
          0, (sum, r) => sum + ((r['final_price'] as num?)?.toDouble() ?? 0));
      monthFare = (monthRidesData as List).fold(
          0, (sum, r) => sum + ((r['final_price'] as num?)?.toDouble() ?? 0));
    }

    final vehicleCount = await _supabase
        .from('fleet_vehicles')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('fleet_owner_id', ownerId);

    return {
      'total_vehicles': vehicleCount.count ?? 0,
      'active_drivers': driverIds.length,
      'today_rides': todayRides,
      'today_fare': todayFare,
      'month_fare': monthFare,
    };
  }

  // ── Terms acceptance ─────────────────────────────────────────

  Future<bool> hasAcceptedTerms(String userId, String role,
      {String version = '1.0'}) async {
    final data = await _supabase
        .from('fleet_terms_acceptances')
        .select('id')
        .eq('user_id', userId)
        .eq('role', role)
        .eq('version', version)
        .maybeSingle();
    return data != null;
  }

  Future<void> acceptTerms(String userId, String role,
      {String version = '1.0'}) async {
    await _supabase.from('fleet_terms_acceptances').insert({
      'user_id': userId,
      'role': role,
      'version': version,
    });
  }
}
