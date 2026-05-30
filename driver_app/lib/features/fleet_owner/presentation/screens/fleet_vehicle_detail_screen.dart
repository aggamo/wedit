import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetVehicleDetailScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const FleetVehicleDetailScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<FleetVehicleDetailScreen> createState() =>
      _FleetVehicleDetailScreenState();
}

class _FleetVehicleDetailScreenState
    extends ConsumerState<FleetVehicleDetailScreen> {
  final ownerId = Supabase.instance.client.auth.currentUser!.id;

  String _revenueShareType = 'percentage';
  final _valueCtrl = TextEditingController(text: '40');
  final _maxTripsCtrl = TextEditingController();
  String _settlementCycle = 'weekly';
  bool _isSaving = false;
  String? _assignmentId;
  String? _driverId;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    final data = await Supabase.instance.client
        .from('fleet_driver_assignments')
        .select('''
          id, driver_id, revenue_share_type, revenue_share_value,
          max_daily_trips, settlement_cycle, is_active
        ''')
        .eq('fleet_vehicle_id', widget.vehicleId)
        .maybeSingle();

    if (data != null && mounted) {
      setState(() {
        _assignmentId = data['id'] as String;
        _driverId = data['driver_id'] as String;
        _revenueShareType = data['revenue_share_type'] as String;
        _valueCtrl.text = '${data['revenue_share_value']}';
        _maxTripsCtrl.text =
            data['max_daily_trips'] != null ? '${data['max_daily_trips']}' : '';
        _settlementCycle = data['settlement_cycle'] as String;
      });
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _maxTripsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_assignmentId == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(fleetRepositoryProvider).updateAssignment(
            assignmentId: _assignmentId!,
            revenueShareType: _revenueShareType,
            revenueShareValue: int.tryParse(_valueCtrl.text) ?? 0,
            settlementCycle: _settlementCycle,
            maxDailyTrips: int.tryParse(_maxTripsCtrl.text),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ الإعدادات')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleCarActive(bool currentActive) async {
    try {
      await ref
          .read(fleetRepositoryProvider)
          .updateVehicleActiveStatus(widget.vehicleId, !currentActive);
      ref.invalidate(fleetVehiclesProvider(ownerId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(currentActive
                ? 'تم تعطيل السيارة'
                : 'تم تفعيل السيارة')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _unlinkDriver() async {
    if (_assignmentId == null || _driverId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فصل السائق'),
        content: const Text(
            'هل أنت متأكد من فصل هذا السائق؟ سيتم إشعاره فوراً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('فصل')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(fleetRepositoryProvider)
          .unlinkDriver(_assignmentId!, _driverId!);
      ref.invalidate(fleetAssignmentsProvider(ownerId));
      if (mounted) {
        setState(() {
          _assignmentId = null;
          _driverId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم فصل السائق')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(fleetVehiclesProvider(ownerId));
    final vehicle = vehiclesAsync.valueOrNull
        ?.firstWhere((v) => v.id == widget.vehicleId,
            orElse: () => throw Exception('not found'));

    return Scaffold(
      appBar: AppBar(title: Text(vehicle?.plateNumber ?? 'تفاصيل السيارة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vehicle status toggle
          if (vehicle != null)
            Card(
              child: SwitchListTile(
                title: const Text('السيارة مفعّلة'),
                subtitle: Text(vehicle.isCarActive
                    ? 'تستقبل الطلبات حالياً'
                    : 'موقوفة مؤقتاً'),
                value: vehicle.isCarActive,
                onChanged: (_) => _toggleCarActive(vehicle.isCarActive),
              ),
            ),

          const SizedBox(height: 16),

          if (_assignmentId != null) ...[
            const Text('نموذج العمل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: _revenueShareType,
              decoration: const InputDecoration(
                  labelText: 'نوع نموذج العمل', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'percentage', child: Text('نسبة مئوية')),
                DropdownMenuItem(
                    value: 'daily_rent', child: Text('إيجار يومي')),
                DropdownMenuItem(
                    value: 'weekly_rent', child: Text('إيجار أسبوعي')),
                DropdownMenuItem(
                    value: 'monthly_rent', child: Text('إيجار شهري')),
              ],
              onChanged: (v) => setState(() => _revenueShareType = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _valueCtrl,
              decoration: InputDecoration(
                labelText: _revenueShareType == 'percentage'
                    ? 'نسبة السائق (%)'
                    : 'مبلغ الإيجار (بر)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _settlementCycle,
              decoration: const InputDecoration(
                  labelText: 'دورة التسوية', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('يومي')),
                DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                DropdownMenuItem(value: 'monthly', child: Text('شهري')),
              ],
              onChanged: (v) => setState(() => _settlementCycle = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _maxTripsCtrl,
              decoration: const InputDecoration(
                labelText: 'الحد الأقصى للرحلات اليومية (اتركه فارغاً لعدم التحديد)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ الإعدادات'),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _unlinkDriver,
              icon: const Icon(Icons.person_remove_rounded, color: Colors.red),
              label: const Text('فصل السائق',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red)),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا يوجد سائق مرتبط بهذه السيارة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}
