import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/data_table_widget.dart';

final _adminServiceProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

// Drivers state
class _DriversState {
  final List<Map<String, dynamic>> drivers;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final String search;
  final String status;

  const _DriversState({
    this.drivers = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
    this.search = '',
    this.status = 'pending',
  });

  _DriversState copyWith({
    List<Map<String, dynamic>>? drivers,
    bool? isLoading,
    String? error,
    int? currentPage,
    String? search,
    String? status,
  }) =>
      _DriversState(
        drivers: drivers ?? this.drivers,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        currentPage: currentPage ?? this.currentPage,
        search: search ?? this.search,
        status: status ?? this.status,
      );
}

class _DriversNotifier extends StateNotifier<_DriversState> {
  final SupabaseAdminService _service;

  _DriversNotifier(this._service) : super(const _DriversState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final drivers = await _service.getDrivers(
        status: state.status,
        search: state.search,
        page: state.currentPage,
      );
      state = state.copyWith(drivers: drivers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setStatus(String status) {
    state = state.copyWith(status: status, currentPage: 0);
    load();
  }

  void setSearch(String search) {
    state = state.copyWith(search: search, currentPage: 0);
    load();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
    load();
  }

  Future<void> approveDriver(String id) async {
    await _service.updateDriverStatus(id, 'active');
    load();
  }

  Future<void> rejectDriver(String id, String reason) async {
    await _service.updateDriverStatus(id, 'rejected', reason: reason);
    load();
  }
}

final driversProvider =
    StateNotifierProvider<_DriversNotifier, _DriversState>((ref) {
  return _DriversNotifier(ref.watch(_adminServiceProvider));
});

class DriversPage extends ConsumerWidget {
  const DriversPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة السائقين',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  isScrollable: true,
                  onTap: (index) {
                    final statuses = ['pending', 'active', 'suspended'];
                    ref
                        .read(driversProvider.notifier)
                        .setStatus(statuses[index]);
                  },
                  tabs: const [
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.pending, size: 16),
                          SizedBox(width: 6),
                          Text('طلبات جديدة'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16),
                          SizedBox(width: 6),
                          Text('نشطون'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 16),
                          SizedBox(width: 6),
                          Text('موقوفون'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _DriversTableView()),
        ],
      ),
    );
  }
}

class _DriversTableView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driversProvider);
    final notifier = ref.read(driversProvider.notifier);
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Card(
      margin: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو رقم الهاتف...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                    onChanged: notifier.setSearch,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: notifier.load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          // Table
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('خطأ: ${state.error}'))
                    : state.drivers.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: AppColors.textSecondary),
                                SizedBox(height: 12),
                                Text('لا يوجد سائقون',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 16,
                            minWidth: 800,
                            headingRowHeight: 48,
                            dataRowHeight: 58,
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                  color: Colors.grey.shade100),
                            ),
                            headingRowColor: WidgetStateProperty.all(
                              AppColors.primary.withOpacity(0.04),
                            ),
                            columns: const [
                              DataColumn2(
                                  label: Text('الاسم'), size: ColumnSize.L),
                              DataColumn2(
                                  label: Text('رقم الهاتف'),
                                  size: ColumnSize.M),
                              DataColumn2(
                                  label: Text('نوع المركبة'),
                                  size: ColumnSize.M),
                              DataColumn2(
                                  label: Text('تاريخ التسجيل'),
                                  size: ColumnSize.M),
                              DataColumn2(
                                  label: Text('الحالة'), size: ColumnSize.S),
                              DataColumn2(
                                  label: Text('الإجراءات'),
                                  size: ColumnSize.L),
                            ],
                            rows: state.drivers.map((driver) {
                              return DataRow2(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppColors.primary
                                              .withOpacity(0.1),
                                          backgroundImage:
                                              driver['profile_photo_url'] != null
                                                  ? NetworkImage(
                                                      driver['profile_photo_url'])
                                                  : null,
                                          child:
                                              driver['profile_photo_url'] == null
                                                  ? const Icon(Icons.person,
                                                      size: 18,
                                                      color: AppColors.primary)
                                                  : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          driver['full_name'] as String? ?? '—',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(driver['phone_number'] as String? ?? '—'),
                                  ),
                                  DataCell(
                                    Text(_vehicleLabel(
                                        driver['vehicle_type'] as String? ?? '')),
                                  ),
                                  DataCell(
                                    Text(driver['created_at'] != null
                                        ? dateFormat.format(
                                            DateTime.parse(driver['created_at']))
                                        : '—'),
                                  ),
                                  DataCell(StatusBadge(
                                    status: driver['status'] as String? ?? '',
                                  )),
                                  DataCell(
                                    _ActionButtons(
                                      driver: driver,
                                      status: state.status,
                                      onApprove: () => notifier
                                          .approveDriver(driver['id']),
                                      onReject: (reason) => notifier
                                          .rejectDriver(driver['id'], reason),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
          ),
        ],
      ),
    );
  }

  String _vehicleLabel(String type) {
    switch (type) {
      case 'sedan':
        return 'سيدان';
      case 'suv':
        return 'SUV';
      case 'vip':
        return 'VIP';
      case 'minibus':
        return 'ميني باص';
      default:
        return type;
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final Map<String, dynamic> driver;
  final String status;
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;

  const _ActionButtons({
    required this.driver,
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View details
        TextButton.icon(
          onPressed: () =>
              context.go('/dashboard/drivers/${driver['id']}'),
          icon: const Icon(Icons.visibility, size: 16),
          label: const Text('تفاصيل'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        if (status == 'pending') ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'قبول',
            onPressed: () => _confirmApprove(context),
            icon: const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 20),
          ),
          IconButton(
            tooltip: 'رفض',
            onPressed: () => _showRejectDialog(context),
            icon: const Icon(Icons.cancel_outlined,
                color: AppColors.error, size: 20),
          ),
        ] else if (status == 'active') ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'إيقاف',
            onPressed: () => _showRejectDialog(context),
            icon: const Icon(Icons.block, color: AppColors.warning, size: 20),
          ),
        ] else if (status == 'suspended') ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'إعادة تفعيل',
            onPressed: () => _confirmApprove(context),
            icon: const Icon(Icons.refresh,
                color: AppColors.success, size: 20),
          ),
        ],
      ],
    );
  }

  void _confirmApprove(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الموافقة'),
        content: Text(
            'هل تريد قبول السائق "${driver['full_name']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onApprove();
            },
            child: const Text('قبول'),
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
        title: const Text('سبب الرفض / الإيقاف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('السائق: ${driver['full_name']}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'السبب',
                hintText: 'أدخل سبب الرفض أو الإيقاف...',
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
              if (reasonCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                onReject(reasonCtrl.text.trim());
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
