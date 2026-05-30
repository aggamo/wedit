class FleetAssignmentEntity {
  final String id;
  final String fleetOwnerId;
  final String fleetVehicleId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final double driverRating;
  final String revenueShareType; // percentage | daily_rent | weekly_rent | monthly_rent
  final int revenueShareValue;
  final int? maxDailyTrips;
  final int dailyTripsCount;
  final String settlementCycle; // daily | weekly | monthly
  final bool isActive;
  final DateTime createdAt;

  const FleetAssignmentEntity({
    required this.id,
    required this.fleetOwnerId,
    required this.fleetVehicleId,
    required this.driverId,
    this.driverName = '',
    this.driverPhone = '',
    this.driverRating = 5.0,
    required this.revenueShareType,
    required this.revenueShareValue,
    this.maxDailyTrips,
    this.dailyTripsCount = 0,
    this.settlementCycle = 'weekly',
    this.isActive = true,
    required this.createdAt,
  });
}
