import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpParams {
  final String phone;
  final String token;

  const VerifyOtpParams({required this.phone, required this.token});
}

class VerifyOtp {
  final AuthRepository _repository;

  const VerifyOtp(this._repository);

  Future<Either<Failure, UserEntity>> call(VerifyOtpParams params) {
    return _repository.verifyOtp(
      phone: params.phone,
      token: params.token,
    );
  }
}
