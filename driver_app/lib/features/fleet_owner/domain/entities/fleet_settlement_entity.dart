class FleetSettlementEntity {
  final String id;
  final String fleetOwnerId;
  final String assignmentId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalFare;
  final double ownerShare;
  final double driverShare;
  final bool waived;
  final String? receiptUrl;
  final bool confirmed;
  final DateTime createdAt;

  const FleetSettlementEntity({
    required this.id,
    required this.fleetOwnerId,
    required this.assignmentId,
    required this.periodStart,
    required this.periodEnd,
    this.totalFare = 0,
    this.ownerShare = 0,
    this.driverShare = 0,
    this.waived = false,
    this.receiptUrl,
    this.confirmed = false,
    required this.createdAt,
  });
}
