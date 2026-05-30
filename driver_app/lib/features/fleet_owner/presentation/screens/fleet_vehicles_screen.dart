import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetVehiclesScreen extends ConsumerWidget {
  const FleetVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = Supabase.instance.client.auth.currentUser!.id;
    final vehiclesAsync = ref.watch(fleetVehiclesProvider(ownerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('السيارات'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicleDialog(context, ref, ownerId),
        icon: const Icon(Icons.add),
        label: const Text('إضافة سيارة'),
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد سيارات مسجلة بعد',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(fleetVehiclesProvider(ownerId).future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final v = vehicles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: v.isCarActive
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: v.isCarActive ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(v.plateNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${v.model ?? ''} ${v.color ?? ''} ${v.year ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/fleet/vehicle/${v.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddVehicleDialog(
      BuildContext context, WidgetRef ref, String ownerId) {
    final plateCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    String vehicleType = 'sedan';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إضافة سيارة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(labelText: 'رقم اللوحة *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: vehicleType,
                  decoration: const InputDecoration(labelText: 'نوع السيارة'),
                  items: const [
                    DropdownMenuItem(value: 'sedan', child: Text('سيدان')),
                    DropdownMenuItem(value: 'suv', child: Text('SUV')),
                    DropdownMenuItem(value: 'vip', child: Text('VIP')),
                    DropdownMenuItem(value: 'minibus', child: Text('ميني باص')),
                  ],
                  onChanged: (v) => setState(() => vehicleType = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: 'الموديل'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: 'اللون'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(labelText: 'سنة الصنع'),
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
                if (plateCtrl.text.trim().isEmpty) return;
                try {
                  await ref.read(fleetRepositoryProvider).addVehicle(
                        ownerId: ownerId,
                        plateNumber: plateCtrl.text.trim(),
                        vehicleType: vehicleType,
                        model: modelCtrl.text.trim().isEmpty
                            ? null
                            : modelCtrl.text.trim(),
                        color: colorCtrl.text.trim().isEmpty
                            ? null
                            : colorCtrl.text.trim(),
                        year: int.tryParse(yearCtrl.text.trim()),
                      );
                  ref.invalidate(fleetVehiclesProvider(ownerId));
                  if (ctx.mounted) Navigator.pop(ctx);
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
