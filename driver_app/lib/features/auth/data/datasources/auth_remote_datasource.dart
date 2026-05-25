import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../models/driver_model.dart';

abstract class AuthRemoteDatasource {
  Future<void> sendOtp(String phone);
  Future<DriverModel> verifyOtp(String phone, String otp);
  Future<DriverModel?> getCurrentDriver();
  Future<void> signOut();
  Future<void> updateFcmToken(String driverId, String token);
  Stream<DriverModel?> watchCurrentDriver(String driverId);
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final SupabaseClient _supabase;

  AuthRemoteDatasourceImpl(this._supabase);

  @override
  Future<void> sendOtp(String phone) async {
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
    } on AuthException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<DriverModel> verifyOtp(String phone, String otp) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      final userId = response.user?.id;
      if (userId == null) throw const AuthFailure('Authentication failed');

      // Try to get existing driver profile
      final driverData = await _supabase
          .from(AppConstants.driversTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (driverData != null) {
        return DriverModel.fromJson(driverData);
      }

      // Create new driver profile
      final newDriver = {
        'id': userId,
        'phone': phone,
        'status': 'pending',
        'rating': 5.0,
        'total_rides': 0,
        'referral_code': _generateReferralCode(userId),
        'created_at': DateTime.now().toIso8601String(),
      };

      final created = await _supabase
          .from(AppConstants.driversTable)
          .insert(newDriver)
          .select()
          .single();

      return DriverModel.fromJson(created);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is ServerFailure || e is AuthFailure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<DriverModel?> getCurrentDriver() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final data = await _supabase
          .from(AppConstants.driversTable)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return data != null ? DriverModel.fromJson(data) : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateFcmToken(String driverId, String token) async {
    try {
      await _supabase
          .from(AppConstants.driversTable)
          .update({'fcm_token': token})
          .eq('id', driverId);
    } catch (e) {
      // Non-critical, don't throw
    }
  }

  @override
  Stream<DriverModel?> watchCurrentDriver(String driverId) {
    return _supabase
        .from(AppConstants.driversTable)
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((data) => data.isEmpty ? null : DriverModel.fromJson(data.first));
  }

  String _generateReferralCode(String userId) {
    return 'WD${userId.substring(0, 6).toUpperCase()}';
  }
}
