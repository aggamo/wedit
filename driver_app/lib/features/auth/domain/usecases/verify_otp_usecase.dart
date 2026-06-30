import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/driver_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUsecase {
  final AuthRepository _repository;
  VerifyOtpUsecase(this._repository);

  Future<Either<Failure, DriverEntity>> call(String phone, String otp) {
    if (otp.length < 6) {
      return Future.value(const Left(ValidationFailure('OTP must be 6 digits')));
    }
    return _repository.verifyOtp(phone, otp);
  }
}
