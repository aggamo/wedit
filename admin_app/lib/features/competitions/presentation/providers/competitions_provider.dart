import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../data/datasources/competitions_remote_datasource.dart';
import '../../domain/entities/competition_settings_entity.dart';

// ── Datasource provider ────────────────────────────────────────────────────────
final competitionsDatasourceProvider =
    Provider<CompetitionsRemoteDatasource>((ref) {
  return CompetitionsRemoteDatasource(ref.watch(supabaseClientProvider));
});

// ── Settings provider (by periodType) ─────────────────────────────────────────
final competitionSettingsByPeriodProvider =
    FutureProvider.family<CompetitionSettingsEntity?, String>(
        (ref, periodType) async {
  return ref
      .watch(competitionsDatasourceProvider)
      .getSettings(periodType);
});

// ── Leaderboard provider (by periodType) ──────────────────────────────────────
final competitionLeaderboardProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, periodType) async {
  return ref
      .watch(competitionsDatasourceProvider)
      .getLeaderboard(periodType, limit: 20);
});

// ── Winners provider (by periodType) ──────────────────────────────────────────
final competitionWinnersByPeriodProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, periodType) async {
  return ref
      .watch(competitionsDatasourceProvider)
      .getWinners(periodType, limit: 50);
});

// ── CompetitionsNotifier ───────────────────────────────────────────────────────
class CompetitionsNotifier
    extends AsyncNotifier<Map<String, dynamic>> {
  late CompetitionsRemoteDatasource _ds;

  @override
  Future<Map<String, dynamic>> build() async {
    _ds = ref.watch(competitionsDatasourceProvider);
    return {};
  }

  // ── Update prizes for a given period ──────────────────────────────────────
  Future<void> updatePrizes(
      String periodType, List<PrizeConfig> prizes) async {
    state = const AsyncLoading();
    try {
      final current = await _ds.getSettings(periodType);
      if (current == null) {
        state = AsyncError(
            'لم يتم العثور على إعدادات للفترة: $periodType', StackTrace.current);
        return;
      }
      final updated = current.copyWith(prizes: prizes);
      await _ds.updateSettings(current.id, {
        'prizes': prizes.map((p) => p.toJson()).toList(),
      });
      ref.invalidate(competitionSettingsByPeriodProvider(periodType));
      state = AsyncData({
        'action': 'updatePrizes',
        'periodType': periodType,
        'success': true,
      });
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Update raffle settings ─────────────────────────────────────────────────
  Future<void> updateRaffleSettings(
      String periodType, Map<String, dynamic> settings) async {
    state = const AsyncLoading();
    try {
      final current = await _ds.getSettings(periodType);
      if (current == null) {
        state = AsyncError(
            'لم يتم العثور على إعدادات للفترة: $periodType', StackTrace.current);
        return;
      }
      await _ds.updateSettings(current.id, settings);
      ref.invalidate(competitionSettingsByPeriodProvider(periodType));
      state = AsyncData({
        'action': 'updateRaffleSettings',
        'periodType': periodType,
        'success': true,
      });
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Update ranking criteria ────────────────────────────────────────────────
  Future<void> updateRankingCriteria(
      String periodType, String criteria) async {
    state = const AsyncLoading();
    try {
      final current = await _ds.getSettings(periodType);
      if (current == null) {
        state = AsyncError(
            'لم يتم العثور على إعدادات للفترة: $periodType', StackTrace.current);
        return;
      }
      await _ds.updateSettings(
          current.id, {'ranking_criteria': criteria});
      ref.invalidate(competitionSettingsByPeriodProvider(periodType));
      state = AsyncData({
        'action': 'updateRankingCriteria',
        'periodType': periodType,
        'criteria': criteria,
        'success': true,
      });
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Update plate digits visibility ────────────────────────────────────────
  Future<void> updatePlateDigits(String periodType, int digits) async {
    state = const AsyncLoading();
    try {
      final current = await _ds.getSettings(periodType);
      if (current == null) {
        state = AsyncError(
            'لم يتم العثور على إعدادات للفترة: $periodType', StackTrace.current);
        return;
      }
      await _ds.updateSettings(
          current.id, {'plate_visible_digits': digits});
      ref.invalidate(competitionSettingsByPeriodProvider(periodType));
      state = AsyncData({
        'action': 'updatePlateDigits',
        'periodType': periodType,
        'digits': digits,
        'success': true,
      });
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Mark winner as paid ───────────────────────────────────────────────────
  Future<void> markPaid(String winnerId) async {
    state = const AsyncLoading();
    try {
      final adminId =
          Supabase.instance.client.auth.currentUser?.id ?? 'system';
      await _ds.markWinnerPaid(winnerId, adminId);
      // Invalidate all winner providers
      ref.invalidate(competitionWinnersByPeriodProvider);
      state = AsyncData({
        'action': 'markPaid',
        'winnerId': winnerId,
        'success': true,
      });
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Run manual raffle ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> runManualRaffle(String periodId) async {
    state = const AsyncLoading();
    try {
      final result = await _ds.runRaffle(periodId);
      ref.invalidate(competitionWinnersByPeriodProvider);
      state = AsyncData({
        'action': 'runRaffle',
        'periodId': periodId,
        'result': result,
        'success': true,
      });
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final competitionsNotifierProvider =
    AsyncNotifierProvider<CompetitionsNotifier, Map<String, dynamic>>(
        CompetitionsNotifier.new);
