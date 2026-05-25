import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/data_table_widget.dart';

final _adminSvcProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

final pendingTransfersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(_adminSvcProvider).getPendingBankTransfers();
});

final activeSubsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(_adminSvcProvider).getSubscriptions(status: 'active');
});

final expiredSubsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(_adminSvcProvider).getSubscriptions(status: 'expired');
});

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTransfersProvider);
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة الاشتراكات',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions, size: 16),
                          const SizedBox(width: 6),
                          const Text('تأكيد التحويلات البنكية'),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16),
                          SizedBox(width: 6),
                          Text('الاشتراكات النشطة'),
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 16),
                          SizedBox(width: 6),
                          Text('المنتهية'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [
                _PendingTransfersTab(),
                _ActiveSubsTab(),
                _ExpiredSubsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending Bank Transfers Tab ──────────────────────────────────────────────
class _PendingTransfersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingTransfersProvider);
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: 'ETB ');
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (transfers) => transfers.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: AppColors.success),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد تحويلات معلقة',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'جميع التحويلات البنكية تم تأكيدها',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: AppColors.warning),
                        const SizedBox(width: 10),
                        Text(
                          '${transfers.length} تحويل بنكي ينتظر التأكيد',
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                        const Spacer(),
                        Text(
                          'إجمالي: ${currency.format(transfers.fold(0.0, (s, t) => s + ((t['amount'] ?? 0) as num).toDouble()))}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Grid of transfer cards
                  LayoutBuilder(builder: (context, constraints) {
                    final cols = constraints.maxWidth > 1100
                        ? 3
                        : constraints.maxWidth > 700
                            ? 2
                            : 1;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: transfers.map((t) {
                        return SizedBox(
                          width: (constraints.maxWidth - (cols - 1) * 16) /
                              cols,
                          child: _TransferCard(
                            transfer: t,
                            currency: currency,
                            dateFormat: dateFormat,
                            onConfirm: () async {
                              final service = ref.read(_adminSvcProvider);
                              await service
                                  .confirmBankTransfer(t['id'] as String);
                              ref.refresh(pendingTransfersProvider);
                              ref.refresh(pendingCountsProvider);
                            },
                            onReject: (reason) async {
                              final service = ref.read(_adminSvcProvider);
                              await service.rejectBankTransfer(
                                  t['id'] as String,
                                  reason: reason);
                              ref.refresh(pendingTransfersProvider);
                              ref.refresh(pendingCountsProvider);
                            },
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final Map<String, dynamic> transfer;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onConfirm;
  final ValueChanged<String> onReject;

  const _TransferCard({
    required this.transfer,
    required this.currency,
    required this.dateFormat,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final driver = transfer['driver'] as Map? ?? {};
    final driverName = driver['full_name'] as String? ?? '—';
    final driverPhone = driver['phone_number'] as String? ?? '—';
    final amount = (transfer['amount'] ?? 0) as num;
    final reference = transfer['payment_reference'] as String? ?? '—';
    final receiptUrl = transfer['receipt_url'] as String? ?? '';
    final planType = transfer['plan_type'] as String? ?? '—';
    final createdAt = transfer['created_at'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Receipt image / placeholder
          GestureDetector(
            onTap: () => _showReceiptImage(context, receiptUrl),
            child: Container(
              height: 160,
              width: double.infinity,
              color: Colors.grey.shade100,
              child: Stack(
                children: [
                  if (receiptUrl.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        receiptUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_not_supported,
                              size: 48, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('لا يوجد إيصال',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  if (receiptUrl.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('عرض الإيصال',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.person,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driverName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(driverPhone,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Details
                _DetailRow(
                  label: 'المبلغ',
                  value: currency.format(amount),
                  valueStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.primary),
                ),
                _DetailRow(label: 'خطة الاشتراك', value: _planLabel(planType)),
                _DetailRow(label: 'رقم المرجع', value: reference),
                if (createdAt != null)
                  _DetailRow(
                    label: 'التاريخ',
                    value: dateFormat
                        .format(DateTime.parse(createdAt)),
                  ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(context),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showConfirmDialog(context),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('تأكيد'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptImage(BuildContext context, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد إيصال مرفق')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('إيصال التحويل البنكي'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close))
              ],
            ),
            ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 600, maxWidth: 500),
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'المبلغ: ${NumberFormat.currency(locale: 'am_ET', symbol: 'ETB ').format((transfer['amount'] ?? 0) as num)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التحويل البنكي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل تريد تأكيد هذا التحويل؟'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'السائق: ${(transfer['driver'] as Map? ?? {})['full_name'] ?? '—'}'),
                  Text(
                      'المبلغ: ${NumberFormat.currency(locale: 'am_ET', symbol: 'ETB ').format((transfer['amount'] ?? 0) as num)}'),
                  Text('المرجع: ${transfer['payment_reference'] ?? '—'}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('تأكيد الدفع'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض التحويل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'السائق: ${(transfer['driver'] as Map? ?? {})['full_name'] ?? '—'}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض',
                hintText: 'مثال: الإيصال غير واضح، المبلغ غير مطابق...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              onReject(reasonCtrl.text.trim());
            },
            child: const Text('رفض التحويل'),
          ),
        ],
      ),
    );
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return plan;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label:',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Active Subscriptions Tab ─────────────────────────────────────────────────
class _ActiveSubsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeSubsProvider);
    final dateFormat = DateFormat('yyyy/MM/dd');
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: 'ETB ');

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (subs) => subs.isEmpty
          ? const Center(child: Text('لا توجد اشتراكات نشطة'))
          : Card(
              margin: const EdgeInsets.all(24),
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 16,
                minWidth: 700,
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
                  DataColumn2(label: Text('السائق'), size: ColumnSize.L),
                  DataColumn2(label: Text('الخطة'), size: ColumnSize.S),
                  DataColumn2(
                      label: Text('المبلغ'), size: ColumnSize.S, numeric: true),
                  DataColumn2(label: Text('تاريخ البدء'), size: ColumnSize.M),
                  DataColumn2(label: Text('تاريخ الانتهاء'), size: ColumnSize.M),
                  DataColumn2(label: Text('التجديد التلقائي'), size: ColumnSize.S),
                ],
                rows: subs.map((sub) {
                  final driver = sub['driver'] as Map? ?? {};
                  return DataRow2(
                    cells: [
                      DataCell(Text(driver['full_name'] as String? ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _planLabel(sub['plan_type'] as String? ?? ''),
                            style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(Text(
                        currency.format(sub['amount'] ?? 0),
                        textAlign: TextAlign.end,
                      )),
                      DataCell(Text(sub['start_date'] != null
                          ? dateFormat.format(
                              DateTime.parse(sub['start_date']))
                          : '—')),
                      DataCell(Text(sub['end_date'] != null
                          ? dateFormat.format(
                              DateTime.parse(sub['end_date']))
                          : '—')),
                      DataCell(
                        Icon(
                          sub['auto_renew'] == true
                              ? Icons.autorenew
                              : Icons.cancel_outlined,
                          color: sub['auto_renew'] == true
                              ? AppColors.success
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return plan;
    }
  }
}

// ─── Expired Subscriptions Tab ────────────────────────────────────────────────
class _ExpiredSubsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expiredSubsProvider);
    final dateFormat = DateFormat('yyyy/MM/dd');
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: 'ETB ');

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (subs) => subs.isEmpty
          ? const Center(child: Text('لا توجد اشتراكات منتهية'))
          : Card(
              margin: const EdgeInsets.all(24),
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 16,
                minWidth: 700,
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
                  DataColumn2(label: Text('السائق'), size: ColumnSize.L),
                  DataColumn2(label: Text('الخطة'), size: ColumnSize.S),
                  DataColumn2(
                      label: Text('المبلغ'), size: ColumnSize.S, numeric: true),
                  DataColumn2(
                      label: Text('تاريخ الانتهاء'), size: ColumnSize.M),
                  DataColumn2(
                      label: Text('طريقة الدفع'), size: ColumnSize.M),
                ],
                rows: subs.map((sub) {
                  final driver = sub['driver'] as Map? ?? {};
                  return DataRow2(
                    cells: [
                      DataCell(Text(driver['full_name'] as String? ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(
                          Text(_planLabel(sub['plan_type'] as String? ?? ''))),
                      DataCell(Text(
                        currency.format(sub['amount'] ?? 0),
                        textAlign: TextAlign.end,
                      )),
                      DataCell(Text(sub['end_date'] != null
                          ? dateFormat.format(
                              DateTime.parse(sub['end_date']))
                          : '—')),
                      DataCell(
                          Text(_paymentMethodLabel(
                              sub['payment_method'] as String? ?? ''))),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return plan;
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'telebirr':
        return 'تيليبير';
      case 'cash':
        return 'نقدي';
      default:
        return method;
    }
  }
}
