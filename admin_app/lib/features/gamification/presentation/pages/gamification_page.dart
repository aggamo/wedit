import 'dart:convert';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final levelDefinitionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('level_definitions')
      .select()
      .order('min_xp')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final pointRulesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('point_earning_rules')
      .select()
      .order('created_at')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final xpRulesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('xp_earning_rules')
      .select()
      .order('created_at')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final streakConfigsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('streak_configs')
      .select('*, streak_milestones(*)')
      .order('type')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final rewardBoxesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('reward_boxes')
      .select('*, box_prizes(*)')
      .order('created_at', ascending: false)
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final redemptionOptionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('redemption_options')
      .select()
      .order('created_at')
      .then((r) => List<Map<String, dynamic>>.from(r));
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class GamificationPage extends ConsumerWidget {
  const GamificationPage({super.key});

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
                Tab(text: 'المستويات'),
                Tab(text: 'قواعد النقاط'),
                Tab(text: 'قواعد XP'),
                Tab(text: 'سلسلة النشاط'),
                Tab(text: 'صناديق المكافآت'),
                Tab(text: 'متجر الاستبدال'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _LevelsTab(),
                _PointRulesTab(),
                _XpRulesTab(),
                _StreakConfigTab(),
                _RewardBoxesTab(),
                _RedemptionOptionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Levels ────────────────────────────────────────────────────────────

class _LevelsTab extends ConsumerWidget {
  const _LevelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(levelDefinitionsProvider);

    return levelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل المستويات: $e',
        onRetry: () => ref.refresh(levelDefinitionsProvider),
      ),
      data: (levels) => Padding(
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
              DataColumn2(label: Text('الاسم'), size: ColumnSize.L),
              DataColumn2(
                  label: Text('الحد الأدنى XP'),
                  size: ColumnSize.M,
                  numeric: true),
              DataColumn2(label: Text('اللون'), size: ColumnSize.S),
              DataColumn2(label: Text('المزايا'), size: ColumnSize.L),
              DataColumn2(label: Text('إجراء'), size: ColumnSize.S),
            ],
            rows: levels.map((level) {
              Color? badgeColor;
              try {
                final hex = (level['badge_color'] as String? ?? '')
                    .replaceAll('#', '');
                if (hex.length == 6) {
                  badgeColor = Color(int.parse('FF$hex', radix: 16));
                }
              } catch (_) {}

              final benefits = level['benefits'];
              String benefitsText = '—';
              if (benefits != null) {
                try {
                  benefitsText = benefits is String
                      ? benefits
                      : const JsonEncoder().convert(benefits);
                } catch (_) {}
              }

              return DataRow2(
                cells: [
                  DataCell(Text(level['name_ar'] as String? ?? '—')),
                  DataCell(Text(
                    '${level['min_xp'] ?? 0}',
                    textAlign: TextAlign.end,
                  )),
                  DataCell(
                    badgeColor != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(level['badge_color'] as String? ?? '—'),
                            ],
                          )
                        : Text(level['badge_color'] as String? ?? '—'),
                  ),
                  DataCell(
                    Tooltip(
                      message: benefitsText,
                      child: Text(
                        benefitsText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    TextButton(
                      onPressed: () =>
                          _showEditLevelDialog(context, ref, level),
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

  void _showEditLevelDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> level) {
    showDialog(
      context: context,
      builder: (ctx) => _EditLevelDialog(level: level, ref: ref),
    );
  }
}

class _EditLevelDialog extends StatefulWidget {
  final Map<String, dynamic> level;
  final WidgetRef ref;

  const _EditLevelDialog({required this.level, required this.ref});

  @override
  State<_EditLevelDialog> createState() => _EditLevelDialogState();
}

class _EditLevelDialogState extends State<_EditLevelDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _minXpCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _benefitsCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.level['name_ar'] as String? ?? '');
    _minXpCtrl =
        TextEditingController(text: '${widget.level['min_xp'] ?? ''}');
    _colorCtrl = TextEditingController(
        text: widget.level['badge_color'] as String? ?? '');
    _benefitsCtrl = TextEditingController(
      text: widget.level['benefits'] != null
          ? (widget.level['benefits'] is String
              ? widget.level['benefits'] as String
              : const JsonEncoder.withIndent('  ')
                  .convert(widget.level['benefits']))
          : '{}',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minXpCtrl.dispose();
    _colorCtrl.dispose();
    _benefitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      dynamic benefits;
      try {
        benefits = jsonDecode(_benefitsCtrl.text.trim());
      } catch (_) {
        benefits = {};
      }
      await Supabase.instance.client.from('level_definitions').update({
        'name_ar': _nameCtrl.text.trim(),
        'min_xp': int.tryParse(_minXpCtrl.text.trim()),
        'badge_color': _colorCtrl.text.trim(),
        'benefits': benefits,
      }).eq('id', widget.level['id']);
      widget.ref.refresh(levelDefinitionsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ المستوى بنجاح'),
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
    return AlertDialog(
      title: Text('تعديل المستوى: ${widget.level['name_ar'] ?? ''}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'اسم المستوى (عربي)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minXpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'الحد الأدنى XP',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                    labelText: 'لون الشارة (مثل: #FF5733)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _benefitsCtrl,
                maxLines: 4,
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

// ─── Tab 2: Point Rules ───────────────────────────────────────────────────────

class _PointRulesTab extends ConsumerStatefulWidget {
  const _PointRulesTab();

  @override
  ConsumerState<_PointRulesTab> createState() => _PointRulesTabState();
}

class _PointRulesTabState extends ConsumerState<_PointRulesTab> {
  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(pointRulesProvider);

    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل قواعد النقاط: $e',
        onRetry: () => ref.refresh(pointRulesProvider),
      ),
      data: (rules) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة قاعدة'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: DataTable2(
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
                    DataColumn2(label: Text('القاعدة'), size: ColumnSize.L),
                    DataColumn2(label: Text('النوع'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('القيمة'),
                        size: ColumnSize.S,
                        numeric: true),
                    DataColumn2(label: Text('فعّال'), size: ColumnSize.S),
                    DataColumn2(label: Text('إجراء'), size: ColumnSize.S),
                  ],
                  rows: rules.map((rule) {
                    return DataRow2(
                      cells: [
                        DataCell(Text(rule['name_ar'] as String? ??
                            rule['name'] as String? ??
                            '—')),
                        DataCell(Text(_translateType(
                            rule['trigger_type'] as String? ?? ''))),
                        DataCell(Text(
                          '${rule['points_value'] ?? rule['value'] ?? 0}',
                          textAlign: TextAlign.end,
                        )),
                        DataCell(
                          Switch(
                            value: rule['is_active'] == true,
                            onChanged: (v) =>
                                _toggleActive(rule['id'] as String, v),
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () =>
                                _showEditDialog(context, rule),
                            child: const Text('تعديل'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _translateType(String type) {
    switch (type) {
      case 'per_ride':
        return 'لكل رحلة';
      case 'per_km':
        return 'لكل كم';
      case 'milestone':
        return 'إنجاز محدد';
      case 'bonus':
        return 'مكافأة';
      default:
        return type;
    }
  }

  Future<void> _toggleActive(String id, bool value) async {
    try {
      await Supabase.instance.client
          .from('point_earning_rules')
          .update({'is_active': value}).eq('id', id);
      ref.refresh(pointRulesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _EditPointRuleDialog(rule: null, ref: ref),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (ctx) => _EditPointRuleDialog(rule: rule, ref: ref),
    );
  }
}

class _EditPointRuleDialog extends StatefulWidget {
  final Map<String, dynamic>? rule;
  final WidgetRef ref;

  const _EditPointRuleDialog({required this.rule, required this.ref});

  @override
  State<_EditPointRuleDialog> createState() => _EditPointRuleDialogState();
}

class _EditPointRuleDialogState extends State<_EditPointRuleDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valueCtrl;
  String _triggerType = 'per_ride';
  bool _isActive = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameCtrl = TextEditingController(
        text: rule?['name_ar'] as String? ?? rule?['name'] as String? ?? '');
    _valueCtrl = TextEditingController(
        text: '${rule?['points_value'] ?? rule?['value'] ?? ''}');
    _triggerType =
        rule?['trigger_type'] as String? ?? 'per_ride';
    _isActive = rule?['is_active'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final data = {
        'name_ar': _nameCtrl.text.trim(),
        'trigger_type': _triggerType,
        'points_value': num.tryParse(_valueCtrl.text.trim()),
        'is_active': _isActive,
      };
      if (widget.rule == null) {
        await Supabase.instance.client
            .from('point_earning_rules')
            .insert(data);
      } else {
        await Supabase.instance.client
            .from('point_earning_rules')
            .update(data)
            .eq('id', widget.rule!['id']);
      }
      widget.ref.refresh(pointRulesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الحفظ بنجاح'),
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
    return AlertDialog(
      title:
          Text(widget.rule == null ? 'إضافة قاعدة نقاط' : 'تعديل قاعدة نقاط'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم القاعدة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _triggerType,
              decoration: const InputDecoration(
                  labelText: 'النوع', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'per_ride', child: Text('لكل رحلة')),
                DropdownMenuItem(value: 'per_km', child: Text('لكل كم')),
                DropdownMenuItem(value: 'milestone', child: Text('إنجاز محدد')),
                DropdownMenuItem(value: 'bonus', child: Text('مكافأة')),
              ],
              onChanged: (v) => setState(() => _triggerType = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'القيمة (نقاط)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('فعّال'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
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

// ─── Tab 3: XP Rules ─────────────────────────────────────────────────────────

class _XpRulesTab extends ConsumerStatefulWidget {
  const _XpRulesTab();

  @override
  ConsumerState<_XpRulesTab> createState() => _XpRulesTabState();
}

class _XpRulesTabState extends ConsumerState<_XpRulesTab> {
  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(xpRulesProvider);

    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل قواعد XP: $e',
        onRetry: () => ref.refresh(xpRulesProvider),
      ),
      data: (rules) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة قاعدة XP'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: DataTable2(
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
                    DataColumn2(label: Text('القاعدة'), size: ColumnSize.L),
                    DataColumn2(label: Text('النوع'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('القيمة'),
                        size: ColumnSize.S,
                        numeric: true),
                    DataColumn2(label: Text('فعّال'), size: ColumnSize.S),
                    DataColumn2(label: Text('إجراء'), size: ColumnSize.S),
                  ],
                  rows: rules.map((rule) {
                    return DataRow2(
                      cells: [
                        DataCell(Text(rule['name_ar'] as String? ??
                            rule['name'] as String? ??
                            '—')),
                        DataCell(Text(_translateType(
                            rule['trigger_type'] as String? ?? ''))),
                        DataCell(Text(
                          '${rule['xp_value'] ?? rule['value'] ?? 0}',
                          textAlign: TextAlign.end,
                        )),
                        DataCell(
                          Switch(
                            value: rule['is_active'] == true,
                            onChanged: (v) =>
                                _toggleActive(rule['id'] as String, v),
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () =>
                                _showEditDialog(context, rule),
                            child: const Text('تعديل'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _translateType(String type) {
    switch (type) {
      case 'per_ride':
        return 'لكل رحلة';
      case 'per_active_day':
        return 'لكل يوم نشط';
      case 'streak_bonus':
        return 'مكافأة سلسلة';
      case 'achievement':
        return 'إنجاز';
      default:
        return type;
    }
  }

  Future<void> _toggleActive(String id, bool value) async {
    try {
      await Supabase.instance.client
          .from('xp_earning_rules')
          .update({'is_active': value}).eq('id', id);
      ref.refresh(xpRulesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _EditXpRuleDialog(rule: null, ref: ref),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (ctx) => _EditXpRuleDialog(rule: rule, ref: ref),
    );
  }
}

class _EditXpRuleDialog extends StatefulWidget {
  final Map<String, dynamic>? rule;
  final WidgetRef ref;

  const _EditXpRuleDialog({required this.rule, required this.ref});

  @override
  State<_EditXpRuleDialog> createState() => _EditXpRuleDialogState();
}

class _EditXpRuleDialogState extends State<_EditXpRuleDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valueCtrl;
  String _triggerType = 'per_ride';
  bool _isActive = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameCtrl = TextEditingController(
        text: rule?['name_ar'] as String? ?? rule?['name'] as String? ?? '');
    _valueCtrl = TextEditingController(
        text: '${rule?['xp_value'] ?? rule?['value'] ?? ''}');
    _triggerType = rule?['trigger_type'] as String? ?? 'per_ride';
    _isActive = rule?['is_active'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final data = {
        'name_ar': _nameCtrl.text.trim(),
        'trigger_type': _triggerType,
        'xp_value': num.tryParse(_valueCtrl.text.trim()),
        'is_active': _isActive,
      };
      if (widget.rule == null) {
        await Supabase.instance.client.from('xp_earning_rules').insert(data);
      } else {
        await Supabase.instance.client
            .from('xp_earning_rules')
            .update(data)
            .eq('id', widget.rule!['id']);
      }
      widget.ref.refresh(xpRulesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الحفظ بنجاح'),
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
    return AlertDialog(
      title: Text(widget.rule == null ? 'إضافة قاعدة XP' : 'تعديل قاعدة XP'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم القاعدة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _triggerType,
              decoration: const InputDecoration(
                  labelText: 'النوع', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'per_ride', child: Text('لكل رحلة')),
                DropdownMenuItem(
                    value: 'per_active_day', child: Text('لكل يوم نشط')),
                DropdownMenuItem(
                    value: 'streak_bonus', child: Text('مكافأة سلسلة')),
                DropdownMenuItem(
                    value: 'achievement', child: Text('إنجاز')),
              ],
              onChanged: (v) => setState(() => _triggerType = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'قيمة XP', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('فعّال'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
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

// ─── Tab 4: Streak Config ─────────────────────────────────────────────────────

class _StreakConfigTab extends ConsumerWidget {
  const _StreakConfigTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(streakConfigsProvider);

    return configsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل إعدادات السلسلة: $e',
        onRetry: () => ref.refresh(streakConfigsProvider),
      ),
      data: (configs) => ListView(
        padding: const EdgeInsets.all(16),
        children: configs.map((config) {
          return _StreakConfigCard(config: config, ref: ref);
        }).toList(),
      ),
    );
  }
}

class _StreakConfigCard extends StatelessWidget {
  final Map<String, dynamic> config;
  final WidgetRef ref;

  const _StreakConfigCard({required this.config, required this.ref});

  String _typeLabel(String type) {
    switch (type) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final milestones =
        List<Map<String, dynamic>>.from(config['streak_milestones'] ?? []);
    final type = config['type'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _typeLabel(type),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'سلسلة ${_typeLabel(type)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (type == 'daily' && milestones.isNotEmpty) ...[
              const Text(
                'المراحل:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              ...milestones.map((m) => _MilestoneTile(
                    milestone: m,
                    ref: ref,
                    configId: config['id'] as String? ?? '',
                  )),
            ] else if (milestones.isEmpty)
              const Text('لا توجد مراحل',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              Text(
                '${milestones.length} مرحلة',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneTile extends StatefulWidget {
  final Map<String, dynamic> milestone;
  final WidgetRef ref;
  final String configId;

  const _MilestoneTile({
    required this.milestone,
    required this.ref,
    required this.configId,
  });

  @override
  State<_MilestoneTile> createState() => _MilestoneTileState();
}

class _MilestoneTileState extends State<_MilestoneTile> {
  bool _expanded = false;
  late final TextEditingController _daysCtrl;
  late final TextEditingController _pointsCtrl;
  late final TextEditingController _xpCtrl;
  late final TextEditingController _msgCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _daysCtrl = TextEditingController(
        text: '${widget.milestone['days'] ?? widget.milestone['streak_days'] ?? ''}');
    _pointsCtrl = TextEditingController(
        text: '${widget.milestone['reward_points'] ?? ''}');
    _xpCtrl = TextEditingController(
        text: '${widget.milestone['xp'] ?? widget.milestone['reward_xp'] ?? ''}');
    _msgCtrl = TextEditingController(
        text: widget.milestone['message'] as String? ?? '');
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _pointsCtrl.dispose();
    _xpCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('streak_milestones')
          .update({
        'days': int.tryParse(_daysCtrl.text.trim()),
        'reward_points': int.tryParse(_pointsCtrl.text.trim()),
        'xp': int.tryParse(_xpCtrl.text.trim()),
        'message': _msgCtrl.text.trim(),
      }).eq('id', widget.milestone['id']);
      widget.ref.refresh(streakConfigsProvider);
      if (mounted) {
        setState(() => _expanded = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الحفظ'), backgroundColor: AppColors.success),
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.background,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                '${widget.milestone['days'] ?? widget.milestone['streak_days'] ?? '?'}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
                '${widget.milestone['days'] ?? widget.milestone['streak_days'] ?? '?'} يوم — '
                '${widget.milestone['reward_points'] ?? 0} نقطة — '
                '${widget.milestone['xp'] ?? widget.milestone['reward_xp'] ?? 0} XP'),
            subtitle: widget.milestone['message'] != null
                ? Text(widget.milestone['message'] as String)
                : null,
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.edit_outlined,
                  size: 18),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _daysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'الأيام',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _pointsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'نقاط',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _xpCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'XP',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                        labelText: 'الرسالة',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Tab 5: Reward Boxes ──────────────────────────────────────────────────────

class _RewardBoxesTab extends ConsumerStatefulWidget {
  const _RewardBoxesTab();

  @override
  ConsumerState<_RewardBoxesTab> createState() => _RewardBoxesTabState();
}

class _RewardBoxesTabState extends ConsumerState<_RewardBoxesTab> {
  String? _expandedBoxId;

  @override
  Widget build(BuildContext context) {
    final boxesAsync = ref.watch(rewardBoxesProvider);

    return boxesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل صناديق المكافآت: $e',
        onRetry: () => ref.refresh(rewardBoxesProvider),
      ),
      data: (boxes) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة صندوق'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: DataTable2(
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
                    DataColumn2(label: Text('الاسم'), size: ColumnSize.L),
                    DataColumn2(label: Text('النوع'), size: ColumnSize.M),
                    DataColumn2(
                        label: Text('فعّال'), size: ColumnSize.S),
                    DataColumn2(
                        label: Text('تاريخ الانتهاء'), size: ColumnSize.M),
                  ],
                  rows: boxes.map((box) {
                    final boxId = box['id'] as String? ?? '';
                    final isExpanded = _expandedBoxId == boxId;
                    return DataRow2(
                      onTap: () => setState(() =>
                          _expandedBoxId = isExpanded ? null : boxId),
                      color: WidgetStateProperty.resolveWith((states) =>
                          isExpanded
                              ? AppColors.primary.withOpacity(0.04)
                              : null),
                      cells: [
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(box['name_ar'] as String? ??
                                box['name'] as String? ??
                                '—'),
                          ],
                        )),
                        DataCell(Text(_translateBoxType(
                            box['box_type'] as String? ?? ''))),
                        DataCell(_BoolChip(value: box['is_active'] == true)),
                        DataCell(Text(box['expires_at'] != null
                            ? DateFormat('yyyy/MM/dd').format(
                                DateTime.parse(box['expires_at']))
                            : '—')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_expandedBoxId != null) ...[
              const SizedBox(height: 12),
              _BoxPrizesPanel(
                box: boxes.firstWhere(
                  (b) => b['id'] == _expandedBoxId,
                  orElse: () => {},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _translateBoxType(String type) {
    switch (type) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'milestone':
        return 'إنجاز';
      case 'seasonal':
        return 'موسمي';
      default:
        return type;
    }
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddBoxDialog(ref: ref),
    );
  }
}

class _BoxPrizesPanel extends StatelessWidget {
  final Map<String, dynamic> box;

  const _BoxPrizesPanel({required this.box});

  @override
  Widget build(BuildContext context) {
    final prizes =
        List<Map<String, dynamic>>.from(box['box_prizes'] ?? []);

    return Card(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'جوائز: ${box['name_ar'] ?? box['name'] ?? ''}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (prizes.isEmpty)
              const Text('لا توجد جوائز',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...prizes.map((prize) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.card_giftcard,
                        color: AppColors.warning, size: 20),
                    title: Text(
                        prize['name_ar'] as String? ??
                            prize['prize_type'] as String? ??
                            '—'),
                    subtitle: Text(
                        'القيمة: ${prize['value'] ?? '—'} — الاحتمالية: ${prize['probability'] ?? '—'}'),
                  )),
          ],
        ),
      ),
    );
  }
}

class _AddBoxDialog extends StatefulWidget {
  final WidgetRef ref;

  const _AddBoxDialog({required this.ref});

  @override
  State<_AddBoxDialog> createState() => _AddBoxDialogState();
}

class _AddBoxDialogState extends State<_AddBoxDialog> {
  final _nameCtrl = TextEditingController();
  String _boxType = 'daily';
  bool _isActive = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('reward_boxes').insert({
        'name_ar': _nameCtrl.text.trim(),
        'box_type': _boxType,
        'is_active': _isActive,
      });
      widget.ref.refresh(rewardBoxesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إضافة الصندوق'),
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
    return AlertDialog(
      title: const Text('إضافة صندوق مكافآت'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم الصندوق', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _boxType,
              decoration: const InputDecoration(
                  labelText: 'نوع الصندوق', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('يومي')),
                DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                DropdownMenuItem(value: 'milestone', child: Text('إنجاز')),
                DropdownMenuItem(value: 'seasonal', child: Text('موسمي')),
              ],
              onChanged: (v) => setState(() => _boxType = v!),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('فعّال'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
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
              : const Text('إضافة'),
        ),
      ],
    );
  }
}

// ─── Tab 6: Redemption Options ────────────────────────────────────────────────

class _RedemptionOptionsTab extends ConsumerWidget {
  const _RedemptionOptionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(redemptionOptionsProvider);

    return optionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل خيارات الاستبدال: $e',
        onRetry: () => ref.refresh(redemptionOptionsProvider),
      ),
      data: (options) => Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 16,
            headingRowHeight: 48,
            dataRowHeight: 56,
            headingRowColor:
                WidgetStateProperty.all(AppColors.primary.withOpacity(0.06)),
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade100),
            ),
            columns: const [
              DataColumn2(label: Text('الاسم'), size: ColumnSize.L),
              DataColumn2(label: Text('النوع'), size: ColumnSize.M),
              DataColumn2(
                  label: Text('التكلفة بنقاط'),
                  size: ColumnSize.M,
                  numeric: true),
              DataColumn2(
                  label: Text('القيمة'), size: ColumnSize.S, numeric: true),
              DataColumn2(label: Text('فعّال'), size: ColumnSize.S),
            ],
            rows: options.map((option) {
              final type = option['redemption_type'] as String? ??
                  option['type'] as String? ??
                  '';
              final isEtb = type == 'etb_cash' || type == 'cash';

              return DataRow2(
                cells: [
                  DataCell(Text(option['name_ar'] as String? ??
                      option['name'] as String? ??
                      '—')),
                  DataCell(
                    isEtb
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_translateRedemptionType(type)),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'معطل افتراضياً',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.warning.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'معطل افتراضياً',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(_translateRedemptionType(type)),
                  ),
                  DataCell(Text(
                    '${option['points_cost'] ?? option['cost_points'] ?? 0}',
                    textAlign: TextAlign.end,
                  )),
                  DataCell(Text(
                    '${option['value'] ?? '—'}',
                    textAlign: TextAlign.end,
                  )),
                  DataCell(
                    Switch(
                      value: option['is_active'] == true,
                      onChanged: (v) => _toggleActive(
                          context, ref, option['id'] as String, v),
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

  String _translateRedemptionType(String type) {
    switch (type) {
      case 'etb_cash':
      case 'cash':
        return 'نقد ETB';
      case 'sub_days':
        return 'أيام اشتراك';
      case 'discount':
        return 'خصم';
      case 'voucher':
        return 'قسيمة';
      default:
        return type;
    }
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, String id, bool value) async {
    try {
      await Supabase.instance.client
          .from('redemption_options')
          .update({'is_active': value}).eq('id', id);
      ref.refresh(redemptionOptionsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
          ElevatedButton(
              onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
