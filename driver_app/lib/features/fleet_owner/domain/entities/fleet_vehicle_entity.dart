class FleetVehicleEntity {
  final String id;
  final String fleetOwnerId;
  final String plateNumber;
  final String? model;
  final String? color;
  final int? year;
  final String? photoUrl;
  final String vehicleType;
  final bool isCarActive;
  final DateTime createdAt;

  const FleetVehicleEntity({
    required this.id,
    required this.fleetOwnerId,
    required this.plateNumber,
    this.model,
    this.color,
    this.year,
    this.photoUrl,
    this.vehicleType = 'sedan',
    this.isCarActive = true,
    required this.createdAt,
  });

  FleetVehicleEntity copyWith({
    String? id,
    String? fleetOwnerId,
    String? plateNumber,
    String? model,
    String? color,
    int? year,
    String? photoUrl,
    String? vehicleType,
    bool? isCarActive,
    DateTime? createdAt,
  }) {
    return FleetVehicleEntity(
      id: id ?? this.id,
      fleetOwnerId: fleetOwnerId ?? this.fleetOwnerId,
      plateNumber: plateNumber ?? this.plateNumber,
      model: model ?? this.model,
      color: color ?? this.color,
      year: year ?? this.year,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      isCarActive: isCarActive ?? this.isCarActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
