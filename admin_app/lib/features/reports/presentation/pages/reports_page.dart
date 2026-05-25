import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';

final _adminSvcProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

// ── Revenue by month ──────────────────────────────────────────────────────────
final monthlyRevenueProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final data = await ref.watch(_adminSvcProvider).getMonthlyRevenue();
  final Map<String, double> monthly = {};
  for (final row in data) {
    final date = DateTime.tryParse(row['created_at'] as String? ?? '');
    if (date == null) continue;
    final key = DateFormat('MMM').format(date);
    monthly[key] = (monthly[key] ?? 0) +
        (row['fare_amount'] as num? ?? 0).toDouble();
  }
  return monthly;
});

// ── Rides by vehicle type ─────────────────────────────────────────────────────
final ridesByVehicleTypeProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final data = await ref.watch(_adminSvcProvider).getRidesByVehicleType();
  final Map<String, int> counts = {};
  for (final row in data) {
    final type = row['vehicle_type'] as String? ?? 'other';
    counts[type] = (counts[type] ?? 0) + 1;
  }
  return counts;
});

// ── Subscription breakdown by plan ───────────────────────────────────────────
final subscriptionBreakdownProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final data = await ref.watch(_adminSvcProvider).getSubscriptionRevenue();
  final Map<String, int> counts = {};
  for (final row in data) {
    final plan = row['plan_type'] as String? ?? 'other';
    counts[plan] = (counts[plan] ?? 0) + 1;
  }
  return counts;
});

// ── Active drivers per day (last 30 days) ────────────────────────────────────
final driverActivityProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final data = await supabase
        .from('driver_locations')
        .select('updated_at')
        .gte('updated_at', since)
        .order('updated_at', ascending: true);

    final Map<String, Set<String>> byDay = {};
    for (final row in (data as List)) {
      final dt =
          DateTime.tryParse(row['updated_at'] as String? ?? '');
      if (dt == null) continue;
      final key = DateFormat('MM/dd').format(dt);
      byDay[key] ??= {};
      // Count unique dates as proxy for activity
      byDay[key]!.add(row['updated_at'] as String? ?? '');
    }
    return byDay.map((k, v) => MapEntry(k, v.length));
  } catch (_) {
    return {};
  }
});

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Row(
            children: [
              const Icon(Icons.bar_chart, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'التقارير والتحليلات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2x2 grid of report cards
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            final cardWidth = isWide
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Card 1: Revenue Report
                SizedBox(
                  width: cardWidth,
                  child: _RevenueReportCard(ref: ref),
                ),
                // Card 2: Rides by Vehicle Type
                SizedBox(
                  width: cardWidth,
                  child: _RidesStatisticsCard(ref: ref),
                ),
                // Card 3: Driver Activity
                SizedBox(
                  width: cardWidth,
                  child: _DriverActivityCard(ref: ref),
                ),
                // Card 4: Subscription Breakdown
                SizedBox(
                  width: cardWidth,
                  child: _SubscriptionBreakdownCard(ref: ref),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Card 1: Revenue Report (BarChart) ─────────────────────────────────────────
class _RevenueReportCard extends StatelessWidget {
  final WidgetRef ref;
  const _RevenueReportCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final revenueAsync = ref.watch(monthlyRevenueProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'إيرادات الاشتراكات',
              icon: Icons.attach_money,
              color: AppColors.success,
              onExport: () => _exportCsv(context, 'revenue'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: revenueAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('تعذر تحميل البيانات',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(child: Text('لا توجد بيانات'));
                  }
                  final entries = data.entries.toList();
                  final maxY = entries
                      .map((e) => e.value)
                      .fold(0.0, (a, b) => a > b ? a : b);

                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.2,
                      barGroups: List.generate(entries.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value,
                              color: AppColors.success,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= entries.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                entries[idx].key,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) => Text(
                              value >= 1000
                                  ? '${(value / 1000).toStringAsFixed(0)}k'
                                  : value.toStringAsFixed(0),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportCsv(BuildContext context, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جارٍ تصدير CSV...')),
    );
  }
}

// ── Card 2: Rides Statistics (PieChart by vehicle type) ───────────────────────
class _RidesStatisticsCard extends StatelessWidget {
  final WidgetRef ref;
  const _RidesStatisticsCard({required this.ref});

  static const _typeColors = {
    'sedan': AppColors.primary,
    'suv': AppColors.secondary,
    'vip': AppColors.tertiary,
    'minibus': AppColors.info,
    'other': AppColors.textSecondary,
  };

  static const _typeLabels = {
    'sedan': 'سيدان',
    'suv': 'دفع رباعي',
    'vip': 'VIP',
    'minibus': 'ميني باص',
    'other': 'أخرى',
  };

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(ridesByVehicleTypeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'إحصائيات الرحلات',
              icon: Icons.directions_car,
              color: AppColors.primary,
              onExport: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('جارٍ تصدير CSV...'))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: ridesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                    child: Text('تعذر تحميل البيانات')),
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(child: Text('لا توجد بيانات'));
                  }
                  final total =
                      data.values.fold(0, (a, b) => a + b);
                  final entries = data.entries.toList();

                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sections: List.generate(entries.length, (i) {
                              final e = entries[i];
                              final color = _typeColors[e.key] ??
                                  AppColors.textSecondary;
                              final pct =
                                  total > 0 ? e.value / total * 100 : 0.0;
                              return PieChartSectionData(
                                value: e.value.toDouble(),
                                color: color,
                                title: '${pct.toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                radius: 70,
                              );
                            }),
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entries.map((e) {
                            final color =
                                _typeColors[e.key] ?? AppColors.textSecondary;
                            final label =
                                _typeLabels[e.key] ?? e.key;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(label,
                                      style: const TextStyle(fontSize: 11)),
                                  const Spacer(),
                                  Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
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
}

// ── Card 3: Driver Activity (LineChart, last 30 days) ─────────────────────────
class _DriverActivityCard extends StatelessWidget {
  final WidgetRef ref;
  const _DriverActivityCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(driverActivityProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'نشاط السائقين',
              icon: Icons.people,
              color: AppColors.info,
              onExport: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('جارٍ تصدير CSV...'))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: activityAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                    child: Text('تعذر تحميل البيانات')),
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(
                        child: Text('لا توجد بيانات للـ 30 يوم الأخيرة'));
                  }
                  final entries = data.entries.toList();
                  final maxY = entries
                      .map((e) => e.value.toDouble())
                      .fold(0.0, (a, b) => a > b ? a : b);

                  final spots = List.generate(
                    entries.length,
                    (i) => FlSpot(i.toDouble(), entries[i].value.toDouble()),
                  );

                  return LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.info,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.info.withOpacity(0.1),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (entries.length / 5).ceilToDouble(),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= entries.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                entries[idx].key,
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (entries.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY * 1.2,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card 4: Subscription Breakdown (PieChart by plan) ─────────────────────────
class _SubscriptionBreakdownCard extends StatelessWidget {
  final WidgetRef ref;
  const _SubscriptionBreakdownCard({required this.ref});

  static const _planColors = {
    'daily': AppColors.tertiary,
    'weekly': AppColors.primary,
    'monthly': AppColors.secondary,
    'other': AppColors.textSecondary,
  };

  static const _planLabels = {
    'daily': 'يومي',
    'weekly': 'أسبوعي',
    'monthly': 'شهري',
    'other': 'أخرى',
  };

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(subscriptionBreakdownProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'توزيع الاشتراكات',
              icon: Icons.card_membership,
              color: AppColors.secondary,
              onExport: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('جارٍ تصدير CSV...'))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: subsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                    child: Text('تعذر تحميل البيانات')),
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(child: Text('لا توجد بيانات'));
                  }
                  final total =
                      data.values.fold(0, (a, b) => a + b);
                  final entries = data.entries.toList();

                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sections: List.generate(entries.length, (i) {
                              final e = entries[i];
                              final color = _planColors[e.key] ??
                                  AppColors.textSecondary;
                              final pct =
                                  total > 0 ? e.value / total * 100 : 0.0;
                              return PieChartSectionData(
                                value: e.value.toDouble(),
                                color: color,
                                title: '${pct.toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                radius: 70,
                              );
                            }),
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entries.map((e) {
                            final color =
                                _planColors[e.key] ?? AppColors.textSecondary;
                            final label = _planLabels[e.key] ?? e.key;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(label,
                                      style: const TextStyle(fontSize: 11)),
                                  const Spacer(),
                                  Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
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
}

// ── Shared card header ─────────────────────────────────────────────────────────
class _CardHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onExport;

  const _CardHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download, size: 14),
          label: const Text('تصدير CSV', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
