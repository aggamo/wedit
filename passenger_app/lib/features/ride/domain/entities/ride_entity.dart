import 'package:equatable/equatable.dart';

class RideEntity extends Equatable {
  final String id;
  final String passengerId;
  final String? driverId;
  final String? acceptedOfferId;
  final String vehicleType;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;
  final String status;
  final double? offeredPrice;
  final double? finalPrice;
  final String? paymentMethod;
  final bool isPaid;
  final int? distanceKm;
  final int? durationMinutes;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int? passengerRating;
  final String? passengerComment;

  const RideEntity({
    required this.id,
    required this.passengerId,
    this.driverId,
    this.acceptedOfferId,
    required this.vehicleType,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    required this.status,
    this.offeredPrice,
    this.finalPrice,
    this.paymentMethod,
    this.isPaid = false,
    this.distanceKm,
    this.durationMinutes,
    this.cancelReason,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.passengerRating,
    this.passengerComment,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isArriving => status == 'arriving';
  bool get isStarted => status == 'started';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive =>
      ['pending', 'accepted', 'arriving', 'started'].contains(status);

  String get displayStatus {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'arriving':
        return 'Driver Arriving';
      case 'started':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  RideEntity copyWith({
    String? id,
    String? passengerId,
    String? driverId,
    String? acceptedOfferId,
    String? vehicleType,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    double? destinationLat,
    double? destinationLng,
    String? destinationAddress,
    String? status,
    double? offeredPrice,
    double? finalPrice,
    String? paymentMethod,
    bool? isPaid,
    int? distanceKm,
    int? durationMinutes,
    String? cancelReason,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    int? passengerRating,
    String? passengerComment,
  }) {
    return RideEntity(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      acceptedOfferId: acceptedOfferId ?? this.acceptedOfferId,
      vehicleType: vehicleType ?? this.vehicleType,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      status: status ?? this.status,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      passengerRating: passengerRating ?? this.passengerRating,
      passengerComment: passengerComment ?? this.passengerComment,
    );
  }

  @override
  List<Object?> get props => [id, passengerId, driverId, status, vehicleType];
}
