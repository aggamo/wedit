import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../models/driver_model.dart';

abstract class AuthRemoteDatasource {
  Future<void> sendOtp(String phone);
  Future<DriverModel> verifyOtp(String phone, String otp);
  Future<DriverModel?> getCurrentDriver();
  Future<String?> getUserRole();
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

      // Check profile role first
      final profileData = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      final role = profileData?['role'] as String? ?? 'driver';

      if (role == 'fleet_owner') {
        return _getOrCreateFleetOwnerModel(userId, phone);
      }

      // Regular driver flow
      final driverData = await _supabase
          .from(AppConstants.driversTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (driverData != null) {
        return DriverModel.fromJson({...driverData, 'role': role});
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

      return DriverModel.fromJson({...created, 'role': role});
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

      // Get profile role
      final profileData = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = profileData?['role'] as String? ?? 'driver';

      if (role == 'fleet_owner') {
        return _getOrCreateFleetOwnerModel(user.id, user.phone ?? '');
      }

      final data = await _supabase
          .from(AppConstants.driversTable)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return DriverModel.fromJson({...data, 'role': role});
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final data = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return data?['role'] as String?;
    } catch (_) {
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

  Future<DriverModel> _getOrCreateFleetOwnerModel(
      String userId, String phone) async {
    // Get fleet owner subscription status
    final fleetData = await _supabase
        .from('fleet_owners')
        .select('subscription_expiry, is_active')
        .eq('id', userId)
        .maybeSingle();

    bool hasActiveSub = false;
    if (fleetData != null) {
      final expiry = fleetData['subscription_expiry'] as String?;
      if (expiry != null) {
        hasActiveSub = DateTime.parse(expiry).isAfter(DateTime.now());
      }
    }

    // Get profile name
    final profileData = await _supabase
        .from('profiles')
        .select('full_name, phone, avatar_url, referral_code, created_at')
        .eq('id', userId)
        .maybeSingle();

    return DriverModel(
      id: userId,
      phone: profileData?['phone'] as String? ?? phone,
      name: profileData?['full_name'] as String?,
      avatarUrl: profileData?['avatar_url'] as String?,
      referralCode: profileData?['referral_code'] as String?,
      status: 'active',
      role: 'fleet_owner',
      createdAt: profileData?['created_at'] != null
          ? DateTime.parse(profileData!['created_at'] as String)
          : DateTime.now(),
      hasActiveSubscription: hasActiveSub,
    );
  }

  String _generateReferralCode(String userId) {
    return 'WD${userId.substring(0, 6).toUpperCase()}';
  }
}
