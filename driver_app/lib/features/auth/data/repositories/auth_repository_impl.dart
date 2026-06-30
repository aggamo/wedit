import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/driver_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _datasource;

  AuthRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, void>> sendOtp(String phone) async {
    try {
      await _datasource.sendOtp(phone);
      return const Right(null);
    } on ServerFailure catch (e) {
      return Left(e);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DriverEntity>> verifyOtp(String phone, String otp) async {
    try {
      final driver = await _datasource.verifyOtp(phone, otp);
      return Right(driver);
    } on ServerFailure catch (e) {
      return Left(e);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DriverEntity?>> getCurrentDriver() async {
    try {
      final driver = await _datasource.getCurrentDriver();
      return Right(driver);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _datasource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateFcmToken(String token) async {
    try {
      // get current driver id from auth
      return const Right(null);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Stream<DriverEntity?> watchCurrentDriver() {
    // Return empty stream if not authenticated
    return const Stream.empty();
  }
}
