import 'package:supabase_flutter/supabase_flutter.dart';

class RewardsDatasource {
  final SupabaseClient _client;

  RewardsDatasource(this._client);

  String? get _uid => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Gamification summary (edge function)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getGamificationSummary() async {
    final uid = _uid;
    if (uid == null) return null;
    final response = await _client.functions.invoke(
      'get-driver-gamification-summary',
      body: {'driver_id': uid},
    );
    if (response.data == null) return null;
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  // ---------------------------------------------------------------------------
  // XP transactions
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getRecentXpTransactions(
      {int limit = 20}) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('xp_transactions')
        .select()
        .eq('driver_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---------------------------------------------------------------------------
  // Points transactions
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getRecentPointsTransactions(
      {int limit = 20}) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('points_transactions')
        .select()
        .eq('driver_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final rows = await _client
        .from('achievements')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getDriverAchievements() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('driver_achievements')
        .select('*, achievements(*)')
        .eq('driver_id', uid)
        .order('earned_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---------------------------------------------------------------------------
  // Redemption
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getRedemptionOptions() async {
    final rows = await _client
        .from('redemption_options')
        .select()
        .eq('is_active', true)
        .order('points_cost', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> redeemPoints(String optionId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _client.functions.invoke(
      'redeem-points',
      body: {'driver_id': uid, 'option_id': optionId},
    );
  }

  // ---------------------------------------------------------------------------
  // Box openings
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getPendingBox() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client
        .from('driver_box_openings')
        .select()
        .eq('driver_id', uid)
        .eq('prize_delivered', false)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    return row != null ? Map<String, dynamic>.from(row) : null;
  }

  Future<Map<String, dynamic>> openBox(String boxId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _client.functions.invoke(
      'open-reward-box',
      body: {'driver_id': uid, 'box_id': boxId},
    );
    if (response.data == null) throw Exception('No response from server');
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ---------------------------------------------------------------------------
  // Subscription
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getCurrentSubscription() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client
        .from('driver_subscriptions')
        .select('*, subscription_plans(*)')
        .eq('driver_id', uid)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row != null ? Map<String, dynamic>.from(row) : null;
  }

  Future<void> freezeSubscription(
      {String? reasonId, String? customReason}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _client.functions.invoke(
      'freeze-subscription',
      body: {
        'driver_id': uid,
        if (reasonId != null) 'reason_id': reasonId,
        if (customReason != null) 'custom_reason': customReason,
      },
    );
  }

  Future<void> unfreezeSubscription() async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _client.functions.invoke(
      'unfreeze-subscription',
      body: {'driver_id': uid},
    );
  }

  Future<List<Map<String, dynamic>>> getFreezeReasons() async {
    final rows = await _client
        .from('freeze_reasons')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---------------------------------------------------------------------------
  // Leaderboard window
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getLeaderboardWindow() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client.rpc(
      'get_driver_leaderboard_window',
      params: {'p_driver_id': uid, 'p_window_size': 5},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
