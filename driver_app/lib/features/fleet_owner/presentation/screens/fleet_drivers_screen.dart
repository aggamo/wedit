import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetDriversScreen extends ConsumerWidget {
  const FleetDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = Supabase.instance.client.auth.currentUser!.id;
    final assignmentsAsync = ref.watch(fleetAssignmentsProvider(ownerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('السائقون'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDriverDialog(context, ref, ownerId),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('إضافة سائق'),
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا يوجد سائقون مرتبطون بعد',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(fleetAssignmentsProvider(ownerId).future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final a = assignments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.person_rounded)),
                    title: Text(a.driverName.isEmpty
                        ? a.driverPhone
                        : a.driverName,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_shareLabel(
                        a.revenueShareType, a.revenueShareValue)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        Text(a.driverRating.toStringAsFixed(1)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _shareLabel(String type, int value) {
    switch (type) {
      case 'percentage':
        return 'نسبة $value% للسائق';
      case 'daily_rent':
        return 'إيجار يومي $value بر';
      case 'weekly_rent':
        return 'إيجار أسبوعي $value بر';
      case 'monthly_rent':
        return 'إيجار شهري $value بر';
      default:
        return '';
    }
  }

  void _showAddDriverDialog(
      BuildContext context, WidgetRef ref, String ownerId) {
    final phoneCtrl = TextEditingController();
    String revenueShareType = 'percentage';
    final valueCtrl = TextEditingController(text: '40');
    String? selectedVehicleId;

    final vehiclesAsync = ref.read(fleetVehiclesProvider(ownerId));
    final vehicles =
        vehiclesAsync.valueOrNull?.where((v) => v.isCarActive).toList() ?? [];
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إضافة سيارة أولاً')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إضافة سائق'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف (+251...)',
                      prefixText: '+'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: selectedVehicleId,
                  decoration: const InputDecoration(labelText: 'السيارة'),
                  items: vehicles
                      .map((v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(v.plateNumber),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => selectedVehicleId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: revenueShareType,
                  decoration: const InputDecoration(labelText: 'نموذج العمل'),
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
                  onChanged: (v) =>
                      setState(() => revenueShareType = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueCtrl,
                  decoration: InputDecoration(
                    labelText: revenueShareType == 'percentage'
                        ? 'النسبة للسائق (%)'
                        : 'المبلغ (بر)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final phone = phoneCtrl.text.trim();
                final value = int.tryParse(valueCtrl.text.trim()) ?? 0;
                if (phone.isEmpty || selectedVehicleId == null) return;

                try {
                  await ref.read(fleetRepositoryProvider).inviteDriver(
                        phone: '+$phone',
                        fleetOwnerId: ownerId,
                        fleetVehicleId: selectedVehicleId!,
                        revenueShareType: revenueShareType,
                        revenueShareValue: value,
                      );
                  ref.invalidate(fleetAssignmentsProvider(ownerId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إضافة السائق بنجاح')));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}
