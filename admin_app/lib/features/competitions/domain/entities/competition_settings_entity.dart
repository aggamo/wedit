class PrizeConfig {
  final int rank;
  final double cash;
  final int freeDays;

  const PrizeConfig({
    required this.rank,
    required this.cash,
    required this.freeDays,
  });

  factory PrizeConfig.fromJson(Map<String, dynamic> json) => PrizeConfig(
        rank: (json['rank'] as num).toInt(),
        cash: (json['cash'] as num).toDouble(),
        freeDays: (json['free_days'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'cash': cash,
        'free_days': freeDays,
      };

  PrizeConfig copyWith({int? rank, double? cash, int? freeDays}) => PrizeConfig(
        rank: rank ?? this.rank,
        cash: cash ?? this.cash,
        freeDays: freeDays ?? this.freeDays,
      );
}

class CompetitionSettingsEntity {
  final String id;
  final String periodType;
  final String rankingCriteria;
  final List<PrizeConfig> prizes;
  final bool raffleEnabled;
  final double rafflePrizeCash;
  final int rafflePrizeDays;
  final int raffleWinnersCount;
  final String raffleLogic; // 'OR' or 'AND'
  final int ridesRequired;
  final int passengerReferrals;
  final int driverReferrals;
  final int plateDigitsVisible;
  final int weekStartDay;
  final bool isActive;

  const CompetitionSettingsEntity({
    required this.id,
    required this.periodType,
    required this.rankingCriteria,
    required this.prizes,
    required this.raffleEnabled,
    required this.rafflePrizeCash,
    required this.rafflePrizeDays,
    required this.raffleWinnersCount,
    required this.raffleLogic,
    required this.ridesRequired,
    required this.passengerReferrals,
    required this.driverReferrals,
    required this.plateDigitsVisible,
    required this.weekStartDay,
    required this.isActive,
  });

  factory CompetitionSettingsEntity.fromJson(Map<String, dynamic> json) {
    final prizesRaw = json['prizes'];
    List<PrizeConfig> prizes = [];
    if (prizesRaw is List) {
      prizes = prizesRaw
          .map((p) => PrizeConfig.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    return CompetitionSettingsEntity(
      id: json['id'] as String? ?? '',
      periodType: json['period_type'] as String? ?? 'weekly',
      rankingCriteria:
          json['ranking_criteria'] as String? ?? 'rides_count',
      prizes: prizes,
      raffleEnabled: json['raffle_enabled'] as bool? ?? true,
      rafflePrizeCash:
          (json['raffle_prize_cash'] as num? ?? 1000).toDouble(),
      rafflePrizeDays:
          (json['raffle_prize_free_days'] as num? ?? 7).toInt(),
      raffleWinnersCount:
          (json['raffle_winners_count'] as num? ?? 1).toInt(),
      raffleLogic: json['raffle_logic'] as String? ?? 'OR',
      ridesRequired:
          (json['raffle_rides_required'] as num? ?? 30).toInt(),
      passengerReferrals:
          (json['raffle_passenger_referrals'] as num? ?? 0).toInt(),
      driverReferrals:
          (json['raffle_driver_referrals'] as num? ?? 0).toInt(),
      plateDigitsVisible:
          (json['plate_visible_digits'] as num? ?? 2).toInt(),
      weekStartDay: _dayToInt(json['week_start_day'] as String? ?? 'monday'),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'period_type': periodType,
        'ranking_criteria': rankingCriteria,
        'prizes': prizes.map((p) => p.toJson()).toList(),
        'raffle_enabled': raffleEnabled,
        'raffle_prize_cash': rafflePrizeCash,
        'raffle_prize_free_days': rafflePrizeDays,
        'raffle_winners_count': raffleWinnersCount,
        'raffle_logic': raffleLogic,
        'raffle_rides_required': ridesRequired,
        'raffle_passenger_referrals': passengerReferrals,
        'raffle_driver_referrals': driverReferrals,
        'plate_visible_digits': plateDigitsVisible,
        'week_start_day': _intToDay(weekStartDay),
        'is_active': isActive,
      };

  CompetitionSettingsEntity copyWith({
    String? id,
    String? periodType,
    String? rankingCriteria,
    List<PrizeConfig>? prizes,
    bool? raffleEnabled,
    double? rafflePrizeCash,
    int? rafflePrizeDays,
    int? raffleWinnersCount,
    String? raffleLogic,
    int? ridesRequired,
    int? passengerReferrals,
    int? driverReferrals,
    int? plateDigitsVisible,
    int? weekStartDay,
    bool? isActive,
  }) =>
      CompetitionSettingsEntity(
        id: id ?? this.id,
        periodType: periodType ?? this.periodType,
        rankingCriteria: rankingCriteria ?? this.rankingCriteria,
        prizes: prizes ?? this.prizes,
        raffleEnabled: raffleEnabled ?? this.raffleEnabled,
        rafflePrizeCash: rafflePrizeCash ?? this.rafflePrizeCash,
        rafflePrizeDays: rafflePrizeDays ?? this.rafflePrizeDays,
        raffleWinnersCount: raffleWinnersCount ?? this.raffleWinnersCount,
        raffleLogic: raffleLogic ?? this.raffleLogic,
        ridesRequired: ridesRequired ?? this.ridesRequired,
        passengerReferrals: passengerReferrals ?? this.passengerReferrals,
        driverReferrals: driverReferrals ?? this.driverReferrals,
        plateDigitsVisible: plateDigitsVisible ?? this.plateDigitsVisible,
        weekStartDay: weekStartDay ?? this.weekStartDay,
        isActive: isActive ?? this.isActive,
      );

  static int _dayToInt(String day) {
    return switch (day) {
      'sunday' => DateTime.sunday,
      'monday' => DateTime.monday,
      'saturday' => DateTime.saturday,
      _ => DateTime.monday,
    };
  }

  static String _intToDay(int day) {
    return switch (day) {
      DateTime.sunday => 'sunday',
      DateTime.saturday => 'saturday',
      _ => 'monday',
    };
  }

  @override
  String toString() =>
      'CompetitionSettingsEntity(id: $id, periodType: $periodType, '
      'rankingCriteria: $rankingCriteria, prizes: ${prizes.length}, '
      'raffleEnabled: $raffleEnabled)';
}
