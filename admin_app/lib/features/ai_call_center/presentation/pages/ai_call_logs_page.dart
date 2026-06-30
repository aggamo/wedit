import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../providers/ai_call_provider.dart';

class AiCallLogsPage extends ConsumerWidget {
  const AiCallLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(aiCallStatsProvider);
    final logsAsync  = ref.watch(aiCallLogsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 1,
              title: const Text(
                'سجل مكالمات المساعد الصوتي',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                  onPressed: () {
                    ref.invalidate(aiCallLogsProvider);
                    ref.invalidate(aiCallStatsProvider);
                  },
                ),
              ],
            ),

            // ── Stats row ───────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: statsAsync.when(
                  loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                  error:   (e, _) => Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
                  data:    (stats) => _StatsRow(stats: stats),
                ),
              ),
            ),

            // ── Logs table ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: logsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  )),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Text('خطأ في تحميل البيانات: $e',
                        style: const TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
                data: (logs) => logs.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(Icons.record_voice_over_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('لا توجد مكالمات بعد',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: Colors.grey,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _LogCard(log: logs[i]),
                          childCount: logs.length,
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

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total       = stats['total'] as int;
    final dispatched  = stats['dispatched'] as int;
    final successRate = (stats['success_rate'] as double) * 100;
    final avgConf     = (stats['avg_confidence'] as double) * 100;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          label: 'مكالمات اليوم',
          value: '$total',
          icon: Icons.phone_in_talk,
          color: Colors.blue,
        ),
        _StatCard(
          label: 'تم الإرسال',
          value: '$dispatched',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        _StatCard(
          label: 'نسبة النجاح',
          value: '${successRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: successRate >= 70 ? Colors.green : Colors.orange,
        ),
        _StatCard(
          label: 'متوسط الدقة',
          value: '${avgConf.toStringAsFixed(1)}%',
          icon: Icons.psychology_outlined,
          color: avgConf >= 70 ? Colors.teal : Colors.orange,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Log Card ─────────────────────────────────────────────────────────────────

class _LogCard extends ConsumerWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  Color _statusColor(String status) {
    switch (status) {
      case 'dispatched': return Colors.green;
      case 'no_driver':  return Colors.orange;
      case 'failed':     return Colors.red;
      default:           return Colors.blue;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'dispatched':  return 'تم الإرسال';
      case 'no_driver':   return 'لا سائق';
      case 'failed':      return 'فشل';
      case 'in_progress': return 'جارٍ';
      default:            return status;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status        = log['status'] as String? ?? '';
    final phone         = log['passenger_phone'] as String? ?? '';
    final pickupText    = log['pickup_text'] as String? ?? '';
    final destText      = log['destination_text'] as String? ?? '';
    final confidence    = log['confidence_score'] as num?;
    final createdAt     = log['created_at'] as String? ?? '';
    final rideId        = log['ride_id'] as String?;
    final retryCount    = log['retry_count'] as int? ?? 0;

    DateTime? parsedDate;
    try { parsedDate = DateTime.parse(createdAt).toLocal(); } catch (_) {}
    final dateStr = parsedDate != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(parsedDate)
        : createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Pickup / destination
            if (pickupText.isNotEmpty)
              _DetailRow(icon: Icons.location_on, color: Colors.red,
                  label: 'الموقع', value: pickupText),
            if (destText.isNotEmpty)
              _DetailRow(icon: Icons.flag, color: Colors.blue,
                  label: 'الوجهة', value: destText),
            if (confidence != null)
              _DetailRow(
                icon: Icons.psychology,
                color: confidence >= 0.7 ? Colors.teal : Colors.orange,
                label: 'دقة الفهم',
                value: '${(confidence * 100).toStringAsFixed(1)}%',
              ),
            if (retryCount > 0)
              _DetailRow(icon: Icons.replay, color: Colors.grey,
                  label: 'محاولات إعادة', value: '$retryCount'),
            if (rideId != null)
              _DetailRow(icon: Icons.tag, color: Colors.indigo,
                  label: 'رقم الرحلة', value: rideId.substring(0, 8).toUpperCase()),

            // Retry button for failed/no_driver calls
            if (status == 'no_driver' || status == 'failed') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _retryManually(context, log),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'إعادة الإرسال يدوياً',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _retryManually(BuildContext context, Map<String, dynamic> log) {
    // Navigate to call center page pre-filled with detected location
    final pickupLat = log['pickup_lat'] as num?;
    final pickupLng = log['pickup_lng'] as num?;

    context.go('/dashboard/call-center', extra: {
      'passengerPhone':  log['passenger_phone'] ?? '',
      'pickupAddress':   log['pickup_text'] ?? '',
      'pickupLat':       pickupLat?.toDouble(),
      'pickupLng':       pickupLng?.toDouble(),
    });
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
