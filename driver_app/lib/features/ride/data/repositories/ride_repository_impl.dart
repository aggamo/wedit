import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/earnings_entity.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_request_entity.dart';
import '../../domain/repositories/ride_repository.dart';
import '../datasources/ride_remote_datasource.dart';

class RideRepositoryImpl implements RideRepository {
  final RideRemoteDatasource _datasource;
  final SupabaseClient _supabase;

  RideRepositoryImpl(this._datasource, this._supabase);

  String get _driverId => _supabase.auth.currentUser?.id ?? '';

  @override
  Stream<List<RideRequestEntity>> streamIncomingRequests() {
    return _datasource.streamIncomingRequests(_driverId);
  }

  @override
  Stream<RideEntity?> streamCurrentRide() {
    return _datasource.streamCurrentRide(_driverId);
  }

  @override
  Future<Either<Failure, void>> submitOffer(
      String rideId, double price,
      {bool isSystemPrice = false, bool isSurgeOffer = false}) async {
    try {
      await _datasource.submitOffer(
          rideId, _driverId, price, isSystemPrice, isSurgeOffer);
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleSurge(bool enabled) async {
    try {
      await _datasource.toggleSurge(_driverId, enabled);
      return const Right(null);
    } catch (e) {
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, void>> declineRequest(String rideId) async {
    try {
      await _datasource.declineRequest(rideId, _driverId);
      return const Right(null);
    } catch (e) {
      return const Right(null); // Non-critical
    }
  }

  @override
  Future<Either<Failure, void>> updateLocation(
      double lat, double lng, double heading) async {
    try {
      await _datasource.updateLocation(_driverId, lat, lng, heading);
      return const Right(null);
    } catch (e) {
      return const Right(null); // Non-critical
    }
  }

  @override
  Future<Either<Failure, void>> markArrived(String rideId) async {
    try {
      await _datasource.markArrived(rideId, _driverId);
      return const Right(null);
    } on RideFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(RideFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> startRide(String rideId) async {
    try {
      await _datasource.startRide(rideId, _driverId);
      return const Right(null);
    } on RideFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(RideFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> completeRide(String rideId) async {
    try {
      await _datasource.completeRide(rideId, _driverId);
      return const Right(null);
    } on RideFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(RideFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setOnlineStatus(bool isOnline) async {
    try {
      await _datasource.setOnlineStatus(_driverId, isOnline);
      return const Right(null);
    } catch (e) {
      return const Right(null); // Non-critical
    }
  }

  @override
  Future<Either<Failure, EarningsEntity>> getEarnings(String period) async {
    try {
      final result = await _datasource.getEarnings(_driverId, period);
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RideEntity>> startStreetHailRide({
    required String passengerPhone,
    required String vehicleType,
    required double startLat,
    required double startLng,
    String? destination,
  }) async {
    try {
      final ride = await _datasource.startStreetHailRide(
        driverId: _driverId,
        passengerPhone: passengerPhone,
        vehicleType: vehicleType,
        startLat: startLat,
        startLng: startLng,
        destination: destination,
      );
      return Right(ride);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> endStreetHailRide({
    required String rideId,
    required double endLat,
    required double endLng,
    required double distanceKm,
    required double durationMinutes,
  }) async {
    try {
      final fare = await _datasource.endStreetHailRide(
        rideId: rideId,
        driverId: _driverId,
        endLat: endLat,
        endLng: endLng,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      );
      return Right(fare);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
