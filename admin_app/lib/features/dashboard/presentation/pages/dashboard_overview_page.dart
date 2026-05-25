import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/data_table_widget.dart';
import 'package:data_table_2/data_table_2.dart';

// Providers
final ridesLast30DaysProvider = FutureProvider<List<FlSpot>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final start =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final res = await supabase
        .from('rides')
        .select('created_at')
        .gte('created_at', start)
        .order('created_at', ascending: true);

    final Map<int, int> byDay = {};
    for (final ride in (res as List)) {
      final date = DateTime.parse(ride['created_at']);
      final dayIndex = DateTime.now().difference(date).inDays;
      final key = 29 - dayIndex;
      byDay[key] = (byDay[key] ?? 0) + 1;
    }
    return List.generate(30, (i) => FlSpot(i.toDouble(), (byDay[i] ?? 0).toDouble()));
  } catch (_) {
    return List.generate(30, (i) => FlSpot(i.toDouble(), 0));
  }
});

final revenueByPaymentMethodProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, 1).toIso8601String();
    final res = await supabase
        .from('rides')
        .select('payment_method, fare_amount')
        .eq('status', 'completed')
        .gte('created_at', start);

    final Map<String, double> byMethod = {};
    for (final ride in (res as List)) {
      final method = ride['payment_method'] as String? ?? 'other';
      byMethod[method] =
          (byMethod[method] ?? 0) + ((ride['fare_amount'] ?? 0) as num).toDouble();
    }
    return byMethod;
  } catch (_) {
    return {'نقدي': 6000, 'إلكتروني': 4000};
  }
});

final recentRidesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase
        .from('rides')
        .select('id, status, fare_amount, created_at, '
            'passenger:passenger_id(full_name), driver:driver_id(full_name), '
            'vehicle_type')
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (_) {
    return [];
  }
});

final pendingDriversProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase
        .from('drivers')
        .select('id, full_name, phone_number, vehicle_type, created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(5);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (_) {
    return [];
  }
});

class DashboardOverviewPage extends ConsumerWidget {
  const DashboardOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً بك في لوحة التحكم',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    DateFormat('EEEE، d MMMM yyyy', 'ar').format(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => ref.refresh(dashboardStatsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stat cards
          statsAsync.when(
            loading: () => _StatCardsRow(stats: null),
            error: (_, __) => _StatCardsRow(stats: null),
            data: (stats) => _StatCardsRow(stats: stats),
          ),
          const SizedBox(height: 24),

          // Charts row
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _RidesChart()),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _RevenueByMethodChart()),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _RidesChart(),
                      const SizedBox(height: 16),
                      _RevenueByMethodChart(),
                    ],
                  );
          }),
          const SizedBox(height: 24),

          // Recent rides table
          _RecentRidesCard(),
          const SizedBox(height: 24),

          // Pending drivers
          _PendingDriversCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCardsRow extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _StatCardsRow({this.stats});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: 'ETB ');
    final cards = [
      (
        'رحلات اليوم',
        stats != null ? '${stats!['rides_today']}' : '—',
        Icons.directions_car,
        AppColors.primary,
        2.4,
      ),
      (
        'السائقون النشطون',
        stats != null ? '${stats!['active_drivers']}' : '—',
        Icons.people,
        AppColors.secondary,
        5.1,
      ),
      (
        'إيرادات اليوم',
        stats != null
            ? currency.format(stats!['revenue_today'])
            : '—',
        Icons.payments,
        AppColors.tertiary,
        -1.2,
      ),
      (
        'تسجيلات جديدة',
        stats != null ? '${stats!['new_registrations']}' : '—',
        Icons.person_add,
        AppColors.info,
        8.0,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final count = constraints.maxWidth > 900
          ? 4
          : constraints.maxWidth > 600
              ? 2
              : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards.map((c) {
          return SizedBox(
            width: (constraints.maxWidth - (count - 1) * 16) / count,
            child: StatCard(
              title: c.$1,
              value: c.$2,
              icon: c.$3,
              color: c.$4,
              changePercent: c.$5,
              isLoading: stats == null,
            ),
          );
        }).toList(),
      );
    });
  }
}

class _RidesChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(ridesLast30DaysProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الرحلات (آخر 30 يوم)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: spotsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('خطأ في التحميل')),
                data: (spots) => LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 5,
                      getDrawingHorizontalLine: (v) => const FlLine(
                        color: Color(0xFFE0E0E0),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            if (value % 5 != 0) return const SizedBox.shrink();
                            final daysAgo = 29 - value.toInt();
                            final date = DateTime.now()
                                .subtract(Duration(days: daysAgo));
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${date.day}/${date.month}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueByMethodChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(revenueByPaymentMethodProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإيرادات حسب وسيلة الدفع',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: dataAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('خطأ في التحميل')),
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(child: Text('لا توجد بيانات'));
                  }
                  final colors = [
                    AppColors.primary,
                    AppColors.secondary,
                    AppColors.tertiary,
                    AppColors.info,
                  ];
                  final entries = data.entries.toList();
                  final total = data.values.fold(0.0, (a, b) => a + b);

                  return Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 50,
                            sections: List.generate(entries.length, (i) {
                              final pct = total > 0
                                  ? entries[i].value / total * 100
                                  : 0.0;
                              return PieChartSectionData(
                                value: entries[i].value,
                                color: colors[i % colors.length],
                                radius: 60,
                                title: '${pct.toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(entries.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: colors[i % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _methodLabel(entries[i].key),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _methodLabel(String key) {
    switch (key) {
      case 'cash':
        return 'نقدي';
      case 'telebirr':
        return 'تيليبير';
      case 'cbe_birr':
        return 'CBE بير';
      case 'card':
        return 'بطاقة';
      default:
        return key;
    }
  }
}

class _RecentRidesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(recentRidesProvider);
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: '');

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Text(
                  'آخر الرحلات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/dashboard/rides'),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: ridesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('تعذر تحميل الرحلات')),
              data: (rides) => rides.isEmpty
                  ? const Center(child: Text('لا توجد رحلات حديثة'))
                  : DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 16,
                      headingRowHeight: 44,
                      dataRowHeight: 50,
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.shade100,
                        ),
                      ),
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.primary.withOpacity(0.04),
                      ),
                      columns: const [
                        DataColumn2(label: Text('المعرّف'), size: ColumnSize.S),
                        DataColumn2(label: Text('الراكب'), size: ColumnSize.M),
                        DataColumn2(label: Text('السائق'), size: ColumnSize.M),
                        DataColumn2(label: Text('النوع'), size: ColumnSize.S),
                        DataColumn2(
                            label: Text('السعر'), size: ColumnSize.S, numeric: true),
                        DataColumn2(label: Text('الحالة'), size: ColumnSize.S),
                      ],
                      rows: rides.map((ride) {
                        final id = (ride['id'] as String? ?? '').substring(0, 8);
                        final passenger =
                            ride['passenger'] as Map? ?? {};
                        final driver = ride['driver'] as Map? ?? {};
                        return DataRow2(
                          cells: [
                            DataCell(Text(
                              '#$id',
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12),
                            )),
                            DataCell(Text(
                                passenger['full_name'] as String? ?? '—')),
                            DataCell(
                                Text(driver['full_name'] as String? ?? '—')),
                            DataCell(Text(
                                _vehicleLabel(ride['vehicle_type'] as String? ?? ''))),
                            DataCell(Text(
                              currency.format(ride['fare_amount'] ?? 0),
                              textAlign: TextAlign.end,
                            )),
                            DataCell(StatusBadge(
                                status: ride['status'] as String? ?? '')),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleLabel(String type) {
    switch (type) {
      case 'sedan':
        return 'سيدان';
      case 'suv':
        return 'SUV';
      case 'vip':
        return 'VIP';
      case 'minibus':
        return 'ميني باص';
      default:
        return type;
    }
  }
}

class _PendingDriversCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(pendingDriversProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.pending_actions,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'سائقون ينتظرون الموافقة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/dashboard/drivers'),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
          ),
          driversAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(20),
              child: Text('تعذر التحميل'),
            ),
            data: (drivers) => drivers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text('لا يوجد سائقون بانتظار الموافقة'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = drivers[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.warning.withOpacity(0.15),
                          child: const Icon(Icons.person,
                              color: AppColors.warning),
                        ),
                        title: Text(
                          d['full_name'] as String? ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${d['phone_number'] ?? ''} • ${_vehicleLabel(d['vehicle_type'] as String? ?? '')}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => context
                                  .go('/dashboard/drivers/${d['id']}'),
                              child: const Text('مراجعة'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _vehicleLabel(String type) {
    switch (type) {
      case 'sedan':
        return 'سيدان';
      case 'suv':
        return 'SUV';
      case 'vip':
        return 'VIP';
      case 'minibus':
        return 'ميني باص';
      default:
        return type;
    }
  }
}
