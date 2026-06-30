class LeaderboardEntryEntity {
  final int rank;
  final String driverId;

  /// Masked display name, e.g. "Ahmed M."
  final String maskedName;

  /// Masked plate, e.g. "***45"
  final String maskedPlate;

  final double score;
  final int ridesCount;
  final double avgRating;
  final double cashPrize;
  final int freeDays;

  /// True when this entry belongs to the currently logged-in driver
  final bool isCurrentDriver;

  const LeaderboardEntryEntity({
    required this.rank,
    required this.driverId,
    required this.maskedName,
    required this.maskedPlate,
    required this.score,
    required this.ridesCount,
    required this.avgRating,
    required this.cashPrize,
    required this.freeDays,
    required this.isCurrentDriver,
  });
}
