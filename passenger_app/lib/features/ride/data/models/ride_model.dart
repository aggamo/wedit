import '../../domain/entities/ride_entity.dart';

class RideModel extends RideEntity {
  const RideModel({
    required super.id,
    required super.passengerId,
    super.driverId,
    super.acceptedOfferId,
    required super.vehicleType,
    required super.pickupLat,
    required super.pickupLng,
    required super.pickupAddress,
    required super.destinationLat,
    required super.destinationLng,
    required super.destinationAddress,
    required super.status,
    super.offeredPrice,
    super.finalPrice,
    super.paymentMethod,
    super.isPaid,
    super.distanceKm,
    super.durationMinutes,
    super.cancelReason,
    required super.createdAt,
    super.acceptedAt,
    super.startedAt,
    super.completedAt,
    super.cancelledAt,
    super.passengerRating,
    super.passengerComment,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as String,
      passengerId: json['passenger_id'] as String,
      driverId: json['driver_id'] as String?,
      acceptedOfferId: json['accepted_offer_id'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'sedan',
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLng: (json['pickup_lng'] as num).toDouble(),
      pickupAddress: json['pickup_address'] as String? ?? '',
      destinationLat: (json['destination_lat'] as num).toDouble(),
      destinationLng: (json['destination_lng'] as num).toDouble(),
      destinationAddress: json['destination_address'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      offeredPrice: (json['offered_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      distanceKm: (json['distance_km'] as num?)?.toInt(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      cancelReason: json['cancel_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'] as String)
          : null,
      passengerRating: (json['passenger_rating'] as num?)?.toInt(),
      passengerComment: json['passenger_comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'passenger_id': passengerId,
      'vehicle_type': vehicleType,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'destination_address': destinationAddress,
      'status': status,
      'payment_method': paymentMethod,
    };
  }
}
