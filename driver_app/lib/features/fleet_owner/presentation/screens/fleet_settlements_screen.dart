import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetSettlementsScreen extends ConsumerStatefulWidget {
  const FleetSettlementsScreen({super.key});

  @override
  ConsumerState<FleetSettlementsScreen> createState() =>
      _FleetSettlementsScreenState();
}

class _FleetSettlementsScreenState
    extends ConsumerState<FleetSettlementsScreen> {
  final ownerId = Supabase.instance.client.auth.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(fleetAssignmentsProvider(ownerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('التسوية والتقارير'),
        automaticallyImplyLeading: false,
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Center(
                child: Text('لا يوجد سائقون لعرض تسوياتهم'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final a = assignments[index];
              return _SettlementCard(
                assignment: a,
                ownerId: ownerId,
                onRefresh: () =>
                    ref.invalidate(fleetAssignmentsProvider(ownerId)),
              );
            },
          );
        },
      ),
    );
  }
}

class _SettlementCard extends ConsumerStatefulWidget {
  final dynamic assignment;
  final String ownerId;
  final VoidCallback onRefresh;

  const _SettlementCard({
    required this.assignment,
    required this.ownerId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends ConsumerState<_SettlementCard> {
  Map<String, double>? _calc;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCalculation();
  }

  Future<void> _loadCalculation() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      switch (widget.assignment.settlementCycle) {
        case 'daily':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'monthly':
          start = DateTime(now.year, now.month, 1);
          break;
        default: // weekly
          start = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
      }
      final result =
          await ref.read(fleetRepositoryProvider).calculateSettlement(
                assignmentId: widget.assignment.id,
                periodStart: start,
                periodEnd: now,
              );
      if (mounted) setState(() => _calc = result);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.driverName.isEmpty ? a.driverPhone : a.driverName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_calc != null) ...[
              _Row('إجمالي الرحلات',
                  '${_calc!['total_fare']!.toStringAsFixed(0)} بر'),
              _Row('حصة المالك',
                  '${_calc!['owner_share']!.toStringAsFixed(0)} بر'),
              _Row('حصة السائق',
                  '${_calc!['driver_share']!.toStringAsFixed(0)} بر'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _waive(a.id),
                      child: const Text('تنازل عن المستحق'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _confirmReceipt(a.id),
                      child: const Text('تأكيد الاستلام'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _waive(String assignmentId) async {
    // Upsert settlement then waive
    await _saveAndWaive(assignmentId, waive: true);
  }

  Future<void> _confirmReceipt(String assignmentId) async {
    await _saveAndWaive(assignmentId, waive: false, confirm: true);
  }

  Future<void> _saveAndWaive(String assignmentId,
      {bool waive = false, bool confirm = false}) async {
    if (_calc == null) return;
    final now = DateTime.now();
    try {
      await ref.read(fleetRepositoryProvider).upsertSettlement(
            fleetOwnerId: widget.ownerId,
            assignmentId: assignmentId,
            periodStart: now.subtract(const Duration(days: 7)),
            periodEnd: now,
            totalFare: _calc!['total_fare']!,
            ownerShare: _calc!['owner_share']!,
            driverShare: _calc!['driver_share']!,
          );

      final settlements =
          await ref.read(fleetRepositoryProvider).getSettlements(widget.ownerId);
      final s = settlements.isNotEmpty ? settlements.first : null;

      if (s != null) {
        if (waive) {
          await ref.read(fleetRepositoryProvider).waiveSettlement(s.id);
        }
        if (confirm) {
          await ref.read(fleetRepositoryProvider).confirmSettlementReceipt(s.id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(waive
                ? 'تم التنازل عن المستحق'
                : 'تم تأكيد الاستلام')));
        _loadCalculation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
