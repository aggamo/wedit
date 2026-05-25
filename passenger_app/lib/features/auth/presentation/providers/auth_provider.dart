import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/send_otp.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/verify_otp.dart';

part 'auth_provider.g.dart';

// Auth state stream
@riverpod
Stream<UserEntity?> authState(AuthStateRef ref) {
  final repository = getIt<AuthRepository>();
  return repository.streamAuthState();
}

// Expose AuthRepository
abstract class AuthRepository {
  Stream<UserEntity?> streamAuthState();
}

@riverpod
Future<UserEntity?> currentUser(CurrentUserRef ref) async {
  final useCase = getIt<GetCurrentUser>();
  final result = await useCase.call();
  return result.fold((_) => null, (user) => user);
}

// Auth controller for actions
@riverpod
class AuthController extends _$AuthController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> sendOtp(String phone) async {
    state = const AsyncLoading();
    final useCase = getIt<SendOtp>();
    final result = await useCase.call(phone);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  Future<UserEntity?> verifyOtp({
    required String phone,
    required String token,
  }) async {
    state = const AsyncLoading();
    final useCase = getIt<VerifyOtp>();
    final result = await useCase.call(
      VerifyOtpParams(phone: phone, token: token),
    );
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (user) {
        state = const AsyncData(null);
        return user;
      },
    );
  }

  Future<bool> signOut() async {
    state = const AsyncLoading();
    final useCase = getIt<SignOut>();
    final result = await useCase.call();
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  Future<UserEntity?> updateProfile(UserEntity user) async {
    state = const AsyncLoading();
    final useCase = getIt<UpdateProfile>();
    final result = await useCase.call(user);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (updated) {
        state = const AsyncData(null);
        return updated;
      },
    );
  }

  void clearError() {
    state = const AsyncData(null);
  }
}

// Provider to track the selected language
final selectedLanguageProvider = StateProvider<String>((ref) => 'ar');

// Onboarding shown provider
final onboardingShownProvider = StateProvider<bool>((ref) => false);
