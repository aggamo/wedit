import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/driver_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

part 'auth_provider.g.dart';

// Supabase client provider
@riverpod
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

// Auth state from Supabase
@riverpod
Stream<AuthState> authState(Ref ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
}

// Remote datasource
@riverpod
AuthRemoteDatasource authRemoteDatasource(Ref ref) {
  return AuthRemoteDatasourceImpl(ref.watch(supabaseClientProvider));
}

// Repository
@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDatasourceProvider));
}

// Use cases
@riverpod
SendOtpUsecase sendOtpUsecase(Ref ref) {
  return SendOtpUsecase(ref.watch(authRepositoryProvider));
}

@riverpod
VerifyOtpUsecase verifyOtpUsecase(Ref ref) {
  return VerifyOtpUsecase(ref.watch(authRepositoryProvider));
}

// Current driver profile
@riverpod
Future<DriverEntity?> currentDriver(Ref ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final result = await repo.getCurrentDriver();
  return result.fold((_) => null, (driver) => driver);
}

// Auth state notifier for OTP flow
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final SendOtpUsecase _sendOtp;
  final VerifyOtpUsecase _verifyOtp;

  AuthNotifier(this._sendOtp, this._verifyOtp) : super(const AsyncValue.data(null));

  Future<bool> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    final result = await _sendOtp(phone);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<DriverEntity?> verifyOtp(String phone, String otp) async {
    state = const AsyncValue.loading();
    final result = await _verifyOtp(phone, otp);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (driver) {
        state = const AsyncValue.data(null);
        return driver;
      },
    );
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

@riverpod
AuthNotifier authNotifier(Ref ref) {
  return AuthNotifier(
    ref.watch(sendOtpUsecaseProvider),
    ref.watch(verifyOtpUsecaseProvider),
  );
}
