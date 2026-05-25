import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride/data/datasources/ride_remote_datasource.dart';
import '../../../ride/domain/entities/earnings_entity.dart';

// ---------------------------------------------------------------------------
// Local providers for earnings screen
// ---------------------------------------------------------------------------

final _earningsPeriodProvider =
    StateProvider<String>((ref) => 'today');

final _earningsDataProvider =
    FutureProvider.family<EarningsEntity, String>((ref, period) async {
  final supabase = ref.watch(supabaseClientProvider);
  final driverId = supabase.auth.currentUser?.id ?? '';
  final datasource = RideRemoteDatasourceImpl(supabase);
  return datasource.getEarnings(driverId, period);
});

// ---------------------------------------------------------------------------
// EarningsScreen
// ---------------------------------------------------------------------------

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = const [
    (label: 'اليوم', period: 'today'),
    (label: 'الأسبوع', period: 'week'),
    (label: 'الشهر', period: 'month'),
    (label: 'الكل', period: 'all'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(_earningsPeriodProvider.notifier).state =
            _tabs[_tabController.index].period;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(_earningsPeriodProvider);
    final earningsAsync = ref.watch(_earningsDataProvider(period));

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرباحي'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) {
          return _EarningsTabContent(
            period: t.period,
            earningsAsync: ref.watch(_earningsDataProvider(t.period)),
          );
        }).toList(),
      ),
    );
  }
}

class _EarningsTabContent extends StatelessWidget {
  final String period;
  final AsyncValue<EarningsEntity> earningsAsync;

  const _EarningsTabContent({
    required this.period,
    required this.earningsAsync,
  });

  double _getTotalForPeriod(EarningsEntity e) {
    switch (period) {
      case 'today':
        return e.todayTotal;
      case 'week':
        return e.weekTotal;
      case 'month':
        return e.monthTotal;
      default:
        return e.allTimeTotal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return earningsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text('خطأ: ${e.toString()}'),
          ],
        ),
      ),
      data: (earnings) {
        final total = _getTotalForPeriod(earnings);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total amount card
            _TotalAmountCard(
              total: total,
              period: period,
            ),

            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'عدد الرحلات',
                    value: '${earnings.ridesCount}',
                    icon: Icons.directions_car_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'متوسط الرحلة',
                    value:
                        '${earnings.averagePerRide.toStringAsFixed(1)} ب',
                    icon: Icons.bar_chart,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Bar chart (last 7 days)
            if (earnings.dailyBreakdown.isNotEmpty) ...[
              const Text(
                'آخر 7 أيام',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: _BarChart(
                  earnings: earnings.dailyBreakdown.take(7).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Transaction list
            if (earnings.dailyBreakdown.isNotEmpty) ...[
              const Text(
                'تفاصيل الرحلات',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...earnings.dailyBreakdown.map((day) =>
                  _DayTransactionTile(earning: day)),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد رحلات في هذه الفترة',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _TotalAmountCard extends StatelessWidget {
  final double total;
  final String period;

  const _TotalAmountCard({required this.total, required this.period});

  String get _periodLabel {
    switch (period) {
      case 'today':
        return 'أرباح اليوم';
      case 'week':
        return 'أرباح الأسبوع';
      case 'month':
        return 'أرباح الشهر';
      default:
        return 'إجمالي الأرباح';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _periodLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, right: 4),
                child: Text(
                  'بر',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTransactionTile extends StatelessWidget {
  final DailyEarning earning;

  const _DayTransactionTile({required this.earning});

  String _formatDate(DateTime date) {
    const dayNames = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return '${dayNames[date.weekday - 1]} ${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final date = earning.date;
    final amount = earning.amount;
    final rides = earning.rides;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.directions_car,
              color: AppTheme.primaryColor, size: 22),
        ),
        title: Text(
          _formatDate(date),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$rides رحلة'),
        trailing: Text(
          '${amount.toStringAsFixed(0)} ب',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppTheme.onlineColor,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Bar Chart
// ---------------------------------------------------------------------------

class _BarChart extends StatelessWidget {
  final List<DailyEarning> earnings;

  const _BarChart({required this.earnings});

  @override
  Widget build(BuildContext context) {
    if (earnings.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      painter: _BarChartPainter(
        earnings: earnings,
        barColor: AppTheme.primaryColor,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyEarning> earnings;
  final Color barColor;

  _BarChartPainter({required this.earnings, required this.barColor});

  static const _dayNames = ['إث', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

  @override
  void paint(Canvas canvas, Size size) {
    if (earnings.isEmpty) return;

    final maxAmount = earnings
        .map((d) => d.amount)
        .reduce((a, b) => a > b ? a : b);

    if (maxAmount == 0) return;

    const labelHeight = 24.0;
    final chartHeight = size.height - labelHeight;
    final barWidth = (size.width / earnings.length) * 0.6;
    final gap = (size.width / earnings.length) * 0.4;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = barColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.rtl,
    );

    for (int i = 0; i < earnings.length; i++) {
      final amount = earnings[i].amount;
      final date = earnings[i].date;
      final barHeight = (amount / maxAmount) * chartHeight * 0.85;

      final left = i * (barWidth + gap) + gap / 2;
      final top = chartHeight - barHeight;

      // Background bar
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, barWidth, chartHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(bgRect, bgPaint);

      // Actual bar
      if (barHeight > 0) {
        final barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          const Radius.circular(6),
        );
        canvas.drawRRect(barRect, barPaint);
      }

      // Day label
      {
        final dayName = _dayNames[(date.weekday - 1) % 7];
        textPainter.text = TextSpan(
          text: dayName,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        );
        textPainter.layout(maxWidth: barWidth + 8);
        textPainter.paint(
          canvas,
          Offset(
            left + barWidth / 2 - textPainter.width / 2,
            chartHeight + 4,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.earnings != earnings || old.barColor != barColor;
}
