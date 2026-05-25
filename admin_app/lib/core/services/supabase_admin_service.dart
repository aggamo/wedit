import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminService {
  final SupabaseClient _client;

  SupabaseAdminService(this._client);

  // ─── Auth ───────────────────────────────────────────────
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await _client
          .from('admins')
          .select('id')
          .eq('user_id', user.id)
          .single();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  // ─── Drivers ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDrivers({
    String? status,
    String? search,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client.from('drivers').select(
        'id, full_name, phone_number, status, vehicle_type, created_at, profile_photo_url, '
        'national_id_number, license_number, rating_avg, total_rides');

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status) as dynamic;
    }
    if (search != null && search.isNotEmpty) {
      query = query.or('full_name.ilike.%$search%,phone_number.ilike.%$search%') as dynamic;
    }

    final res = await (query as PostgrestFilterBuilder)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> getDriverById(String id) async {
    final res = await _client
        .from('drivers')
        .select('*, driver_documents(*), driver_vehicles(*)')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> updateDriverStatus(String driverId, String status,
      {String? reason}) async {
    final updateData = <String, dynamic>{'status': status};
    if (reason != null) updateData['rejection_reason'] = reason;
    await _client.from('drivers').update(updateData).eq('id', driverId);
  }

  Future<void> approveDriverDocument(String docId, bool approved,
      {String? reason}) async {
    await _client.from('driver_documents').update({
      'status': approved ? 'approved' : 'rejected',
      if (reason != null) 'rejection_reason': reason,
    }).eq('id', docId);
  }

  // ─── Rides ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRides({
    String? status,
    String? vehicleType,
    DateTime? startDate,
    DateTime? endDate,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client.from('rides').select(
        'id, status, vehicle_type, fare_amount, created_at, '
        'passenger:passenger_id(full_name, phone_number), '
        'driver:driver_id(full_name, phone_number)');

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status) as dynamic;
    }
    if (vehicleType != null && vehicleType.isNotEmpty) {
      query = query.eq('vehicle_type', vehicleType) as dynamic;
    }
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String()) as dynamic;
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String()) as dynamic;
    }

    final res = await (query as PostgrestFilterBuilder)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Stream<List<Map<String, dynamic>>> watchActiveRides() {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'in_progress')
        .order('created_at', ascending: false)
        .limit(50)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  // ─── Subscriptions ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingBankTransfers() async {
    final res = await _client
        .from('subscriptions')
        .select('*, driver:driver_id(full_name, phone_number)')
        .eq('payment_method', 'bank_transfer')
        .eq('payment_status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> confirmBankTransfer(String subscriptionId) async {
    await _client.from('subscriptions').update({
      'payment_status': 'confirmed',
      'confirmed_at': DateTime.now().toIso8601String(),
    }).eq('id', subscriptionId);
  }

  Future<void> rejectBankTransfer(String subscriptionId,
      {required String reason}) async {
    await _client.from('subscriptions').update({
      'payment_status': 'rejected',
      'rejection_reason': reason,
    }).eq('id', subscriptionId);
  }

  Future<List<Map<String, dynamic>>> getSubscriptions({
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client
        .from('subscriptions')
        .select('*, driver:driver_id(full_name, phone_number)');
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status) as dynamic;
    }
    final res = await (query as PostgrestFilterBuilder)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ─── Competitions ───────────────────────────────────────
  Future<Map<String, dynamic>?> getCompetitionSettings() async {
    try {
      final res = await _client
          .from('competition_settings')
          .select('*')
          .single();
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertCompetitionSettings(Map<String, dynamic> settings) async {
    await _client.from('competition_settings').upsert(settings);
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String period) async {
    final res = await _client
        .from('competition_leaderboard')
        .select('*, driver:driver_id(full_name, vehicle_plate_number)')
        .eq('period_type', period)
        .order('rank', ascending: true)
        .limit(10);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> getCompetitionWinners() async {
    final res = await _client
        .from('competition_winners')
        .select('*, driver:driver_id(full_name)')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> markPrizePaid(String winnerId) async {
    await _client.from('competition_winners').update({
      'prize_paid': true,
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', winnerId);
  }

  Future<void> runRaffleManually() async {
    await _client.functions.invoke('run-raffle', body: {'manual': true});
  }

  // ─── Complaints ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getComplaints({
    String? status,
    String? category,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client.from('complaints').select(
        '*, reporter:reporter_id(full_name), reported:reported_id(full_name)');
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status) as dynamic;
    }
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category) as dynamic;
    }
    final res = await (query as PostgrestFilterBuilder)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> resolveComplaint(String complaintId,
      {required String adminNote}) async {
    await _client.from('complaints').update({
      'status': 'resolved',
      'admin_note': adminNote,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', complaintId);
  }

  // ─── Notifications ──────────────────────────────────────
  Future<void> sendNotification({
    required String target,
    required String title,
    required String body,
    String? type,
    String? userId,
  }) async {
    await _client.functions.invoke('send-notification', body: {
      'target': target,
      'title': title,
      'body': body,
      'type': type ?? 'general',
      if (userId != null) 'user_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> getSentNotifications({
    int page = 0,
    int pageSize = 20,
  }) async {
    final res = await _client
        .from('admin_notifications')
        .select('*')
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ─── Referrals ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getReferrals({
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client.from('referrals').select(
        '*, referrer:referrer_id(full_name), referred:referred_id(full_name)');
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status) as dynamic;
    }
    final res = await (query as PostgrestFilterBuilder)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ─── Settings ───────────────────────────────────────────
  Future<Map<String, dynamic>?> getPlatformSettings() async {
    try {
      final res = await _client
          .from('platform_settings')
          .select('*')
          .single();
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlatformSettings(Map<String, dynamic> settings) async {
    await _client.from('platform_settings').upsert(settings);
  }

  // ─── Reports ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMonthlyRevenue() async {
    final res = await _client
        .from('rides')
        .select('fare_amount, created_at')
        .eq('status', 'completed')
        .gte('created_at',
            DateTime.now().subtract(const Duration(days: 365)).toIso8601String())
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> getRidesByVehicleType() async {
    final res = await _client
        .from('rides')
        .select('vehicle_type, fare_amount')
        .eq('status', 'completed')
        .gte('created_at',
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> getSubscriptionRevenue() async {
    final res = await _client
        .from('subscriptions')
        .select('plan_type, amount, created_at')
        .eq('payment_status', 'confirmed')
        .gte('created_at',
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
    return List<Map<String, dynamic>>.from(res as List);
  }
}
