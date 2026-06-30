import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../domain/entities/driver_location_entity.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_offer_entity.dart';
import '../../domain/repositories/ride_repository.dart';
import '../datasources/ride_remote_datasource.dart';

class RideRepositoryImpl implements RideRepository {
  final RideRemoteDatasource _datasource;

  const RideRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, RideEntity>> requestRide(
      RequestRideParams params) async {
    try {
      final ride = await _datasource.requestRide(
        pickupLat: params.pickupLat,
        pickupLng: params.pickupLng,
        pickupAddress: params.pickupAddress,
        dropoffLat: params.destinationLat,
        dropoffLng: params.destinationLng,
        dropoffAddress: params.destinationAddress,
        vehicleType: params.vehicleType,
      );
      return Right(ride);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<RideOfferEntity>> getRideOffers(String rideId) {
    return _datasource.streamRideOffers(rideId);
  }

  @override
  Future<Either<Failure, RideEntity>> acceptOffer(String offerId) async {
    try {
      final ride = await _datasource.acceptOffer(offerId);
      return Right(ride);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<RideEntity> getRideStatus(String rideId) {
    return _datasource.streamRideStatus(rideId);
  }

  @override
  Future<Either<Failure, void>> cancelRide(
      String rideId, String reason) async {
    try {
      await _datasource.cancelRide(rideId, reason);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> rateRide({
    required String rideId,
    required int score,
    String? comment,
  }) async {
    try {
      await _datasource.submitRating(
        rideId: rideId,
        score: score,
        comment: comment,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<DriverLocationEntity>> getNearbyDrivers({
    required double lat,
    required double lng,
    String? vehicleType,
  }) {
    return _datasource.streamNearbyDrivers();
  }

  @override
  Future<Either<Failure, List<RideEntity>>> getRideHistory() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        return const Left(AuthFailure(message: 'User not authenticated'));
      }
      final rides = await _datasource.getRideHistory(userId);
      return Right(rides);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getEstimatedPrice({
    required double distanceKm,
    required String vehicleType,
  }) async {
    try {
      final price = await _datasource.getEstimatedPrice(
        distanceKm: distanceKm,
        vehicleType: vehicleType,
      );
      return Right(price);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, RideEntity>> getRideById(String rideId) async {
    try {
      final ride = await _datasource.getRideById(rideId);
      return Right(ride);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
