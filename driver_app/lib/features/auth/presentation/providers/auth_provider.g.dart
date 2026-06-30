// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supabaseClientHash() => r'supabaseClientHash';
String _$authStateHash() => r'authStateHash';
String _$authRemoteDatasourceHash() => r'authRemoteDatasourceHash';
String _$authRepositoryHash() => r'authRepositoryHash';
String _$sendOtpUsecaseHash() => r'sendOtpUsecaseHash';
String _$verifyOtpUsecaseHash() => r'verifyOtpUsecaseHash';
String _$currentDriverHash() => r'currentDriverHash';
String _$authNotifierHash() => r'authNotifierHash';

@ProviderFor(supabaseClient)
final supabaseClientProvider = AutoDisposeProvider<SupabaseClient>.internal(
  supabaseClient,
  name: r'supabaseClientProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$supabaseClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@ProviderFor(authState)
final authStateProvider = AutoDisposeStreamProvider<AuthState>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@ProviderFor(authRemoteDatasource)
final authRemoteDatasourceProvider = AutoDisposeProvider<AuthRemoteDatasource>.internal(
  authRemoteDatasource,
  name: r'authRemoteDatasourceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@ProviderFor(sendOtpUsecase)
final sendOtpUsecaseProvider = AutoDisposeProvider<SendOtpUsecase>.internal(
  sendOtpUsecase,
  name: r'sendOtpUsecaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sendOtpUsecaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@ProviderFor(verifyOtpUsecase)
final verifyOtpUsecaseProvider = AutoDisposeProvider<VerifyOtpUsecase>.internal(
  verifyOtpUsecase,
  name: r'verifyOtpUsecaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$verifyOtpUsecaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@ProviderFor(currentDriver)
final currentDriverProvider = AutoDisposeFutureProvider<DriverEntity?>.internal(
  currentDriver,
  name: r'currentDriverProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentDriverHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@ProviderFor(authNotifier)
final authNotifierProvider =
    AutoDisposeProvider<AuthNotifier>.internal(
  authNotifier,
  name: r'authNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);
