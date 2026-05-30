import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetAnalyticsScreen extends ConsumerStatefulWidget {
  const FleetAnalyticsScreen({super.key});

  @override
  ConsumerState<FleetAnalyticsScreen> createState() =>
      _FleetAnalyticsScreenState();
}

class _FleetAnalyticsScreenState extends ConsumerState<FleetAnalyticsScreen> {
  final ownerId = Supabase.instance.client.auth.currentUser!.id;
  String _period = 'week'; // today | week | month
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final assignments =
          await ref.read(fleetRepositoryProvider).getAssignments(ownerId);

      final now = DateTime.now();
      final DateTime start;
      switch (_period) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'month':
          start = DateTime(now.year, now.month, 1);
          break;
        default:
          start = now.subtract(Duration(days: now.weekday - 1));
      }

      final rows = <Map<String, dynamic>>[];
      for (final a in assignments) {
        final rides = await Supabase.instance.client
            .from('rides')
            .select('final_price, rating_by_passenger, status, completed_at')
            .eq('driver_id', a.driverId)
            .inFilter('status', ['completed', 'cancelled'])
            .gte('created_at', start.toIso8601String());

        final completed =
            (rides as List).where((r) => r['status'] == 'completed').toList();
        final cancelled =
            rides.where((r) => r['status'] == 'cancelled').toList();
        final totalFare = completed.fold(
            0.0, (sum, r) => sum + ((r['final_price'] as num?)?.toDouble() ?? 0));
        final avgRating = completed.isEmpty
            ? 0.0
            : completed.fold(
                    0.0,
                    (sum, r) =>
                        sum +
                        ((r['rating_by_passenger'] as num?)?.toDouble() ?? 0)) /
                completed.length;
        final cancelRate = rides.isEmpty
            ? 0.0
            : cancelled.length / rides.length * 100;

        rows.add({
          'name': a.driverName.isEmpty ? a.driverPhone : a.driverName,
          'rides': completed.length,
          'fare': totalFare,
          'rating': avgRating,
          'cancel_rate': cancelRate,
        });
      }

      if (mounted) setState(() => _rows = rows);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحليل أداء السائقين'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'today', label: Text('اليوم')),
                ButtonSegment(value: 'week', label: Text('الأسبوع')),
                ButtonSegment(value: 'month', label: Text('الشهر')),
              ],
              selected: {_period},
              onSelectionChanged: (s) {
                setState(() => _period = s.first);
                _load();
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('لا توجد بيانات'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('السائق')),
                      DataColumn(label: Text('الرحلات')),
                      DataColumn(label: Text('الإيرادات (بر)')),
                      DataColumn(label: Text('التقييم')),
                      DataColumn(label: Text('نسبة الإلغاء %')),
                    ],
                    rows: _rows
                        .map(
                          (r) => DataRow(cells: [
                            DataCell(Text(r['name'] as String)),
                            DataCell(Text('${r['rides']}')),
                            DataCell(Text(
                                (r['fare'] as double).toStringAsFixed(0))),
                            DataCell(Text(
                                (r['rating'] as double).toStringAsFixed(1))),
                            DataCell(Text(
                                '${(r['cancel_rate'] as double).toStringAsFixed(1)}%')),
                          ]),
                        )
                        .toList(),
                  ),
                ),
    );
  }
}
