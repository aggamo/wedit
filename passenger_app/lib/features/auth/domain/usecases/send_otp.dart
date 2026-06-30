import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class SendOtp {
  final AuthRepository _repository;

  const SendOtp(this._repository);

  Future<Either<Failure, void>> call(String phone) {
    return _repository.sendOtp(phone);
  }
}
