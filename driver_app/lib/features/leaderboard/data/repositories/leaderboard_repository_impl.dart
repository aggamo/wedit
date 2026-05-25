import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/competition_settings_entity.dart';
import '../../domain/entities/leaderboard_entry_entity.dart';
import '../../domain/entities/my_rank_entity.dart';
import '../../domain/entities/winner_entity.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDatasource _datasource;
  final SupabaseClient _supabase;

  LeaderboardRepositoryImpl(this._datasource, this._supabase);

  String get _driverId => _supabase.auth.currentUser?.id ?? '';

  @override
  Future<Either<Failure, List<LeaderboardEntryEntity>>> getLeaderboard(
      String periodType, int limit) async {
    try {
      final result = await _datasource.getLeaderboard(
          periodType, limit, _driverId);
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MyRankEntity>> getMyRank(
      String periodType) async {
    try {
      final result =
          await _datasource.getMyRank(_driverId, periodType);
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CompetitionSettingsEntity>>
      getCompetitionSettings(String periodType) async {
    try {
      final result =
          await _datasource.getCompetitionSettings(periodType);
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<WinnerEntity>>> getPastWinners(
      String periodType, int limit) async {
    try {
      final result =
          await _datasource.getPastWinners(periodType, limit);
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DateTime>> getPeriodEndTime(
      String periodType) async {
    try {
      final result =
          await _datasource.getPeriodEndTime(periodType);
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
