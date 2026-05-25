import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/driver_location_entity.dart';
import '../entities/ride_entity.dart';
import '../entities/ride_offer_entity.dart';

class RequestRideParams {
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;
  final String vehicleType;
  final String? preferredPaymentMethod;

  const RequestRideParams({
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    required this.vehicleType,
    this.preferredPaymentMethod,
  });
}

abstract class RideRepository {
  /// Request a new ride
  Future<Either<Failure, RideEntity>> requestRide(RequestRideParams params);

  /// Stream of offers for a ride
  Stream<List<RideOfferEntity>> getRideOffers(String rideId);

  /// Accept a specific offer
  Future<Either<Failure, RideEntity>> acceptOffer(String offerId);

  /// Stream of ride status updates
  Stream<RideEntity> getRideStatus(String rideId);

  /// Cancel a ride
  Future<Either<Failure, void>> cancelRide(String rideId, String reason);

  /// Rate a ride
  Future<Either<Failure, void>> rateRide({
    required String rideId,
    required int score,
    String? comment,
  });

  /// Stream of nearby drivers
  Stream<List<DriverLocationEntity>> getNearbyDrivers({
    required double lat,
    required double lng,
    String? vehicleType,
  });

  /// Get ride history for current user
  Future<Either<Failure, List<RideEntity>>> getRideHistory();

  /// Get estimated price for a route
  Future<Either<Failure, double>> getEstimatedPrice({
    required double distanceKm,
    required String vehicleType,
  });

  /// Get a specific ride by ID
  Future<Either<Failure, RideEntity>> getRideById(String rideId);
}
