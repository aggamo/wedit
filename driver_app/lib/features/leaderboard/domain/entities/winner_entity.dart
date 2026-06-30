class WinnerEntity {
  final String maskedName;

  /// e.g. "الأسبوع 12 مايو" or "مايو 2025"
  final String periodLabel;

  /// 'rank_prize' or 'raffle'
  final String winType;

  final int rank;
  final double cashPrize;
  final int freeDays;

  const WinnerEntity({
    required this.maskedName,
    required this.periodLabel,
    required this.winType,
    required this.rank,
    required this.cashPrize,
    required this.freeDays,
  });

  bool get isRaffle => winType == 'raffle';
}
