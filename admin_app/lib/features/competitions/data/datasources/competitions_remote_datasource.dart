import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/competition_settings_entity.dart';

class CompetitionsRemoteDatasource {
  final SupabaseClient _client;

  const CompetitionsRemoteDatasource(this._client);

  // ── Settings ───────────────────────────────────────────────────────────────

  /// Fetches competition settings for [periodType] ('weekly' | 'monthly').
  Future<CompetitionSettingsEntity?> getSettings(String periodType) async {
    try {
      final res = await _client
          .from('competition_settings')
          .select('*')
          .eq('period_type', periodType)
          .maybeSingle();
      if (res == null) return null;
      return CompetitionSettingsEntity.fromJson(
          Map<String, dynamic>.from(res as Map));
    } catch (e) {
      rethrow;
    }
  }

  /// Updates competition settings row with [id] using provided [settings] map.
  Future<void> updateSettings(
      String id, Map<String, dynamic> settings) async {
    await _client
        .from('competition_settings')
        .update(settings)
        .eq('id', id);
  }

  /// Upserts competition settings for [entity].
  Future<void> upsertSettings(CompetitionSettingsEntity entity) async {
    await _client
        .from('competition_settings')
        .upsert(entity.toJson());
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────

  /// Returns the leaderboard entries for the active period of [periodType].
  /// Falls back to the competition_leaderboard view / table.
  Future<List<Map<String, dynamic>>> getLeaderboard(
    String periodType, {
    int limit = 10,
  }) async {
    try {
      final res = await _client
          .from('competition_rankings')
          .select('*, driver:driver_id(full_name, vehicle_plate_number)')
          .eq('period_type', periodType)
          .order('rank', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      // Fallback to legacy view
      final res = await _client
          .from('competition_leaderboard')
          .select('*, driver:driver_id(full_name, vehicle_plate_number)')
          .eq('period_type', periodType)
          .order('rank', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List);
    }
  }

  // ── Winners ────────────────────────────────────────────────────────────────

  /// Returns past winners for [periodType], up to [limit] records.
  Future<List<Map<String, dynamic>>> getWinners(
    String periodType, {
    int limit = 50,
  }) async {
    final res = await _client
        .from('competition_winners')
        .select(
            '*, driver:driver_id(full_name, phone_number, vehicle_plate_number)')
        .eq('period_type', periodType)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Marks a winner's prize as paid by [paidBy] admin.
  Future<void> markWinnerPaid(String winnerId, String paidBy) async {
    await _client.from('competition_winners').update({
      'prize_paid': true,
      'paid_at': DateTime.now().toIso8601String(),
      'paid_by': paidBy,
    }).eq('id', winnerId);
  }

  // ── Edge Functions ─────────────────────────────────────────────────────────

  /// Triggers the run-raffle Edge Function for [periodId].
  Future<Map<String, dynamic>> runRaffle(String periodId) async {
    final response = await _client.functions.invoke(
      'run-raffle',
      body: {'period_id': periodId, 'manual': true},
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'success': true};
  }
}
