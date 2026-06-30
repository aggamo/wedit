import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/fleet_provider.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _Settlement {
  final String id;
  final String driverId;
  final String driverName;
  final double totalFare;
  final double ownerShare;
  final double driverShare;
  final String? receiptUrl;
  final bool isWaived;
  final DateTime createdAt;

  const _Settlement({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.totalFare,
    required this.ownerShare,
    required this.driverShare,
    this.receiptUrl,
    required this.isWaived,
    required this.createdAt,
  });

  bool get isPaid => receiptUrl != null && receiptUrl!.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Period provider
// ---------------------------------------------------------------------------

final _settlementPeriodProvider = StateProvider<String>((ref) => 'today');

// ---------------------------------------------------------------------------
// Settlements data provider
// ---------------------------------------------------------------------------

final _settlementsProvider =
    FutureProvider.family<List<_Settlement>, String>((ref, period) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ownerId = ref.watch(fleetOwnerIdProvider);
  if (ownerId.isEmpty) return [];

  final now = DateTime.now();
  DateTime startDate;
  switch (period) {
    case 'today':
      startDate = DateTime(now.year, now.month, now.day);
      break;
    case 'week':
      startDate = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      break;
    case 'month':
      startDate = DateTime(now.year, now.month, 1);
      break;
    default:
      startDate = DateTime(now.year, now.month, now.day);
  }

  final data = await supabase
      .from('fleet_owner_settlements')
      .select('id, driver_id, total_fare, owner_share, driver_share, receipt_url, is_waived, created_at, profiles(full_name)')
      .eq('fleet_owner_id', ownerId)
      .gte('created_at', startDate.toIso8601String())
      .order('created_at', ascending: false);

  return (data as List).map((row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return _Settlement(
      id: row['id'] as String,
      driverId: row['driver_id'] as String,
      driverName: (profile?['full_name'] as String?) ?? 'سائق',
      totalFare: (row['total_fare'] as num?)?.toDouble() ?? 0,
      ownerShare: (row['owner_share'] as num?)?.toDouble() ?? 0,
      driverShare: (row['driver_share'] as num?)?.toDouble() ?? 0,
      receiptUrl: row['receipt_url'] as String?,
      isWaived: (row['is_waived'] as bool?) ?? false,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }).toList();
});

// ---------------------------------------------------------------------------
// FleetSettlementsScreen
// ---------------------------------------------------------------------------

class FleetSettlementsScreen extends ConsumerWidget {
  const FleetSettlementsScreen({super.key});

  static const _periods = [
    ('today', 'اليوم'),
    ('week', 'هذا الأسبوع'),
    ('month', 'هذا الشهر'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_settlementPeriodProvider);
    final settlementsAsync = ref.watch(_settlementsProvider(period));

    return Scaffold(
      appBar: AppBar(title: const Text('التسويات')),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: _periods.map((p) {
                final isSelected = period == p.$1;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(_settlementPeriodProvider.notifier).state = p.$1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Summary header
          settlementsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (settlements) {
              final totalFare =
                  settlements.fold<double>(0, (s, e) => s + e.totalFare);
              final ownerTotal =
                  settlements.fold<double>(0, (s, e) => s + e.ownerShare);
              final driverTotal =
                  settlements.fold<double>(0, (s, e) => s + e.driverShare);
              return _SummaryHeader(
                totalFare: totalFare,
                ownerTotal: ownerTotal,
                driverTotal: driverTotal,
              );
            },
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(_settlementsProvider(period)),
              child: settlementsAsync.when(
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
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(_settlementsProvider(period)),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
                data: (settlements) {
                  if (settlements.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('لا توجد تسويات في هذه الفترة',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: settlements.length,
                    itemBuilder: (_, i) => _SettlementCard(
                      settlement: settlements[i],
                      onWaive: settlements[i].isWaived
                          ? null
                          : () async {
                              await ref
                                  .read(fleetNotifierProvider.notifier)
                                  .waiveSettlement(settlements[i].id);
                              ref.invalidate(_settlementsProvider(period));
                            },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _SummaryHeader extends StatelessWidget {
  final double totalFare;
  final double ownerTotal;
  final double driverTotal;

  const _SummaryHeader({
    required this.totalFare,
    required this.ownerTotal,
    required this.driverTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'إجمالي الأجور',
              value: '${totalFare.toStringAsFixed(0)} ب',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white38),
          Expanded(
            child: _SummaryItem(
              label: 'حصتك',
              value: '${ownerTotal.toStringAsFixed(0)} ب',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white38),
          Expanded(
            child: _SummaryItem(
              label: 'حصة السائقين',
              value: '${driverTotal.toStringAsFixed(0)} ب',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final _Settlement settlement;
  final VoidCallback? onWaive;

  const _SettlementCard({required this.settlement, this.onWaive});

  @override
  Widget build(BuildContext context) {
    final s = settlement;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.driverName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (s.isWaived)
                  _StatusBadge(label: 'تنازل', color: Colors.purple)
                else if (s.isPaid)
                  _StatusBadge(label: 'مدفوع', color: AppTheme.onlineColor)
                else
                  _StatusBadge(label: 'غير مدفوع', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AmountItem(
                    label: 'إجمالي الأجرة',
                    value: '${s.totalFare.toStringAsFixed(0)} ب',
                    valueColor: Colors.black87,
                  ),
                ),
                Expanded(
                  child: _AmountItem(
                    label: 'حصة المالك',
                    value: '${s.ownerShare.toStringAsFixed(0)} ب',
                    valueColor: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: _AmountItem(
                    label: 'حصة السائق',
                    value: '${s.driverShare.toStringAsFixed(0)} ب',
                    valueColor: AppTheme.onlineColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            if (onWaive != null && !s.isWaived && !s.isPaid) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: onWaive,
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('تنازل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _AmountItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _AmountItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

