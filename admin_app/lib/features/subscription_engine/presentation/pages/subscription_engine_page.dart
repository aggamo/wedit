import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('subscription_plans')
      .select()
      .order('sort_order')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final subscriptionSettingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('subscription_settings')
      .select()
      .order('key')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final freezeReasonsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('freeze_reasons')
      .select()
      .order('sort_order')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final activeFreezeProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('subscription_freezes')
      .select('*, profiles!driver_id(full_name), freeze_reasons(label_ar)')
      .isFilter('unfrozen_at', null)
      .order('frozen_at', ascending: false)
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final auditLogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('admin_audit_log')
      .select(
          '*, profiles!admin_id(full_name), profiles!target_driver_id(full_name)')
      .order('created_at', ascending: false)
      .limit(50)
      .then((r) => List<Map<String, dynamic>>.from(r));
});

// ─── Active Days Stats Provider ───────────────────────────────────────────────

final activeDaysStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final res = await Supabase.instance.client
      .from('active_day_logs')
      .select('driver_id, is_active_day')
      .eq('log_date', today);
  final list = List<Map<String, dynamic>>.from(res);
  final total = list.length;
  final withActive = list.where((r) => r['is_active_day'] == true).length;
  return {
    'total': total,
    'with_active': withActive,
    'without_active': total - withActive,
  };
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class SubscriptionEnginePage extends ConsumerWidget {
  const SubscriptionEnginePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'الخطط'),
                Tab(text: 'الإعدادات'),
                Tab(text: 'أسباب التجميد'),
                Tab(text: 'التجميدات النشطة'),
                Tab(text: 'الأيام النشطة'),
                Tab(text: 'سجل التدخل'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _PlansTab(),
                _SettingsTab(),
                _FreezeReasonsTab(),
                _ActiveFreezesTab(),
                _ActiveDaysTab(),
                _AuditLogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Plans ─────────────────────────────────────────────────────────────

class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل الخطط: $e',
        onRetry: () => ref.refresh(subscriptionPlansProvider),
      ),
      data: (plans) => Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 16,
            headingRowHeight: 48,
            dataRowHeight: 52,
            headingRowColor:
                WidgetStateProperty.all(AppColors.primary.withOpacity(0.06)),
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade100),
            ),
            columns: const [
              DataColumn2(label: Text('الخطة'), size: ColumnSize.L),
              DataColumn2(
                  label: Text('السعر'), size: ColumnSize.S, numeric: true),
              DataColumn2(
                  label: Text('الأيام النشطة'),
                  size: ColumnSize.S,
                  numeric: true),
              DataColumn2(
                  label: Text('عدم الانتهاء'), size: ColumnSize.S),
              DataColumn2(
                  label: Text('استخدام أيام نشطة'), size: ColumnSize.S),
              DataColumn2(label: Text('الفعّال'), size: ColumnSize.S),
              DataColumn2(label: Text('إجراء'), size: ColumnSize.S),
            ],
            rows: plans.map((plan) {
              return DataRow2(
                cells: [
                  DataCell(Text(plan['name_ar'] as String? ??
                      plan['name'] as String? ??
                      '—')),
                  DataCell(Text(
                    '${plan['price_etb'] ?? 0} ETB',
                    textAlign: TextAlign.end,
                  )),
                  DataCell(Text(
                    '${plan['active_days_total'] ?? '—'}',
                    textAlign: TextAlign.end,
                  )),
                  DataCell(_BoolChip(value: plan['no_expiry'] == true)),
                  DataCell(
                      _BoolChip(value: plan['use_active_days'] == true)),
                  DataCell(_BoolChip(value: plan['is_active'] == true)),
                  DataCell(
                    TextButton(
                      onPressed: () =>
                          _showEditPlanDialog(context, ref, plan),
                      child: const Text('تعديل'),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showEditPlanDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => _EditPlanDialog(plan: plan, ref: ref),
    );
  }
}

class _EditPlanDialog extends StatefulWidget {
  final Map<String, dynamic> plan;
  final WidgetRef ref;

  const _EditPlanDialog({required this.plan, required this.ref});

  @override
  State<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<_EditPlanDialog> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _activeDaysCtrl;
  late final TextEditingController _featuresCtrl;
  late bool _noExpiry;
  late bool _isActive;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
        text: '${widget.plan['price_etb'] ?? ''}');
    _activeDaysCtrl = TextEditingController(
        text: '${widget.plan['active_days_total'] ?? ''}');
    _featuresCtrl = TextEditingController(
        text: widget.plan['features'] != null
            ? const JsonEncoder.withIndent('  ')
                .convert(widget.plan['features'])
            : '{}');
    _noExpiry = widget.plan['no_expiry'] == true;
    _isActive = widget.plan['is_active'] == true;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _activeDaysCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      dynamic features;
      try {
        features = jsonDecode(_featuresCtrl.text.trim());
      } catch (_) {
        features = {};
      }
      await Supabase.instance.client.from('subscription_plans').update({
        'price_etb': double.tryParse(_priceCtrl.text.trim()),
        'active_days_total': int.tryParse(_activeDaysCtrl.text.trim()),
        'no_expiry': _noExpiry,
        'is_active': _isActive,
        'features': features,
      }).eq('id', widget.plan['id']);
      widget.ref.refresh(subscriptionPlansProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الخطة بنجاح'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          'تعديل الخطة: ${widget.plan['name_ar'] ?? widget.plan['name'] ?? ''}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'السعر (ETB)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _activeDaysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'الأيام النشطة الإجمالية',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('بدون انتهاء'),
                value: _noExpiry,
                onChanged: (v) => setState(() => _noExpiry = v),
              ),
              SwitchListTile(
                title: const Text('فعّال'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _featuresCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'المزايا (JSON)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

// ─── Tab 2: Settings ──────────────────────────────────────────────────────────

const _settingKeys = [
  'trial_duration_days',
  'active_day_min_rides',
  'active_day_min_hours',
  'freeze_max_times_per_month',
  'freeze_max_days_per_freeze',
  'inactive_xp_penalty_per_day',
  'inactive_level_decay_days',
  'late_sub_grace_days',
  'late_sub_xp_penalty_pct',
  'personal_goal_window_days',
  'personal_goal_multiplier',
];

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(subscriptionSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل الإعدادات: $e',
        onRetry: () => ref.refresh(subscriptionSettingsProvider),
      ),
      data: (settings) {
        final filtered = settings
            .where((s) => _settingKeys.contains(s['key']))
            .toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _SettingTile(setting: filtered[i], ref: ref),
        );
      },
    );
  }
}

class _SettingTile extends StatefulWidget {
  final Map<String, dynamic> setting;
  final WidgetRef ref;

  const _SettingTile({required this.setting, required this.ref});

  @override
  State<_SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<_SettingTile> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl =
        TextEditingController(text: '${widget.setting['value'] ?? ''}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final rawVal = _ctrl.text.trim();
      final numVal = num.tryParse(rawVal) ?? rawVal;
      await Supabase.instance.client
          .from('subscription_settings')
          .update({'value': numVal})
          .eq('key', widget.setting['key']);
      widget.ref.refresh(subscriptionSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الحفظ'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.setting['key'] as String? ?? '';
    final desc =
        widget.setting['description_ar'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(key,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (desc.isNotEmpty)
                    Text(desc,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: desc.isNotEmpty ? desc : key,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 3: Freeze Reasons ────────────────────────────────────────────────────

class _FreezeReasonsTab extends ConsumerStatefulWidget {
  const _FreezeReasonsTab();

  @override
  ConsumerState<_FreezeReasonsTab> createState() =>
      _FreezeReasonsTabState();
}

class _FreezeReasonsTabState extends ConsumerState<_FreezeReasonsTab> {
  final _addCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final label = _addCtrl.text.trim();
    if (label.isEmpty) return;
    setState(() => _adding = true);
    try {
      await Supabase.instance.client
          .from('freeze_reasons')
          .insert({'label_ar': label, 'sort_order': 999});
      _addCtrl.clear();
      ref.refresh(freezeReasonsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client
          .from('freeze_reasons')
          .delete()
          .eq('id', id);
      ref.refresh(freezeReasonsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasonsAsync = ref.watch(freezeReasonsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addCtrl,
                  decoration: const InputDecoration(
                    labelText: 'سبب تجميد جديد',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _adding ? null : _add,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: reasonsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorWidget(
                message: 'خطأ: $e',
                onRetry: () => ref.refresh(freezeReasonsProvider),
              ),
              data: (reasons) => reasons.isEmpty
                  ? const Center(child: Text('لا توجد أسباب تجميد'))
                  : ListView.separated(
                      itemCount: reasons.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = reasons[i];
                        return ListTile(
                          leading: const Icon(Icons.ac_unit,
                              color: AppColors.primary),
                          title: Text(r['label_ar'] as String? ?? '—'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18),
                                onPressed: () =>
                                    _showEditDialog(context, r),
                                tooltip: 'تعديل',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error),
                                onPressed: () =>
                                    _confirmDelete(context, r),
                                tooltip: 'حذف',
                              ),
                            ],
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

  void _showEditDialog(
      BuildContext context, Map<String, dynamic> reason) {
    final ctrl = TextEditingController(
        text: reason['label_ar'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل سبب التجميد'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'السبب', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client
                    .from('freeze_reasons')
                    .update({'label_ar': ctrl.text.trim()})
                    .eq('id', reason['id']);
                ref.refresh(freezeReasonsProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('خطأ: $e'),
                        backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, Map<String, dynamic> reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل تريد حذف سبب التجميد: ${reason['label_ar'] ?? ''}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _delete(reason['id'] as String);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 4: Active Freezes ────────────────────────────────────────────────────

class _ActiveFreezesTab extends ConsumerWidget {
  const _ActiveFreezesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freezesAsync = ref.watch(activeFreezeProvider);

    return freezesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل التجميدات: $e',
        onRetry: () => ref.refresh(activeFreezeProvider),
      ),
      data: (freezes) => Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: freezes.isEmpty
              ? const Center(child: Text('لا توجد تجميدات نشطة'))
              : DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 16,
                  headingRowHeight: 48,
                  dataRowHeight: 52,
                  headingRowColor: WidgetStateProperty.all(
                      AppColors.primary.withOpacity(0.06)),
                  border: TableBorder(
                      horizontalInside:
                          BorderSide(color: Colors.grey.shade100)),
                  columns: const [
                    DataColumn2(
                        label: Text('السائق'), size: ColumnSize.L),
                    DataColumn2(
                        label: Text('السبب'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('تاريخ التجميد'),
                        size: ColumnSize.M),
                    DataColumn2(
                        label: Text('إجراء'), size: ColumnSize.S),
                  ],
                  rows: freezes.map((f) {
                    final driver =
                        f['profiles'] as Map? ?? {};
                    final reason =
                        f['freeze_reasons'] as Map? ?? {};
                    final frozenAt = f['frozen_at'] != null
                        ? DateFormat('yyyy/MM/dd HH:mm')
                            .format(DateTime.parse(f['frozen_at']))
                        : '—';
                    return DataRow2(
                      cells: [
                        DataCell(Text(
                            driver['full_name'] as String? ?? '—')),
                        DataCell(Text(
                            reason['label_ar'] as String? ?? '—')),
                        DataCell(Text(frozenAt)),
                        DataCell(_UnfreezeButton(
                            freeze: f, ref: ref)),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}

class _UnfreezeButton extends StatefulWidget {
  final Map<String, dynamic> freeze;
  final WidgetRef ref;

  const _UnfreezeButton({required this.freeze, required this.ref});

  @override
  State<_UnfreezeButton> createState() => _UnfreezeButtonState();
}

class _UnfreezeButtonState extends State<_UnfreezeButton> {
  bool _loading = false;

  Future<void> _unfreeze() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إلغاء التجميد'),
        content: const Text('هل تريد إلغاء تجميد هذا السائق؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'unfreeze-subscription',
        body: {
          'freeze_id': widget.freeze['id'],
          'admin_override': true,
        },
      );
      widget.ref.refresh(activeFreezeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إلغاء التجميد بنجاح'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _unfreeze,
      style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
      child: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('إلغاء التجميد', style: TextStyle(fontSize: 12)),
    );
  }
}

// ─── Tab 5: Active Days ───────────────────────────────────────────────────────

class _ActiveDaysTab extends ConsumerWidget {
  const _ActiveDaysTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(activeDaysStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل الإحصائيات: $e',
        onRetry: () => ref.refresh(activeDaysStatsProvider),
      ),
      data: (stats) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إحصائيات اليوم',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'تحديث',
                        onPressed: () =>
                            ref.refresh(activeDaysStatsProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _StatRow(
                    label: 'إجمالي السائقين المعالجين اليوم',
                    value: '${stats['total']}',
                    color: AppColors.primary,
                  ),
                  const Divider(height: 24),
                  _StatRow(
                    label: 'عدد من تم احتساب يوم نشط لهم',
                    value: '${stats['with_active']}',
                    color: AppColors.success,
                  ),
                  const Divider(height: 24),
                  _StatRow(
                    label: 'عدد من لم يتم احتساب يوم نشط لهم',
                    value: '${stats['without_active']}',
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 22, color: color)),
      ],
    );
  }
}

// ─── Tab 6: Audit Log ─────────────────────────────────────────────────────────

class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab();

  String _translateAction(String? action) {
    switch (action) {
      case 'grant_sub_days':
        return 'منح أيام اشتراك';
      case 'grant_points':
        return 'منح نقاط';
      case 'grant_xp':
        return 'منح XP';
      case 'manual_freeze':
        return 'تجميد يدوي';
      case 'manual_unfreeze':
        return 'إلغاء تجميد يدوي';
      case 'status_change':
        return 'تغيير الحالة';
      case 'doc_approve':
        return 'قبول وثيقة';
      case 'doc_reject':
        return 'رفض وثيقة';
      default:
        return action ?? '—';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(auditLogProvider);

    return logAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل السجل: $e',
        onRetry: () => ref.refresh(auditLogProvider),
      ),
      data: (logs) => Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: logs.isEmpty
              ? const Center(child: Text('لا توجد سجلات'))
              : DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 16,
                  headingRowHeight: 48,
                  dataRowHeight: 52,
                  headingRowColor: WidgetStateProperty.all(
                      AppColors.primary.withOpacity(0.06)),
                  border: TableBorder(
                      horizontalInside:
                          BorderSide(color: Colors.grey.shade100)),
                  columns: const [
                    DataColumn2(
                        label: Text('المدير'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('السائق'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('الإجراء'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('قبل / بعد'),
                        size: ColumnSize.L),
                    DataColumn2(
                        label: Text('السبب'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('التاريخ'), size: ColumnSize.M),
                  ],
                  rows: logs.map((log) {
                    final adminProfiles =
                        log['profiles'] as Map? ?? {};
                    final driverProfiles =
                        log['profiles!target_driver_id'] as Map? ?? {};
                    final before = log['before_value'];
                    final after = log['after_value'];
                    return DataRow2(
                      cells: [
                        DataCell(Text(
                            adminProfiles['full_name'] as String? ??
                                '—')),
                        DataCell(Text(
                            driverProfiles['full_name'] as String? ??
                                '—')),
                        DataCell(Text(
                            _translateAction(
                                log['action_type'] as String?))),
                        DataCell(Text(
                          before != null || after != null
                              ? '${before ?? '—'} → ${after ?? '—'}'
                              : '—',
                          style: const TextStyle(fontSize: 12),
                        )),
                        DataCell(Text(log['reason'] as String? ?? '—')),
                        DataCell(Text(log['created_at'] != null
                            ? DateFormat('yyyy/MM/dd HH:mm').format(
                                DateTime.parse(log['created_at']))
                            : '—')),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _BoolChip extends StatelessWidget {
  final bool value;
  const _BoolChip({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: value
            ? AppColors.success.withOpacity(0.12)
            : AppColors.error.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value ? 'نعم' : 'لا',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: value ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
