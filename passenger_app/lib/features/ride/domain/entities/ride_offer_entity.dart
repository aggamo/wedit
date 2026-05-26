import 'package:equatable/equatable.dart';

class RideOfferEntity extends Equatable {
  final String id;
  final String rideId;
  final String driverId;
  final String driverName;
  final double driverRating;
  final int driverTotalRides;
  final String? driverAvatarUrl;
  final String vehicleModel;
  final String vehiclePlate;
  final String vehicleColor;
  final String vehicleType;
  final double offeredPrice;
  final int etaMinutes;
  final double distanceToPickupKm;
  final DateTime expiresAt;
  final bool isExpired;
  final bool isSystemPrice;
  final String status; // pending, accepted, declined, expired

  const RideOfferEntity({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.driverName,
    required this.driverRating,
    this.driverTotalRides = 0,
    this.driverAvatarUrl,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.vehicleColor,
    required this.vehicleType,
    required this.offeredPrice,
    required this.etaMinutes,
    required this.distanceToPickupKm,
    required this.expiresAt,
    this.isExpired = false,
    this.isSystemPrice = false,
    this.status = 'pending',
  });

  bool get isActive =>
      status == 'pending' &&
      !isExpired &&
      expiresAt.isAfter(DateTime.now());

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get secondsRemaining => timeRemaining.inSeconds;

  @override
  List<Object?> get props => [
        id,
        rideId,
        driverId,
        offeredPrice,
        etaMinutes,
        status,
        isSystemPrice,
      ];
}
