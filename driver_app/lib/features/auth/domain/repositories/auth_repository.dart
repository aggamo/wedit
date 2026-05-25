import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/driver_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, void>> sendOtp(String phone);
  Future<Either<Failure, DriverEntity>> verifyOtp(String phone, String otp);
  Future<Either<Failure, DriverEntity?>> getCurrentDriver();
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, void>> updateFcmToken(String token);
  Stream<DriverEntity?> watchCurrentDriver();
}
