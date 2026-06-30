import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/send_otp.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/update_profile.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/ride/data/datasources/ride_remote_datasource.dart';
import '../../features/ride/data/repositories/ride_repository_impl.dart';
import '../../features/ride/domain/repositories/ride_repository.dart';
import '../supabase/supabase_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // External dependencies
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // Core services
  getIt.registerSingleton<SupabaseService>(SupabaseService.instance);

  // Auth feature
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasourceImpl(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<AuthRemoteDatasource>()),
  );

  getIt.registerLazySingleton<SendOtp>(
    () => SendOtp(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<VerifyOtp>(
    () => VerifyOtp(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<SignOut>(
    () => SignOut(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<GetCurrentUser>(
    () => GetCurrentUser(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<UpdateProfile>(
    () => UpdateProfile(getIt<AuthRepository>()),
  );

  // Ride feature
  getIt.registerLazySingleton<RideRemoteDatasource>(
    () => RideRemoteDatasourceImpl(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<RideRepository>(
    () => RideRepositoryImpl(getIt<RideRemoteDatasource>()),
  );
}
