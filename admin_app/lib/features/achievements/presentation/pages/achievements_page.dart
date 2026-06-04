import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final achievementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('achievements')
      .select()
      .order('created_at', ascending: false)
      .then((r) => List<Map<String, dynamic>>.from(r));
});

final _driverSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final driverAchievementsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.trim().isEmpty) return [];
  final res = await Supabase.instance.client
      .from('driver_achievements')
      .select('*, achievements(name_ar, badge_icon), profiles!driver_id(full_name, phone_number)')
      .or('profiles.full_name.ilike.%$query%,profiles.phone_number.ilike.%$query%')
      .order('earned_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(res);
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'الإنجازات'),
                Tab(text: 'إنجازات السائقين'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _AchievementsListTab(),
                _DriverAchievementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Achievements List ─────────────────────────────────────────────────

class _AchievementsListTab extends ConsumerWidget {
  const _AchievementsListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievAsync = ref.watch(achievementsProvider);

    return achievAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorWidget(
        message: 'خطأ في تحميل الإنجازات: $e',
        onRetry: () => ref.refresh(achievementsProvider),
      ),
      data: (achievements) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إنجاز جديد'),
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
                        label: Text('القيمة'),
                        size: ColumnSize.S,
                        numeric: true),
                    DataColumn2(
                        label: Text('نقاط المكافأة'),
                        size: ColumnSize.S,
                        numeric: true),
                    DataColumn2(label: Text('XP'), size: ColumnSize.S, numeric: true),
                    DataColumn2(label: Text('مخفي'), size: ColumnSize.S),
                    DataColumn2(label: Text('فعّال'), size: ColumnSize.S),
                  ],
                  rows: achievements.map((a) {
                    return DataRow2(
                      cells: [
                        DataCell(Text(a['name_ar'] as String? ?? '—')),
                        DataCell(Text(
                            _translateTrigger(a['trigger_type'] as String? ?? ''))),
                        DataCell(Text(
                          '${a['trigger_value'] ?? '—'}',
                          textAlign: TextAlign.end,
                        )),
                        DataCell(Text(
                          '${a['reward_points'] ?? 0}',
                          textAlign: TextAlign.end,
                        )),
                        DataCell(Text(
                          '${a['reward_xp'] ?? 0}',
                          textAlign: TextAlign.end,
                        )),
                        DataCell(_BoolChip(value: a['is_hidden'] == true)),
                        DataCell(
                          Switch(
                            value: a['is_active'] == true,
                            onChanged: (v) =>
                                _toggleActive(context, ref, a['id'] as String, v),
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

  String _translateTrigger(String type) {
    switch (type) {
      case 'ride_count':
        return 'عدد الرحلات';
      case 'streak_days':
        return 'أيام متتالية';
      case 'xp_total':
        return 'إجمالي XP';
      case 'rating_avg':
        return 'متوسط التقييم';
      case 'admin_manual':
        return 'يدوي';
      default:
        return type;
    }
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, String id, bool value) async {
    try {
      await Supabase.instance.client
          .from('achievements')
          .update({'is_active': value}).eq('id', id);
      ref.refresh(achievementsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _AchievementFormDialog(achievement: null, ref: ref),
    );
  }
}

// ─── Achievement Form Dialog ──────────────────────────────────────────────────

class _AchievementFormDialog extends StatefulWidget {
  final Map<String, dynamic>? achievement;
  final WidgetRef ref;

  const _AchievementFormDialog(
      {required this.achievement, required this.ref});

  @override
  State<_AchievementFormDialog> createState() =>
      _AchievementFormDialogState();
}

class _AchievementFormDialogState extends State<_AchievementFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _triggerValueCtrl;
  late final TextEditingController _rewardPointsCtrl;
  late final TextEditingController _rewardXpCtrl;
  String _triggerType = 'ride_count';
  bool _isHidden = false;
  bool _isRepeatable = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final a = widget.achievement;
    _nameCtrl =
        TextEditingController(text: a?['name_ar'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: a?['description_ar'] as String? ?? '');
    _triggerValueCtrl =
        TextEditingController(text: '${a?['trigger_value'] ?? ''}');
    _rewardPointsCtrl =
        TextEditingController(text: '${a?['reward_points'] ?? ''}');
    _rewardXpCtrl =
        TextEditingController(text: '${a?['reward_xp'] ?? ''}');
    _triggerType = a?['trigger_type'] as String? ?? 'ride_count';
    _isHidden = a?['is_hidden'] == true;
    _isRepeatable = a?['is_repeatable'] == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _triggerValueCtrl.dispose();
    _rewardPointsCtrl.dispose();
    _rewardXpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = {
        'name_ar': _nameCtrl.text.trim(),
        'description_ar': _descCtrl.text.trim(),
        'trigger_type': _triggerType,
        'trigger_value': num.tryParse(_triggerValueCtrl.text.trim()),
        'reward_points': int.tryParse(_rewardPointsCtrl.text.trim()),
        'reward_xp': int.tryParse(_rewardXpCtrl.text.trim()),
        'is_hidden': _isHidden,
        'is_repeatable': _isRepeatable,
      };
      if (widget.achievement == null) {
        await Supabase.instance.client.from('achievements').insert(data);
      } else {
        await Supabase.instance.client
            .from('achievements')
            .update(data)
            .eq('id', widget.achievement!['id']);
      }
      widget.ref.refresh(achievementsProvider);
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
      title: Text(widget.achievement == null ? 'إنجاز جديد' : 'تعديل إنجاز'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'الاسم (عربي)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'الوصف (عربي)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _triggerType,
                decoration: const InputDecoration(
                    labelText: 'نوع الشرط', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'ride_count', child: Text('عدد الرحلات')),
                  DropdownMenuItem(
                      value: 'streak_days', child: Text('أيام متتالية')),
                  DropdownMenuItem(
                      value: 'xp_total', child: Text('إجمالي XP')),
                  DropdownMenuItem(
                      value: 'rating_avg', child: Text('متوسط التقييم')),
                  DropdownMenuItem(
                      value: 'admin_manual', child: Text('يدوي')),
                ],
                onChanged: (v) => setState(() => _triggerType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _triggerValueCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'قيمة الشرط', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rewardPointsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'نقاط المكافأة',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rewardXpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'XP المكافأة',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('مخفي'),
                value: _isHidden,
                onChanged: (v) => setState(() => _isHidden = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('قابل للتكرار'),
                value: _isRepeatable,
                onChanged: (v) => setState(() => _isRepeatable = v),
                contentPadding: EdgeInsets.zero,
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

// ─── Tab 2: Driver Achievements ───────────────────────────────────────────────

class _DriverAchievementsTab extends ConsumerStatefulWidget {
  const _DriverAchievementsTab();

  @override
  ConsumerState<_DriverAchievementsTab> createState() =>
      _DriverAchievementsTabState();
}

class _DriverAchievementsTabState
    extends ConsumerState<_DriverAchievementsTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_driverSearchQueryProvider);
    final achievAsync = ref.watch(driverAchievementsProvider(query));
    final allAchievAsync = ref.watch(achievementsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search + Add Manual button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'ابحث عن سائق بالاسم أو رقم الهاتف',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(_driverSearchQueryProvider.notifier)
                                  .state = '';
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (v) => ref
                      .read(_driverSearchQueryProvider.notifier)
                      .state = v.trim(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showManualAssignDialog(context, allAchievAsync.valueOrNull ?? []),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إنجاز يدوي'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (query.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'أدخل اسم السائق أو رقم هاتفه للبحث',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: achievAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorWidget(
                  message: 'خطأ في البحث: $e',
                  onRetry: () =>
                      ref.refresh(driverAchievementsProvider(query)),
                ),
                data: (records) => records.isEmpty
                    ? const Center(
                        child: Text('لا توجد نتائج',
                            style: TextStyle(
                                color: AppColors.textSecondary)))
                    : Card(
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
                            DataColumn2(
                                label: Text('السائق'), size: ColumnSize.L),
                            DataColumn2(
                                label: Text('الإنجاز'), size: ColumnSize.L),
                            DataColumn2(
                                label: Text('تاريخ الحصول'),
                                size: ColumnSize.M),
                          ],
                          rows: records.map((r) {
                            final profile = r['profiles'] as Map? ?? {};
                            final achievData =
                                r['achievements'] as Map? ?? {};
                            final earnedAt = r['earned_at'] as String?;

                            return DataRow2(
                              cells: [
                                DataCell(Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        profile['full_name'] as String? ??
                                            '—'),
                                    Text(
                                      profile['phone_number'] as String? ??
                                          '—',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                )),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (achievData['badge_icon'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            right: 6),
                                        child: Text(
                                            achievData['badge_icon']
                                                as String,
                                            style: const TextStyle(
                                                fontSize: 18)),
                                      ),
                                    Text(achievData['name_ar']
                                            as String? ??
                                        '—'),
                                  ],
                                )),
                                DataCell(Text(earnedAt != null
                                    ? _formatDate(earnedAt)
                                    : '—')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  void _showManualAssignDialog(
      BuildContext context, List<Map<String, dynamic>> allAchievements) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _ManualAssignDialog(achievements: allAchievements, ref: ref),
    );
  }
}

class _ManualAssignDialog extends StatefulWidget {
  final List<Map<String, dynamic>> achievements;
  final WidgetRef ref;

  const _ManualAssignDialog(
      {required this.achievements, required this.ref});

  @override
  State<_ManualAssignDialog> createState() => _ManualAssignDialogState();
}

class _ManualAssignDialogState extends State<_ManualAssignDialog> {
  final _driverIdCtrl = TextEditingController();
  String? _selectedAchievementId;
  bool _loading = false;

  @override
  void dispose() {
    _driverIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_driverIdCtrl.text.trim().isEmpty ||
        _selectedAchievementId == null) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('driver_achievements').insert({
        'driver_id': _driverIdCtrl.text.trim(),
        'achievement_id': _selectedAchievementId,
        'earned_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم منح الإنجاز بنجاح'),
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
      title: const Text('منح إنجاز يدوي'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _driverIdCtrl,
              decoration: const InputDecoration(
                  labelText: 'معرف السائق (Driver ID)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedAchievementId,
              decoration: const InputDecoration(
                  labelText: 'الإنجاز', border: OutlineInputBorder()),
              hint: const Text('اختر إنجازاً'),
              items: widget.achievements.map((a) {
                return DropdownMenuItem<String>(
                  value: a['id'] as String?,
                  child: Text(a['name_ar'] as String? ?? '—'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedAchievementId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _loading ? null : _assign,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('منح'),
        ),
      ],
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
          ElevatedButton(
              onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
