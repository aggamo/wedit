class EarningsEntity {
  final double todayTotal;
  final double weekTotal;
  final double monthTotal;
  final double allTimeTotal;
  final int ridesCount;
  final double averagePerRide;

  /// Daily breakdown: each entry has {date: DateTime, amount: double, rides: int}
  final List<Map<String, dynamic>> dailyBreakdown;

  const EarningsEntity({
    required this.todayTotal,
    required this.weekTotal,
    required this.monthTotal,
    required this.allTimeTotal,
    required this.ridesCount,
    required this.averagePerRide,
    required this.dailyBreakdown,
  });

  static const empty = EarningsEntity(
    todayTotal: 0,
    weekTotal: 0,
    monthTotal: 0,
    allTimeTotal: 0,
    ridesCount: 0,
    averagePerRide: 0,
    dailyBreakdown: [],
  );
}
