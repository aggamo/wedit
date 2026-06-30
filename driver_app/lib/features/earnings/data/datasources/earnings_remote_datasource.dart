import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/earnings_entity.dart';

abstract class EarningsRemoteDatasource {
  Future<EarningsEntity> getEarnings(String driverId, String period);
}

class EarningsRemoteDatasourceImpl implements EarningsRemoteDatasource {
  final SupabaseClient _supabase;

  EarningsRemoteDatasourceImpl(this._supabase);

  @override
  Future<EarningsEntity> getEarnings(
      String driverId, String period) async {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        final weekday = now.weekday; // Mon=1, Sun=7
        startDate =
            now.subtract(Duration(days: weekday - 1));
        startDate =
            DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default: // 'all'
        startDate = DateTime(2020, 1, 1);
    }

    // Query completed rides in period
    final data = await _supabase
        .from(AppConstants.ridesTable)
        .select('agreed_price, completed_at, created_at, pickup_address, dropoff_address')
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .gte('completed_at', startDate.toIso8601String())
        .order('completed_at', ascending: false);

    double periodTotal = 0;
    final Map<String, Map<String, dynamic>> dailyMap = {};

    for (final row in data) {
      final price = (row['agreed_price'] as num?)?.toDouble() ?? 0;
      periodTotal += price;

      final completedAt = row['completed_at'] as String?;
      if (completedAt != null) {
        final date = DateTime.parse(completedAt);
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (dailyMap.containsKey(key)) {
          dailyMap[key]!['amount'] =
              (dailyMap[key]!['amount'] as double) + price;
          dailyMap[key]!['rides'] =
              (dailyMap[key]!['rides'] as int) + 1;
        } else {
          dailyMap[key] = {
            'date': date,
            'amount': price,
            'rides': 1,
          };
        }
      }
    }

    // Sort daily breakdown newest first
    final breakdownList = dailyMap.values.toList()
      ..sort((a, b) => (b['date'] as DateTime)
          .compareTo(a['date'] as DateTime));

    // Get all-time total
    final allTimeData = await _supabase
        .from(AppConstants.ridesTable)
        .select('agreed_price')
        .eq('driver_id', driverId)
        .eq('status', 'completed');

    double allTime = 0;
    for (final row in allTimeData) {
      allTime += (row['agreed_price'] as num?)?.toDouble() ?? 0;
    }

    final count = data.length;

    return EarningsEntity(
      todayTotal: period == 'today' ? periodTotal : 0,
      weekTotal: period == 'week' ? periodTotal : 0,
      monthTotal: period == 'month' ? periodTotal : 0,
      allTimeTotal: allTime,
      ridesCount: count,
      averagePerRide: count > 0 ? periodTotal / count : 0,
      dailyBreakdown: breakdownList,
    );
  }
}
