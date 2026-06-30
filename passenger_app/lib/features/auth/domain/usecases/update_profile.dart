import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class UpdateProfile {
  final AuthRepository _repository;

  const UpdateProfile(this._repository);

  Future<Either<Failure, UserEntity>> call(UserEntity user) {
    return _repository.updateProfile(user);
  }
}
