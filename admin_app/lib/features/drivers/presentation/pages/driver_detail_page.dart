import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/data_table_widget.dart';

final _driverDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final service = SupabaseAdminService(ref.watch(supabaseClientProvider));
  return service.getDriverById(id);
});

final _driverRidesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final supabase = ref.watch(supabaseClientProvider);
  final res = await supabase
      .from('rides')
      .select(
          'id, status, fare_amount, created_at, passenger:passenger_id(full_name), vehicle_type')
      .eq('driver_id', id)
      .order('created_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(res as List);
});

class DriverDetailPage extends ConsumerWidget {
  final String driverId;
  const DriverDetailPage({super.key, required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(_driverDetailProvider(driverId));

    return driverAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('خطأ في تحميل بيانات السائق: $e'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.refresh(_driverDetailProvider(driverId)),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
      data: (driver) => _DriverDetailView(
        driver: driver,
        driverId: driverId,
        ref: ref,
      ),
    );
  }
}

class _DriverDetailView extends StatelessWidget {
  final Map<String, dynamic> driver;
  final String driverId;
  final WidgetRef ref;

  const _DriverDetailView({
    required this.driver,
    required this.driverId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + title
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/dashboard/drivers'),
                icon: const Icon(Icons.arrow_back_ios),
                tooltip: 'العودة',
              ),
              const SizedBox(width: 8),
              Text(
                'تفاصيل السائق',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              _ActionButtonsBar(driver: driver, driverId: driverId, ref: ref),
            ],
          ),
          const SizedBox(height: 24),

          // Profile + Vehicle cards
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 2,
                          child: _ProfileCard(driver: driver)),
                      const SizedBox(width: 16),
                      Expanded(
                          flex: 2,
                          child: _VehicleCard(driver: driver)),
                      const SizedBox(width: 16),
                      Expanded(
                          flex: 1,
                          child: _StatsCard(driver: driver)),
                    ],
                  )
                : Column(
                    children: [
                      _ProfileCard(driver: driver),
                      const SizedBox(height: 16),
                      _VehicleCard(driver: driver),
                      const SizedBox(height: 16),
                      _StatsCard(driver: driver),
                    ],
                  );
          }),
          const SizedBox(height: 24),

          // Documents
          _DocumentsSection(driver: driver, driverId: driverId, ref: ref),
          const SizedBox(height: 24),

          // Ride history
          _RideHistoryCard(driverId: driverId),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  const _ProfileCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المعلومات الشخصية',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: driver['profile_photo_url'] != null
                        ? NetworkImage(driver['profile_photo_url'])
                        : null,
                    child: driver['profile_photo_url'] == null
                        ? const Icon(Icons.person,
                            size: 48, color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _statusColor(driver['status'] as String? ?? ''),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
                      ),
                      width: 20,
                      height: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    driver['full_name'] as String? ?? '—',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: driver['status'] as String? ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _InfoRow(
                icon: Icons.phone, label: 'الهاتف', value: driver['phone_number'] as String? ?? '—'),
            _InfoRow(
                icon: Icons.badge, label: 'رقم الهوية', value: driver['national_id_number'] as String? ?? '—'),
            _InfoRow(
                icon: Icons.card_membership,
                label: 'رقم الرخصة',
                value: driver['license_number'] as String? ?? '—'),
            if (driver['created_at'] != null)
              _InfoRow(
                icon: Icons.calendar_today,
                label: 'تاريخ التسجيل',
                value: DateFormat('yyyy/MM/dd').format(
                    DateTime.parse(driver['created_at'])),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'online':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'offline':
      default:
        return Colors.grey;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  const _VehicleCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final vehicles = driver['driver_vehicles'] as List? ?? [];
    final vehicle = vehicles.isNotEmpty
        ? vehicles.first as Map<String, dynamic>
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'معلومات المركبة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (vehicle == null)
              const Text('لا توجد معلومات مركبة',
                  style: TextStyle(color: AppColors.textSecondary))
            else ...[
              _InfoRow(
                  icon: Icons.directions_car,
                  label: 'نوع المركبة',
                  value: _vehicleLabel(vehicle['vehicle_type'] as String? ?? '')),
              _InfoRow(
                  icon: Icons.abc,
                  label: 'رقم اللوحة',
                  value: vehicle['plate_number'] as String? ?? '—'),
              _InfoRow(
                  icon: Icons.palette,
                  label: 'اللون',
                  value: vehicle['color'] as String? ?? '—'),
              _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'سنة الصنع',
                  value: vehicle['year'] != null
                      ? '${vehicle['year']}'
                      : '—'),
              _InfoRow(
                  icon: Icons.branding_watermark,
                  label: 'الماركة / الموديل',
                  value:
                      '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()),
            ],
          ],
        ),
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

class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  const _StatsCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإحصائيات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _StatTile(
              label: 'التقييم',
              value: driver['rating_avg'] != null
                  ? '${(driver['rating_avg'] as num).toStringAsFixed(1)} ★'
                  : '—',
              color: AppColors.warning,
            ),
            const Divider(height: 20),
            _StatTile(
              label: 'إجمالي الرحلات',
              value: '${driver['total_rides'] ?? 0}',
              color: AppColors.primary,
            ),
            const Divider(height: 20),
            _StatTile(
              label: 'النقاط',
              value: '${driver['loyalty_points'] ?? 0}',
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18, color: color)),
      ],
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final Map<String, dynamic> driver;
  final String driverId;
  final WidgetRef ref;

  const _DocumentsSection(
      {required this.driver, required this.driverId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final docs = driver['driver_documents'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الوثائق',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              const Text('لا توجد وثائق',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: docs.map((doc) {
                  return _DocumentCard(
                    doc: doc as Map<String, dynamic>,
                    ref: ref,
                    driverId: driverId,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final WidgetRef ref;
  final String driverId;

  const _DocumentCard(
      {required this.doc, required this.ref, required this.driverId});

  @override
  Widget build(BuildContext context) {
    final status = doc['status'] as String? ?? 'pending';
    final url = doc['document_url'] as String? ?? '';
    final type = doc['document_type'] as String? ?? '';

    return SizedBox(
      width: 200,
      child: Card(
        color: AppColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: GestureDetector(
                onTap: () => _showFullImage(context, url),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: url.isNotEmpty
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported,
                                  size: 48, color: Colors.grey),
                        )
                      : const Icon(Icons.description,
                          size: 48, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _docTypeLabel(type),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  StatusBadge(status: status),
                  if (status == 'pending') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectDoc(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('رفض', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveDoc(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('قبول', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(_docTypeLabel(doc['document_type'] as String? ?? '')),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close))
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 500, maxWidth: 600),
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.contain)
                  : const Icon(Icons.image_not_supported, size: 100),
            ),
          ],
        ),
      ),
    );
  }

  void _approveDoc(BuildContext context) {
    final service = SupabaseAdminService(ref.read(supabaseClientProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد'),
        content: Text('قبول الوثيقة: ${_docTypeLabel(doc['document_type'] as String? ?? '')}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await service.approveDriverDocument(doc['id'] as String, true);
              ref.refresh(_driverDetailProvider(driverId));
            },
            child: const Text('قبول'),
          ),
        ],
      ),
    );
  }

  void _rejectDoc(BuildContext context) {
    final service = SupabaseAdminService(ref.read(supabaseClientProvider));
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الوثيقة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_docTypeLabel(doc['document_type'] as String? ?? '')),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'سبب الرفض'),
              maxLines: 2,
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
            onPressed: () async {
              Navigator.pop(ctx);
              await service.approveDriverDocument(doc['id'] as String, false,
                  reason: reasonCtrl.text.trim());
              ref.refresh(_driverDetailProvider(driverId));
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  String _docTypeLabel(String type) {
    switch (type) {
      case 'national_id':
        return 'بطاقة الهوية';
      case 'driver_license':
        return 'رخصة القيادة';
      case 'vehicle_registration':
        return 'ترخيص المركبة';
      case 'insurance':
        return 'التأمين';
      case 'profile_photo':
        return 'الصورة الشخصية';
      default:
        return type;
    }
  }
}

class _RideHistoryCard extends ConsumerWidget {
  final String driverId;
  const _RideHistoryCard({required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(_driverRidesProvider(driverId));
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: '');
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'آخر الرحلات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          SizedBox(
            height: 320,
            child: ridesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('تعذر التحميل')),
              data: (rides) => rides.isEmpty
                  ? const Center(child: Text('لا توجد رحلات'))
                  : DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 16,
                      headingRowHeight: 44,
                      dataRowHeight: 50,
                      border: TableBorder(
                        horizontalInside:
                            BorderSide(color: Colors.grey.shade100),
                      ),
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.primary.withOpacity(0.04),
                      ),
                      columns: const [
                        DataColumn2(
                            label: Text('الراكب'), size: ColumnSize.M),
                        DataColumn2(
                            label: Text('نوع المركبة'),
                            size: ColumnSize.M),
                        DataColumn2(
                            label: Text('السعر'), size: ColumnSize.S, numeric: true),
                        DataColumn2(
                            label: Text('التاريخ'), size: ColumnSize.M),
                        DataColumn2(
                            label: Text('الحالة'), size: ColumnSize.S),
                      ],
                      rows: rides.map((ride) {
                        final passenger =
                            ride['passenger'] as Map? ?? {};
                        return DataRow2(
                          cells: [
                            DataCell(Text(
                                passenger['full_name'] as String? ?? '—')),
                            DataCell(Text(
                                _vehicleLabel(ride['vehicle_type'] as String? ?? ''))),
                            DataCell(Text(
                              currency.format(ride['fare_amount'] ?? 0),
                              textAlign: TextAlign.end,
                            )),
                            DataCell(Text(ride['created_at'] != null
                                ? dateFormat.format(
                                    DateTime.parse(ride['created_at']))
                                : '—')),
                            DataCell(StatusBadge(
                                status: ride['status'] as String? ?? '')),
                          ],
                        );
                      }).toList(),
                    ),
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

class _ActionButtonsBar extends StatelessWidget {
  final Map<String, dynamic> driver;
  final String driverId;
  final WidgetRef ref;

  const _ActionButtonsBar(
      {required this.driver, required this.driverId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = driver['status'] as String? ?? '';
    final service = SupabaseAdminService(ref.read(supabaseClientProvider));

    return Wrap(
      spacing: 8,
      children: [
        if (status == 'pending') ...[
          OutlinedButton.icon(
            onPressed: () => _reject(context, service),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('رفض'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _approve(context, service),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('قبول'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
          ),
        ] else if (status == 'active') ...[
          ElevatedButton.icon(
            onPressed: () => _suspend(context, service),
            icon: const Icon(Icons.block, size: 18),
            label: const Text('إيقاف'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
          ),
        ] else if (status == 'suspended') ...[
          ElevatedButton.icon(
            onPressed: () => _activate(context, service),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('تفعيل'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
          ),
        ] else if (status == 'rejected') ...[
          ElevatedButton.icon(
            onPressed: () => _activate(context, service),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة تفعيل'),
          ),
        ],
      ],
    );
  }

  void _approve(BuildContext context, SupabaseAdminService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد القبول'),
        content: const Text('هل تريد قبول هذا السائق؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('قبول')),
        ],
      ),
    );
    if (confirm == true) {
      await service.updateDriverStatus(driverId, 'active');
      ref.refresh(_driverDetailProvider(driverId));
    }
  }

  void _reject(BuildContext context, SupabaseAdminService service) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض السائق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل سبب الرفض:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'السبب'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await service.updateDriverStatus(driverId, 'rejected',
          reason: reasonCtrl.text.trim());
      ref.refresh(_driverDetailProvider(driverId));
    }
  }

  void _suspend(BuildContext context, SupabaseAdminService service) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إيقاف السائق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل سبب الإيقاف:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'السبب'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إيقاف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await service.updateDriverStatus(driverId, 'suspended',
          reason: reasonCtrl.text.trim());
      ref.refresh(_driverDetailProvider(driverId));
    }
  }

  void _activate(BuildContext context, SupabaseAdminService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل السائق'),
        content: const Text('هل تريد تفعيل هذا السائق؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تفعيل')),
        ],
      ),
    );
    if (confirm == true) {
      await service.updateDriverStatus(driverId, 'active');
      ref.refresh(_driverDetailProvider(driverId));
    }
  }
}
