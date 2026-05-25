import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/driver_registration_entity.dart';

abstract class RegistrationRemoteDatasource {
  Future<void> submitRegistration(DriverRegistrationEntity entity);
  Future<String> uploadDocument(File file, String type);
  Future<String> getRegistrationStatus();
}

class RegistrationRemoteDatasourceImpl implements RegistrationRemoteDatasource {
  final SupabaseClient _supabase;

  RegistrationRemoteDatasourceImpl(this._supabase);

  @override
  Future<void> submitRegistration(DriverRegistrationEntity entity) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AuthFailure('Not authenticated');

      // Update driver profile
      await _supabase
          .from(AppConstants.driversTable)
          .update({
            'name': entity.fullName,
            'status': 'pending',
          })
          .eq('id', userId);

      // Insert registration details
      await _supabase.from('driver_registrations').upsert({
        'driver_id': userId,
        ...entity.toRegistrationJson(),
        'submitted_at': DateTime.now().toIso8601String(),
      });
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> uploadDocument(File file, String type) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AuthFailure('Not authenticated');

      final extension = file.path.split('.').last;
      final fileName = '${userId}_${type}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = 'documents/$fileName';

      await _supabase.storage
          .from(AppConstants.documentsBucket)
          .upload(path, file);

      final url = _supabase.storage
          .from(AppConstants.documentsBucket)
          .getPublicUrl(path);

      return url;
    } on StorageException catch (e) {
      throw UploadFailure(e.message);
    } catch (e) {
      if (e is UploadFailure || e is AuthFailure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> getRegistrationStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AuthFailure('Not authenticated');

      final data = await _supabase
          .from(AppConstants.driversTable)
          .select('status')
          .eq('id', userId)
          .single();

      return data['status'] as String? ?? 'pending';
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
