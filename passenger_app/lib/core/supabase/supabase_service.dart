import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService _instance = SupabaseService._();
  static SupabaseService get instance => _instance;

  SupabaseClient get client => Supabase.instance.client;

  // Auth helpers
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => client.auth.currentUser?.id;
  bool get isAuthenticated => client.auth.currentUser != null;

  Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  // Database table references
  SupabaseQueryBuilder get profilesTable => client.from('profiles');
  SupabaseQueryBuilder get ridesTable => client.from('rides');
  SupabaseQueryBuilder get rideOffersTable => client.from('ride_offers');
  SupabaseQueryBuilder get driverLocationsTable => client.from('driver_locations');
  SupabaseQueryBuilder get notificationsTable => client.from('notifications');
  SupabaseQueryBuilder get pointsTransactionsTable => client.from('points_transactions');
  SupabaseQueryBuilder get referralsTable => client.from('referrals');

  // Realtime channel helpers
  RealtimeChannel driverLocationChannel(String rideId) {
    return client.channel('driver_location_$rideId');
  }

  RealtimeChannel rideStatusChannel(String rideId) {
    return client.channel('ride_status_$rideId');
  }

  RealtimeChannel rideOffersChannel(String rideId) {
    return client.channel('ride_offers_$rideId');
  }

  // Storage
  StorageFileApi get avatarsStorage => client.storage.from('avatars');

  /// Upload a file and get its public URL
  Future<String> uploadAvatar(String userId, List<int> bytes, String extension) async {
    final path = '$userId/avatar.$extension';
    await avatarsStorage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: 'image/$extension',
        upsert: true,
      ),
    );
    return avatarsStorage.getPublicUrl(path);
  }

  /// Get a user profile by ID
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await profilesTable
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  /// Update a user profile
  Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final response = await profilesTable
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId)
        .select()
        .single();
    return response;
  }

  /// Get user's active ride
  Future<Map<String, dynamic>?> getActiveRide(String passengerId) async {
    final response = await ridesTable
        .select()
        .eq('passenger_id', passengerId)
        .inFilter('status', ['pending', 'accepted', 'arriving', 'started'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  }
}
