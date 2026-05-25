import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class SendOtpUsecase {
  final AuthRepository _repository;
  SendOtpUsecase(this._repository);

  Future<Either<Failure, void>> call(String phone) {
    if (phone.isEmpty) {
      return Future.value(const Left(ValidationFailure('Phone number is required')));
    }
    return _repository.sendOtp(phone);
  }
}
