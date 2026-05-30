import '../../domain/entities/fleet_settlement_entity.dart';

class FleetSettlementModel extends FleetSettlementEntity {
  const FleetSettlementModel({
    required super.id,
    required super.fleetOwnerId,
    required super.assignmentId,
    required super.periodStart,
    required super.periodEnd,
    super.totalFare,
    super.ownerShare,
    super.driverShare,
    super.waived,
    super.receiptUrl,
    super.confirmed,
    required super.createdAt,
  });

  factory FleetSettlementModel.fromJson(Map<String, dynamic> json) {
    return FleetSettlementModel(
      id: json['id'] as String,
      fleetOwnerId: json['fleet_owner_id'] as String,
      assignmentId: json['assignment_id'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      totalFare: (json['total_fare'] as num?)?.toDouble() ?? 0,
      ownerShare: (json['owner_share'] as num?)?.toDouble() ?? 0,
      driverShare: (json['driver_share'] as num?)?.toDouble() ?? 0,
      waived: json['waived'] as bool? ?? false,
      receiptUrl: json['receipt_url'] as String?,
      confirmed: json['confirmed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
