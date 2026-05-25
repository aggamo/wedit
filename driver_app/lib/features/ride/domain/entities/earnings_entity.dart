class EarningsEntity {
  final double todayTotal;
  final double weekTotal;
  final double monthTotal;
  final double allTimeTotal;
  final int ridesCount;
  final double averagePerRide;
  final List<DailyEarning> dailyBreakdown;

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

class DailyEarning {
  final DateTime date;
  final double amount;
  final int rides;

  const DailyEarning({
    required this.date,
    required this.amount,
    required this.rides,
  });
}
