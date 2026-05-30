import '../../domain/entities/fleet_assignment_entity.dart';

class FleetAssignmentModel extends FleetAssignmentEntity {
  const FleetAssignmentModel({
    required super.id,
    required super.fleetOwnerId,
    required super.fleetVehicleId,
    required super.driverId,
    super.driverName,
    super.driverPhone,
    super.driverRating,
    required super.revenueShareType,
    required super.revenueShareValue,
    super.maxDailyTrips,
    super.dailyTripsCount,
    super.settlementCycle,
    super.isActive,
    required super.createdAt,
  });

  factory FleetAssignmentModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final driver = json['drivers'] as Map<String, dynamic>?;
    return FleetAssignmentModel(
      id: json['id'] as String,
      fleetOwnerId: json['fleet_owner_id'] as String,
      fleetVehicleId: json['fleet_vehicle_id'] as String,
      driverId: json['driver_id'] as String,
      driverName: profile?['full_name'] as String? ?? '',
      driverPhone: profile?['phone'] as String? ?? '',
      driverRating: (driver?['rating'] as num?)?.toDouble() ?? 5.0,
      revenueShareType: json['revenue_share_type'] as String,
      revenueShareValue: json['revenue_share_value'] as int,
      maxDailyTrips: json['max_daily_trips'] as int?,
      dailyTripsCount: json['daily_trips_count'] as int? ?? 0,
      settlementCycle: json['settlement_cycle'] as String? ?? 'weekly',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
