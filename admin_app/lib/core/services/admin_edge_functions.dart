import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides static helpers for invoking Supabase Edge Functions
/// from the wedit admin dashboard.
class AdminEdgeFunctions {
  AdminEdgeFunctions._(); // static-only class

  static SupabaseClient get _client => Supabase.instance.client;

  // ── send-notification ──────────────────────────────────────────────────────

  /// Sends a push notification via the `send-notification` Edge Function.
  ///
  /// [target]  One of: 'all' | 'passengers' | 'drivers' | 'specific_user'
  /// [title]   Notification title (shown in push banner).
  /// [body]    Notification body text.
  /// [type]    One of: 'general' | 'ride_update' | 'subscription' |
  ///           'leaderboard' | 'promo'
  /// [userId]  Required when [target] is 'specific_user'.
  static Future<Map<String, dynamic>> sendNotification({
    required String target,
    required String title,
    required String body,
    String type = 'general',
    String? userId,
  }) async {
    final response = await _client.functions.invoke(
      'send-notification',
      body: {
        'target': target,
        'title': title,
        'body': body,
        'type': type,
        if (userId != null) 'user_id': userId,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'success': true};
  }

  // ── run-raffle ─────────────────────────────────────────────────────────────

  /// Triggers the raffle draw for the given [periodId].
  ///
  /// [periodId]  UUID of the competition period row in `competition_periods`.
  static Future<Map<String, dynamic>> runRaffle(String periodId) async {
    final response = await _client.functions.invoke(
      'run-raffle',
      body: {
        'period_id': periodId,
        'manual': true,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'success': true, 'period_id': periodId};
  }

  // ── close-competition-period ───────────────────────────────────────────────

  /// Closes the current active competition period for [periodType] and
  /// finalises rankings/winners.
  ///
  /// [periodType]  'weekly' | 'monthly'
  static Future<Map<String, dynamic>> closeCompetitionPeriod(
      String periodType) async {
    final response = await _client.functions.invoke(
      'close-competition-period',
      body: {
        'period_type': periodType,
        'manual': true,
        'closed_by': _client.auth.currentUser?.id ?? 'admin',
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'success': true, 'period_type': periodType};
  }
}
