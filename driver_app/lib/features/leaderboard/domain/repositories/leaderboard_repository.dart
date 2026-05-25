import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/competition_settings_entity.dart';
import '../entities/leaderboard_entry_entity.dart';
import '../entities/my_rank_entity.dart';
import '../entities/winner_entity.dart';

abstract class LeaderboardRepository {
  Future<Either<Failure, List<LeaderboardEntryEntity>>> getLeaderboard(
      String periodType, int limit);

  Future<Either<Failure, MyRankEntity>> getMyRank(String periodType);

  Future<Either<Failure, CompetitionSettingsEntity>> getCompetitionSettings(
      String periodType);

  Future<Either<Failure, List<WinnerEntity>>> getPastWinners(
      String periodType, int limit);

  Future<Either<Failure, DateTime>> getPeriodEndTime(String periodType);
}
