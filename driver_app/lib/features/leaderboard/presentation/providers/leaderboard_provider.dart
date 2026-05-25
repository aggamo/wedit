import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/leaderboard_remote_datasource.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../domain/entities/competition_settings_entity.dart';
import '../../domain/entities/leaderboard_entry_entity.dart';
import '../../domain/entities/my_rank_entity.dart';
import '../../domain/entities/winner_entity.dart';
import '../../domain/repositories/leaderboard_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final leaderboardDatasourceProvider =
    Provider<LeaderboardRemoteDatasource>((ref) {
  return LeaderboardRemoteDatasourceImpl(
      ref.watch(supabaseClientProvider));
});

final leaderboardRepositoryProvider =
    Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepositoryImpl(
    ref.watch(leaderboardDatasourceProvider),
    ref.watch(supabaseClientProvider),
  );
});

// ---------------------------------------------------------------------------
// Period selector
// ---------------------------------------------------------------------------

/// Currently selected period tab ('weekly' or 'monthly')
final selectedPeriodProvider =
    StateProvider<String>((ref) => 'weekly');

// ---------------------------------------------------------------------------
// FutureProvider families
// ---------------------------------------------------------------------------

/// Top-N leaderboard entries for a given period
final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntryEntity>, String>(
        (ref, periodType) async {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final result = await repo.getLeaderboard(
      periodType, AppConstants.leaderboardTopN);
  return result.fold((f) => throw f, (data) => data);
});

/// Current driver's rank for a given period
final myRankProvider =
    FutureProvider.family<MyRankEntity, String>(
        (ref, periodType) async {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final result = await repo.getMyRank(periodType);
  return result.fold((f) => throw f, (data) => data);
});

/// Competition settings for a given period
final competitionSettingsProvider =
    FutureProvider.family<CompetitionSettingsEntity, String>(
        (ref, periodType) async {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final result = await repo.getCompetitionSettings(periodType);
  return result.fold(
    (f) => CompetitionSettingsEntity.defaultSettings(periodType),
    (data) => data,
  );
});

/// Past winners for a given period
final pastWinnersProvider =
    FutureProvider.family<List<WinnerEntity>, String>(
        (ref, periodType) async {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final result = await repo.getPastWinners(periodType, 8);
  return result.fold((f) => [], (data) => data);
});

/// Period end time for countdown
final periodEndTimeProvider =
    FutureProvider.family<DateTime, String>(
        (ref, periodType) async {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final result = await repo.getPeriodEndTime(periodType);
  return result.fold(
    (f) {
      final now = DateTime.now();
      if (periodType == 'weekly') {
        final daysUntilSunday = 7 - now.weekday;
        final next =
            now.add(Duration(days: daysUntilSunday));
        return DateTime(next.year, next.month, next.day, 23, 59);
      }
      final lastDay =
          DateTime(now.year, now.month + 1, 0);
      return DateTime(
          lastDay.year, lastDay.month, lastDay.day, 23, 59);
    },
    (data) => data,
  );
});
