import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/rewards_datasource.dart';

// ---------------------------------------------------------------------------
// Datasource provider
// ---------------------------------------------------------------------------

final rewardsDatasourceProvider = Provider<RewardsDatasource>((ref) {
  return RewardsDatasource(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

final gamificationSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getGamificationSummary();
});

final achievementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getAchievements();
});

final driverAchievementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getDriverAchievements();
});

final redemptionOptionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getRedemptionOptions();
});

final pendingBoxProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getPendingBox();
});

final currentSubscriptionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getCurrentSubscription();
});

final freezeReasonsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getFreezeReasons();
});

final recentXpTransactionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getRecentXpTransactions(limit: 20);
});

final recentPointsTransactionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getRecentPointsTransactions(limit: 20);
});

final leaderboardWindowProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(rewardsDatasourceProvider);
  return ds.getLeaderboardWindow();
});
