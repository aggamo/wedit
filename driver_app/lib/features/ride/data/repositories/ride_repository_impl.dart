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
      String rideId, double price) async {
    try {
      await _datasource.submitOffer(rideId, _driverId, price);
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
}
