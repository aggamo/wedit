import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Send OTP to phone number
  Future<Either<Failure, void>> sendOtp(String phone);

  /// Verify OTP and return user entity
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String phone,
    required String token,
  });

  /// Sign out current user
  Future<Either<Failure, void>> signOut();

  /// Get current authenticated user
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// Update user profile
  Future<Either<Failure, UserEntity>> updateProfile(UserEntity user);

  /// Stream of auth state changes
  Stream<UserEntity?> streamAuthState();
}
