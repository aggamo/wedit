class PrizeConfig {
  final int rank;
  final double cash;
  final int freeDays;

  const PrizeConfig({
    required this.rank,
    required this.cash,
    required this.freeDays,
  });
}

class CompetitionSettingsEntity {
  final String periodType; // 'weekly' or 'monthly'
  final String rankingCriteria;
  final List<PrizeConfig> prizes;
  final bool raffleEnabled;
  final double rafflePrizeCash;
  final int rafflePrizeDays;
  final int raffleWinnersCount;

  /// Raffle conditions: {logic: 'or'|'and', rides_required: int, passenger_referrals: int?, driver_referrals: int?}
  final Map<String, dynamic> raffleConditions;

  final int plateDigitsVisible;
  final bool isActive;

  const CompetitionSettingsEntity({
    required this.periodType,
    required this.rankingCriteria,
    required this.prizes,
    required this.raffleEnabled,
    required this.rafflePrizeCash,
    required this.rafflePrizeDays,
    required this.raffleWinnersCount,
    required this.raffleConditions,
    required this.plateDigitsVisible,
    required this.isActive,
  });

  /// Default settings used as a fallback when the DB is not available
  static CompetitionSettingsEntity defaultSettings(String periodType) {
    return CompetitionSettingsEntity(
      periodType: periodType,
      rankingCriteria: 'rides',
      prizes: const [
        PrizeConfig(rank: 1, cash: 500, freeDays: 7),
        PrizeConfig(rank: 2, cash: 300, freeDays: 5),
        PrizeConfig(rank: 3, cash: 200, freeDays: 3),
      ],
      raffleEnabled: true,
      rafflePrizeCash: 100,
      rafflePrizeDays: 2,
      raffleWinnersCount: 3,
      raffleConditions: const {
        'logic': 'or',
        'rides_required': 25,
        'passenger_referrals': 5,
        'driver_referrals': 2,
      },
      plateDigitsVisible: 2,
      isActive: true,
    );
  }
}
