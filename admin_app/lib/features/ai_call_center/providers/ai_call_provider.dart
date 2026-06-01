import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/admin_provider.dart';

/// Fetch ai_call_logs ordered by newest first.
final aiCallLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('ai_call_logs')
      .select('*, rides(id, status)')
      .order('created_at', ascending: false)
      .limit(200);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Today's stats derived from ai_call_logs.
final aiCallStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

  final response = await supabase
      .from('ai_call_logs')
      .select('status, confidence_score')
      .gte('created_at', startOfDay);

  final logs = (response as List).cast<Map<String, dynamic>>();
  final total = logs.length;
  final dispatched = logs.where((l) => l['status'] == 'dispatched').length;
  final avgConfidence = total == 0
      ? 0.0
      : logs
              .where((l) => l['confidence_score'] != null)
              .map((l) => (l['confidence_score'] as num).toDouble())
              .fold(0.0, (a, b) => a + b) /
          (logs.where((l) => l['confidence_score'] != null).length.toDouble().clamp(1, double.infinity));

  return {
    'total': total,
    'dispatched': dispatched,
    'success_rate': total == 0 ? 0.0 : dispatched / total,
    'avg_confidence': avgConfidence,
  };
});
