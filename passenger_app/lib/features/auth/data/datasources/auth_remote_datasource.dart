import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDatasource {
  Future<void> sendOtp(String phone);
  Future<UserModel> verifyOtp({required String phone, required String token});
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  Future<UserModel> updateProfile(UserModel user);
  Stream<UserModel?> streamAuthState();
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final SupabaseService _supabase;

  const AuthRemoteDatasourceImpl(this._supabase);

  @override
  Future<void> sendOtp(String phone) async {
    try {
      await _supabase.client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: true,
      );
    } on AuthException catch (e) {
      throw AuthException(message: e.message, code: e.statusCode);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> verifyOtp({
    required String phone,
    required String token,
  }) async {
    try {
      final response = await _supabase.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        throw const AuthException(message: 'Verification failed');
      }

      // Fetch or create profile
      final profile = await _getOrCreateProfile(supabaseUser);
      return profile;
    } on AuthException catch (e) {
      throw AuthException(message: e.message, code: e.statusCode);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  Future<UserModel> _getOrCreateProfile(User supabaseUser) async {
    try {
      // Try to get existing profile
      final existing = await _supabase.client
          .from('profiles')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (existing != null) {
        return UserModel.fromJson(existing);
      }

      // Create new profile
      final newProfile = {
        'id': supabaseUser.id,
        'phone': supabaseUser.phone ?? '',
        'role': 'passenger',
        'points': 0,
        'total_rides': 0,
        'is_active': true,
        'referral_code': _generateReferralCode(supabaseUser.id),
        'created_at': DateTime.now().toIso8601String(),
      };

      final created = await _supabase.client
          .from('profiles')
          .insert(newProfile)
          .select()
          .single();

      return UserModel.fromJson(created);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    }
  }

  String _generateReferralCode(String userId) {
    // Generate a 7-char alphanumeric code from user ID
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final hash = userId.hashCode.abs();
    var code = '';
    var n = hash;
    for (var i = 0; i < 7; i++) {
      code += chars[n % chars.length];
      n ~/= chars.length;
    }
    return code;
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final supabaseUser = _supabase.currentUser;
      if (supabaseUser == null) return null;

      final profile = await _supabase.client
          .from('profiles')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (profile == null) return null;
      return UserModel.fromJson(profile);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    try {
      final updated = await _supabase.client
          .from('profiles')
          .update(user.toUpdateJson())
          .eq('id', user.id)
          .select()
          .single();
      return UserModel.fromJson(updated);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, code: e.code);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<UserModel?> streamAuthState() {
    return _supabase.authStateStream.asyncMap((event) async {
      if (event.session?.user == null) return null;
      return getCurrentUser();
    });
  }
}
