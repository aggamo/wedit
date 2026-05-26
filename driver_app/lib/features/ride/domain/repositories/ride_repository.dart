import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ride_entity.dart';
import '../entities/ride_request_entity.dart';
import '../entities/earnings_entity.dart';

abstract class RideRepository {
  Stream<List<RideRequestEntity>> streamIncomingRequests();
  Stream<RideEntity?> streamCurrentRide();
  Future<Either<Failure, void>> submitOffer(
      String rideId, double price, {bool isSystemPrice = false});
  Future<Either<Failure, void>> declineRequest(String rideId);
  Future<Either<Failure, void>> updateLocation(
      double lat, double lng, double heading);
  Future<Either<Failure, void>> markArrived(String rideId);
  Future<Either<Failure, void>> startRide(String rideId);
  Future<Either<Failure, void>> completeRide(String rideId);
  Future<Either<Failure, void>> setOnlineStatus(bool isOnline);
  Future<Either<Failure, EarningsEntity>> getEarnings(String period);
}
