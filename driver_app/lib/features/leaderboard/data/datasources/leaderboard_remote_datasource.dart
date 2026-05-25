import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/competition_settings_entity.dart';
import '../../domain/entities/leaderboard_entry_entity.dart';
import '../../domain/entities/my_rank_entity.dart';
import '../../domain/entities/winner_entity.dart';

abstract class LeaderboardRemoteDatasource {
  Future<List<LeaderboardEntryEntity>> getLeaderboard(
      String periodType, int limit, String currentDriverId);

  Future<MyRankEntity> getMyRank(
      String driverId, String periodType);

  Future<CompetitionSettingsEntity> getCompetitionSettings(
      String periodType);

  Future<List<WinnerEntity>> getPastWinners(
      String periodType, int limit);

  Future<DateTime> getPeriodEndTime(String periodType);
}

class LeaderboardRemoteDatasourceImpl
    implements LeaderboardRemoteDatasource {
  final SupabaseClient _supabase;

  LeaderboardRemoteDatasourceImpl(this._supabase);

  @override
  Future<List<LeaderboardEntryEntity>> getLeaderboard(
      String periodType, int limit, String currentDriverId) async {
    try {
      // Get active competition period
      final periods = await _supabase
          .from('competition_periods')
          .select('id')
          .eq('period_type', periodType)
          .eq('status', 'active')
          .limit(1);

      if (periods.isEmpty) return [];

      final periodId = periods.first['id'] as String;

      // Get rankings for this period
      final rankings = await _supabase
          .from(AppConstants.competitionRankingsTable)
          .select('driver_id, rank, score, rides_count, avg_rating, plate_number, driver_name')
          .eq('period_id', periodId)
          .order('rank', ascending: true)
          .limit(limit);

      // Get settings for prizes
      final settings =
          await getCompetitionSettings(periodType);

      return rankings.asMap().entries.map((entry) {
        final row = entry.value;
        final rank = (row['rank'] as int?) ?? (entry.key + 1);
        final driverId = row['driver_id'] as String? ?? '';

        // Find prize for this rank
        PrizeConfig? prize;
        for (final p in settings.prizes) {
          if (p.rank == rank) {
            prize = p;
            break;
          }
        }

        // Mask the plate
        final rawPlate = row['plate_number'] as String? ?? '';
        final maskedPlate = _maskPlate(
            rawPlate, settings.plateDigitsVisible);

        // Mask the name
        final rawName = row['driver_name'] as String? ?? 'سائق';
        final maskedName = _maskName(rawName);

        return LeaderboardEntryEntity(
          rank: rank,
          driverId: driverId,
          maskedName: maskedName,
          maskedPlate: maskedPlate,
          score: (row['score'] as num?)?.toDouble() ?? 0,
          ridesCount: (row['rides_count'] as int?) ?? 0,
          avgRating: (row['avg_rating'] as num?)?.toDouble() ?? 0,
          cashPrize: prize?.cash ?? 0,
          freeDays: prize?.freeDays ?? 0,
          isCurrentDriver: driverId == currentDriverId,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<MyRankEntity> getMyRank(
      String driverId, String periodType) async {
    try {
      // Get active period
      final periods = await _supabase
          .from('competition_periods')
          .select('id')
          .eq('period_type', periodType)
          .eq('status', 'active')
          .limit(1);

      if (periods.isEmpty) {
        return MyRankEntity(
          rank: 0,
          totalDrivers: 0,
          score: 0,
          ridesCount: 0,
          gapToFirst: 0,
          isRaffleEligible: false,
          ridesForRaffle: 0,
          ridesRequiredForRaffle:
              AppConstants.raffleRequiredRides,
          referralsForRaffle: 0,
          referralsRequiredForRaffle:
              AppConstants.raffleRequiredInvites,
        );
      }

      final periodId = periods.first['id'] as String;

      // Get my ranking
      final myRankings = await _supabase
          .from(AppConstants.competitionRankingsTable)
          .select('rank, score, rides_count')
          .eq('period_id', periodId)
          .eq('driver_id', driverId)
          .limit(1);

      // Get total drivers in this period
      final totalCount = await _supabase
          .from(AppConstants.competitionRankingsTable)
          .select()
          .eq('period_id', periodId)
          .count();

      // Get first place score
      final firstPlace = await _supabase
          .from(AppConstants.competitionRankingsTable)
          .select('rides_count')
          .eq('period_id', periodId)
          .order('rank', ascending: true)
          .limit(1);

      final firstRidesCount =
          firstPlace.isNotEmpty
              ? (firstPlace.first['rides_count'] as int?) ?? 0
              : 0;

      final settings = await getCompetitionSettings(periodType);
      final raffleConditions = settings.raffleConditions;
      final ridesRequired = (raffleConditions['rides_required'] as int?) ??
          AppConstants.raffleRequiredRides;
      final passengerReferralsRequired =
          (raffleConditions['passenger_referrals'] as int?) ??
              AppConstants.raffleRequiredInvites;
      final driverReferralsRequired =
          (raffleConditions['driver_referrals'] as int?) ?? 0;

      if (myRankings.isEmpty) {
        return MyRankEntity(
          rank: 0,
          totalDrivers: totalCount.count,
          score: 0,
          ridesCount: 0,
          gapToFirst: firstRidesCount,
          isRaffleEligible: false,
          ridesForRaffle: 0,
          ridesRequiredForRaffle: ridesRequired,
          referralsForRaffle: 0,
          referralsRequiredForRaffle: passengerReferralsRequired,
        );
      }

      final myRow = myRankings.first;
      final myRank = (myRow['rank'] as int?) ?? 0;
      final myRides = (myRow['rides_count'] as int?) ?? 0;
      final gapToFirst = myRank == 1
          ? 0
          : (firstRidesCount - myRides).clamp(0, 9999);

      // Get referral counts for raffle eligibility
      final referralData = await _supabase
          .from('referrals')
          .select()
          .eq('referrer_id', driverId)
          .count();
      final referralCount = referralData.count;

      final isRaffleEligible = myRides >= ridesRequired ||
          referralCount >= passengerReferralsRequired;

      final prizeForFirst =
          settings.prizes.isNotEmpty ? settings.prizes.first : null;

      return MyRankEntity(
        rank: myRank,
        totalDrivers: totalCount.count,
        score: (myRow['score'] as num?)?.toDouble() ?? 0,
        ridesCount: myRides,
        gapToFirst: gapToFirst,
        isRaffleEligible: isRaffleEligible,
        ridesForRaffle: myRides,
        ridesRequiredForRaffle: ridesRequired,
        referralsForRaffle: referralCount,
        referralsRequiredForRaffle: passengerReferralsRequired,
        potentialCashPrize: prizeForFirst?.cash,
      );
    } on PostgrestException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<CompetitionSettingsEntity> getCompetitionSettings(
      String periodType) async {
    try {
      final data = await _supabase
          .from(AppConstants.competitionSettingsTable)
          .select()
          .eq('period_type', periodType)
          .eq('is_active', true)
          .limit(1);

      if (data.isEmpty) {
        return CompetitionSettingsEntity.defaultSettings(periodType);
      }

      final row = data.first;
      final prizesRaw = row['prizes'] as List<dynamic>? ?? [];
      final prizes = prizesRaw
          .map((p) => PrizeConfig(
                rank: (p['rank'] as int?) ?? 0,
                cash: (p['cash'] as num?)?.toDouble() ?? 0,
                freeDays: (p['free_days'] as int?) ?? 0,
              ))
          .toList();

      return CompetitionSettingsEntity(
        periodType: periodType,
        rankingCriteria:
            row['ranking_criteria'] as String? ?? 'rides',
        prizes: prizes,
        raffleEnabled: row['raffle_enabled'] as bool? ?? false,
        rafflePrizeCash:
            (row['raffle_prize_cash'] as num?)?.toDouble() ?? 0,
        rafflePrizeDays: (row['raffle_prize_days'] as int?) ?? 0,
        raffleWinnersCount:
            (row['raffle_winners_count'] as int?) ?? 1,
        raffleConditions:
            (row['raffle_conditions'] as Map<String, dynamic>?) ??
                {},
        plateDigitsVisible:
            (row['plate_digits_visible'] as int?) ?? 2,
        isActive: row['is_active'] as bool? ?? true,
      );
    } catch (e) {
      // Return default if DB not set up
      return CompetitionSettingsEntity.defaultSettings(periodType);
    }
  }

  @override
  Future<List<WinnerEntity>> getPastWinners(
      String periodType, int limit) async {
    try {
      final data = await _supabase
          .from(AppConstants.competitionWinnersTable)
          .select('*, competition_periods!inner(period_type, label, status)')
          .eq('competition_periods.period_type', periodType)
          .eq('competition_periods.status', 'rewarded')
          .order('created_at', ascending: false)
          .limit(limit);

      return data.map((row) {
        final period =
            row['competition_periods'] as Map<String, dynamic>?;
        return WinnerEntity(
          maskedName: _maskName(row['driver_name'] as String? ?? 'سائق'),
          periodLabel: period?['label'] as String? ?? '',
          winType: row['win_type'] as String? ?? 'rank_prize',
          rank: (row['rank'] as int?) ?? 0,
          cashPrize: (row['cash_prize'] as num?)?.toDouble() ?? 0,
          freeDays: (row['free_days'] as int?) ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<DateTime> getPeriodEndTime(String periodType) async {
    try {
      final data = await _supabase
          .from('competition_periods')
          .select('ended_at')
          .eq('period_type', periodType)
          .eq('status', 'active')
          .limit(1);

      if (data.isEmpty) {
        return _calculateNextEndTime(periodType);
      }

      final endedAt = data.first['ended_at'];
      if (endedAt == null) {
        return _calculateNextEndTime(periodType);
      }

      return DateTime.parse(endedAt as String);
    } catch (_) {
      return _calculateNextEndTime(periodType);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime _calculateNextEndTime(String periodType) {
    final now = DateTime.now();
    if (periodType == 'weekly') {
      // Next Sunday at 23:59
      final daysUntilSunday = 7 - now.weekday;
      final nextSunday = now.add(Duration(days: daysUntilSunday));
      return DateTime(
          nextSunday.year, nextSunday.month, nextSunday.day, 23, 59);
    } else {
      // Last day of current month at 23:59
      final lastDay =
          DateTime(now.year, now.month + 1, 0);
      return DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59);
    }
  }

  String _maskPlate(String plate, int visibleDigits) {
    if (plate.length <= visibleDigits) return plate;
    final visible = plate.substring(plate.length - visibleDigits);
    return '${'*' * (plate.length - visibleDigits)}$visible';
  }

  String _maskName(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return name;
    if (parts.length == 1) {
      final n = parts[0];
      return n.length > 1 ? '${n[0]}${n.substring(1).replaceAll(RegExp(r'.'), '*')}' : n;
    }
    return '${parts[0]} ${parts[1][0]}.';
  }
}
