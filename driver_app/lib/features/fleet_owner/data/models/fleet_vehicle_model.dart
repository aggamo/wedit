import '../../domain/entities/fleet_vehicle_entity.dart';

class FleetVehicleModel extends FleetVehicleEntity {
  const FleetVehicleModel({
    required super.id,
    required super.fleetOwnerId,
    required super.plateNumber,
    super.model,
    super.color,
    super.year,
    super.photoUrl,
    super.vehicleType,
    super.isCarActive,
    required super.createdAt,
  });

  factory FleetVehicleModel.fromJson(Map<String, dynamic> json) {
    return FleetVehicleModel(
      id: json['id'] as String,
      fleetOwnerId: json['fleet_owner_id'] as String,
      plateNumber: json['plate_number'] as String,
      model: json['model'] as String?,
      color: json['color'] as String?,
      year: json['year'] as int?,
      photoUrl: json['photo_url'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'sedan',
      isCarActive: json['is_car_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'fleet_owner_id': fleetOwnerId,
        'plate_number': plateNumber,
        'model': model,
        'color': color,
        'year': year,
        'photo_url': photoUrl,
        'vehicle_type': vehicleType,
        'is_car_active': isCarActive,
      };
}
