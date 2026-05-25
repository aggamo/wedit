import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/stat_card.dart';

final _adminSvcProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

final _referralStatusFilterProvider = StateProvider<String>((ref) => 'all');

final referralsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final status = ref.watch(_referralStatusFilterProvider);
  return ref.watch(_adminSvcProvider).getReferrals(
        status: status == 'all' ? null : status,
        pageSize: 100,
      );
});

final referralStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final all = await supabase
        .from('referrals')
        .select('id', const FetchOptions(count: CountOption.exact, head: true));

    final rewarded = await supabase
        .from('referrals')
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('status', 'rewarded');

    final pointsData = await supabase
        .from('referrals')
        .select('reward_points')
        .eq('status', 'rewarded');

    int totalPoints = 0;
    for (final r in (pointsData as List)) {
      totalPoints += (r['reward_points'] as num? ?? 0).toInt();
    }

    return {
      'total': all.count ?? 0,
      'rewarded': rewarded.count ?? 0,
      'total_points': totalPoints,
    };
  } catch (_) {
    return {'total': 0, 'rewarded': 0, 'total_points': 0};
  }
});

class ReferralsPage extends ConsumerWidget {
  const ReferralsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralsAsync = ref.watch(referralsProvider);
    final statsAsync = ref.watch(referralStatsProvider);
    final currentFilter = ref.watch(_referralStatusFilterProvider);
    final dateFormat = DateFormat('yyyy/MM/dd');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Row(
            children: [
              const Icon(Icons.share, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'الإحالات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Summary Stats Row ───────────────────────────────────────────────
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth > 900
                          ? (constraints.maxWidth - 32) / 3
                          : constraints.maxWidth > 600
                              ? (constraints.maxWidth - 16) / 2
                              : constraints.maxWidth,
                      child: StatCard(
                        title: 'إجمالي الإحالات',
                        value: '${stats['total']}',
                        icon: Icons.people_alt,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth > 900
                          ? (constraints.maxWidth - 32) / 3
                          : constraints.maxWidth > 600
                              ? (constraints.maxWidth - 16) / 2
                              : constraints.maxWidth,
                      child: StatCard(
                        title: 'الإحالات المكافأة',
                        value: '${stats['rewarded']}',
                        icon: Icons.card_giftcard,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth > 900
                          ? (constraints.maxWidth - 32) / 3
                          : constraints.maxWidth > 600
                              ? (constraints.maxWidth - 16) / 2
                              : constraints.maxWidth,
                      child: StatCard(
                        title: 'إجمالي النقاط الممنوحة',
                        value: '${stats['total_points']}',
                        icon: Icons.stars,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── Referrals Table ─────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.table_chart, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'قائمة الإحالات',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const Spacer(),
                      // Status filter dropdown
                      DropdownButton<String>(
                        value: currentFilter,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(8),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                          DropdownMenuItem(value: 'pending', child: Text('معلق')),
                          DropdownMenuItem(
                              value: 'completed', child: Text('مكتمل')),
                          DropdownMenuItem(value: 'rewarded', child: Text('مكافأ')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            ref
                                .read(_referralStatusFilterProvider.notifier)
                                .state = v;
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'تحديث',
                        onPressed: () => ref.refresh(referralsProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  referralsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'تعذر تحميل الإحالات: $e',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    data: (referrals) => referrals.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.share,
                                      size: 48, color: AppColors.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'لا توجد إحالات',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 450,
                            child: DataTable2(
                              columnSpacing: 12,
                              horizontalMargin: 16,
                              headingRowHeight: 48,
                              dataRowHeight: 54,
                              border: TableBorder(
                                horizontalInside:
                                    BorderSide(color: Colors.grey.shade100),
                              ),
                              headingRowColor: WidgetStateProperty.all(
                                AppColors.primary.withOpacity(0.04),
                              ),
                              columns: const [
                                DataColumn2(
                                    label: Text('المُحيل'),
                                    size: ColumnSize.L),
                                DataColumn2(
                                    label: Text('المُحال'), size: ColumnSize.L),
                                DataColumn2(
                                    label: Text('نوع المُحيل'),
                                    size: ColumnSize.M),
                                DataColumn2(
                                    label: Text('الحالة'), size: ColumnSize.M),
                                DataColumn2(
                                    label: Text('النقاط'),
                                    size: ColumnSize.S,
                                    numeric: true),
                                DataColumn2(
                                    label: Text('التاريخ'),
                                    size: ColumnSize.M),
                              ],
                              rows: referrals.map((r) {
                                final referrer =
                                    r['referrer'] as Map? ?? {};
                                final referred =
                                    r['referred'] as Map? ?? {};
                                final status =
                                    r['status'] as String? ?? 'pending';
                                final referrerType =
                                    r['referrer_type'] as String? ?? '—';
                                final points =
                                    (r['reward_points'] as num? ?? 0).toInt();
                                final createdAt = r['created_at'] != null
                                    ? dateFormat.format(
                                        DateTime.parse(r['created_at']))
                                    : '—';

                                return DataRow2(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: AppColors.primary
                                                .withOpacity(0.1),
                                            child: const Icon(Icons.person,
                                                size: 14,
                                                color: AppColors.primary),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            referrer['full_name']
                                                    as String? ??
                                                '—',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        referred['full_name'] as String? ?? '—',
                                      ),
                                    ),
                                    DataCell(
                                      _buildReferrerTypeChip(referrerType),
                                    ),
                                    DataCell(_buildStatusChip(status)),
                                    DataCell(
                                      points > 0
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.tertiary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$points نقطة',
                                                style: const TextStyle(
                                                  color: AppColors.tertiary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                          : const Text('—'),
                                    ),
                                    DataCell(Text(createdAt)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferrerTypeChip(String type) {
    final (label, color) = switch (type) {
      'driver' => ('سائق', AppColors.primary),
      'passenger' => ('راكب', AppColors.secondary),
      _ => (type, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final (label, color, icon) = switch (status) {
      'pending' => ('معلق', AppColors.warning, Icons.pending),
      'completed' => ('مكتمل', AppColors.info, Icons.check),
      'rewarded' => ('مكافأ', AppColors.success, Icons.card_giftcard),
      _ => (status, AppColors.textSecondary, Icons.help_outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}
