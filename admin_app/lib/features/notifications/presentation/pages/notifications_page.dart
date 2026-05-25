import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';

final _adminSvcProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

final sentNotificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(_adminSvcProvider).getSentNotifications(pageSize: 50);
});

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();

  String _target = 'all';
  String _type = 'general';
  bool _sending = false;

  static const _targetOptions = [
    ('all', 'الجميع'),
    ('passengers', 'الركاب'),
    ('drivers', 'السائقون'),
    ('specific_user', 'مستخدم محدد'),
  ];

  static const _typeOptions = [
    ('general', 'عام'),
    ('ride_update', 'تحديث رحلة'),
    ('subscription', 'اشتراك'),
    ('leaderboard', 'قائمة المتصدرين'),
    ('promo', 'عرض ترويجي'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref.read(_adminSvcProvider).sendNotification(
            target: _target,
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            type: _type,
            userId: _target == 'specific_user' && _userIdCtrl.text.isNotEmpty
                ? _userIdCtrl.text.trim()
                : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الإشعار بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _userIdCtrl.clear();
        setState(() => _target = 'all');
        ref.refresh(sentNotificationsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الإرسال: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(sentNotificationsProvider);
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Row(
            children: [
              const Icon(Icons.notifications, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'الإشعارات والتنبيهات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Section 1: Send Notification Form ──────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.send, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'إرسال إشعار جديد',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildTargetDropdown()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTypeDropdown()),
                              ],
                            )
                          : Column(
                              children: [
                                _buildTargetDropdown(),
                                const SizedBox(height: 12),
                                _buildTypeDropdown(),
                              ],
                            );
                    }),
                    if (_target == 'specific_user') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _userIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'معرف المستخدم أو رقم الهاتف',
                          prefixIcon: Icon(Icons.person_search),
                          hintText: 'أدخل معرف المستخدم أو رقم الهاتف',
                        ),
                        validator: (v) {
                          if (_target == 'specific_user' &&
                              (v == null || v.trim().isEmpty)) {
                            return 'يرجى إدخال معرف المستخدم';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الإشعار',
                        prefixIcon: Icon(Icons.title),
                        hintText: 'أدخل عنوان الإشعار',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bodyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'نص الإشعار',
                        prefixIcon: Icon(Icons.message),
                        hintText: 'أدخل نص الإشعار',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'النص مطلوب' : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _sendNotification,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                        label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال الإشعار'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: Sent Notifications History ──────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'سجل الإشعارات المُرسلة',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'تحديث',
                        onPressed: () => ref.refresh(sentNotificationsProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  notificationsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'تعذر تحميل الإشعارات: $e',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    data: (notifications) => notifications.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(Icons.notifications_none,
                                      size: 48, color: AppColors.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'لا توجد إشعارات مُرسلة',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 400,
                            child: DataTable2(
                              columnSpacing: 12,
                              horizontalMargin: 16,
                              headingRowHeight: 48,
                              dataRowHeight: 52,
                              border: TableBorder(
                                horizontalInside:
                                    BorderSide(color: Colors.grey.shade100),
                              ),
                              headingRowColor: WidgetStateProperty.all(
                                AppColors.primary.withOpacity(0.04),
                              ),
                              columns: const [
                                DataColumn2(
                                    label: Text('الهدف'), size: ColumnSize.M),
                                DataColumn2(
                                    label: Text('العنوان'), size: ColumnSize.L),
                                DataColumn2(
                                    label: Text('النوع'), size: ColumnSize.M),
                                DataColumn2(
                                    label: Text('التاريخ'), size: ColumnSize.M),
                                DataColumn2(
                                    label: Text('الحالة'), size: ColumnSize.S),
                              ],
                              rows: notifications.map((n) {
                                final target = n['target'] as String? ?? '—';
                                final title = n['title'] as String? ?? '—';
                                final type = n['type'] as String? ?? '—';
                                final status = n['status'] as String? ?? 'sent';
                                final createdAt = n['created_at'] != null
                                    ? dateFormat.format(
                                        DateTime.parse(n['created_at']))
                                    : '—';

                                return DataRow2(
                                  cells: [
                                    DataCell(_buildTargetChip(target)),
                                    DataCell(
                                      Text(
                                        title,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    DataCell(_buildTypeChip(type)),
                                    DataCell(Text(createdAt)),
                                    DataCell(_buildStatusChip(status)),
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

  Widget _buildTargetDropdown() {
    return DropdownButtonFormField<String>(
      value: _target,
      decoration: const InputDecoration(
        labelText: 'الجمهور المستهدف',
        prefixIcon: Icon(Icons.group),
      ),
      items: _targetOptions
          .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
          .toList(),
      onChanged: (v) => setState(() => _target = v ?? 'all'),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _type,
      decoration: const InputDecoration(
        labelText: 'نوع الإشعار',
        prefixIcon: Icon(Icons.category),
      ),
      items: _typeOptions
          .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
          .toList(),
      onChanged: (v) => setState(() => _type = v ?? 'general'),
    );
  }

  Widget _buildTargetChip(String target) {
    final (label, color) = switch (target) {
      'all' => ('الجميع', AppColors.info),
      'passengers' => ('الركاب', AppColors.secondary),
      'drivers' => ('السائقون', AppColors.primary),
      'specific_user' => ('مستخدم محدد', AppColors.tertiary),
      _ => (target, AppColors.textSecondary),
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

  Widget _buildTypeChip(String type) {
    final label = switch (type) {
      'general' => 'عام',
      'ride_update' => 'تحديث رحلة',
      'subscription' => 'اشتراك',
      'leaderboard' => 'قائمة المتصدرين',
      'promo' => 'عرض ترويجي',
      _ => type,
    };
    return Text(label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12));
  }

  Widget _buildStatusChip(String status) {
    final (label, color) = switch (status) {
      'sent' => ('مُرسل', AppColors.success),
      'failed' => ('فشل', AppColors.error),
      'pending' => ('معلق', AppColors.warning),
      _ => (status, AppColors.textSecondary),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status == 'sent'
              ? Icons.check_circle
              : status == 'failed'
                  ? Icons.cancel
                  : Icons.pending,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
