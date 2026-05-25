class MyRankEntity {
  final int rank;
  final int totalDrivers;
  final double score;
  final int ridesCount;

  /// Rides needed to reach rank #1
  final int gapToFirst;

  final bool isRaffleEligible;

  /// Driver's current rides count toward raffle condition
  final int ridesForRaffle;
  final int ridesRequiredForRaffle;
  final int referralsForRaffle;
  final int referralsRequiredForRaffle;

  /// Cash prize if driver reaches rank #1
  final double? potentialCashPrize;

  const MyRankEntity({
    required this.rank,
    required this.totalDrivers,
    required this.score,
    required this.ridesCount,
    required this.gapToFirst,
    required this.isRaffleEligible,
    required this.ridesForRaffle,
    required this.ridesRequiredForRaffle,
    required this.referralsForRaffle,
    required this.referralsRequiredForRaffle,
    this.potentialCashPrize,
  });
}
