import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/fleet_provider.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _FleetVehicle {
  final String id;
  final String plateNumber;
  final String type;
  final String? model;
  final int? year;
  final String? color;
  final bool isActive;

  const _FleetVehicle({
    required this.id,
    required this.plateNumber,
    required this.type,
    this.model,
    this.year,
    this.color,
    required this.isActive,
  });

  _FleetVehicle copyWith({bool? isActive}) {
    return _FleetVehicle(
      id: id,
      plateNumber: plateNumber,
      type: type,
      model: model,
      year: year,
      color: color,
      isActive: isActive ?? this.isActive,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _vehiclesProvider = FutureProvider<List<_FleetVehicle>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ownerId = ref.watch(fleetOwnerIdProvider);
  if (ownerId.isEmpty) return [];

  final data = await supabase
      .from('fleet_vehicles')
      .select()
      .eq('fleet_owner_id', ownerId)
      .order('created_at');

  return (data as List).map((row) {
    return _FleetVehicle(
      id: row['id'] as String,
      plateNumber: row['plate_number'] as String? ?? '',
      type: row['type'] as String? ?? 'sedan',
      model: row['model'] as String?,
      year: row['year'] as int?,
      color: row['color'] as String?,
      isActive: (row['is_active'] as bool?) ?? true,
    );
  }).toList();
});

// ---------------------------------------------------------------------------
// FleetVehiclesScreen
// ---------------------------------------------------------------------------

class FleetVehiclesScreen extends ConsumerStatefulWidget {
  const FleetVehiclesScreen({super.key});

  @override
  ConsumerState<FleetVehiclesScreen> createState() => _FleetVehiclesScreenState();
}

class _FleetVehiclesScreenState extends ConsumerState<FleetVehiclesScreen> {
  // Local override map: vehicleId -> isActive (for optimistic UI)
  final Map<String, bool> _localStatus = {};

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(_vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('مركبات الأسطول')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_vehiclesProvider),
        child: vehiclesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('خطأ: ${e.toString()}'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(_vehiclesProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          data: (vehicles) {
            if (vehicles.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('لا توجد مركبات بعد', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('أضف مركبتك الأولى بالضغط على +', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (_, i) {
                final v = vehicles[i];
                final isActive = _localStatus[v.id] ?? v.isActive;
                return _VehicleCard(
                  vehicle: v.copyWith(isActive: isActive),
                  onToggle: (val) async {
                    setState(() => _localStatus[v.id] = val);
                    await ref.read(fleetNotifierProvider.notifier).toggleVehicleStatus(v.id, val);
                    ref.invalidate(_vehiclesProvider);
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showAddVehicleSheet(context),
      ),
    );
  }

  void _showAddVehicleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddVehicleSheet(
        onSubmit: (plate, type, model, year, color) async {
          final ok = await ref.read(fleetNotifierProvider.notifier).addVehicle(
            plateNumber: plate,
            type: type,
            model: model,
            year: year,
            color: color,
          );
          if (ok) {
            ref.invalidate(_vehiclesProvider);
            if (context.mounted) Navigator.pop(context);
          } else {
            final err = ref.read(fleetNotifierProvider).error;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err ?? 'حدث خطأ'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vehicle card widget
// ---------------------------------------------------------------------------

class _VehicleCard extends StatelessWidget {
  final _FleetVehicle vehicle;
  final ValueChanged<bool> onToggle;

  const _VehicleCard({required this.vehicle, required this.onToggle});

  String get _typeLabel {
    switch (vehicle.type) {
      case 'sedan':
        return 'سيدان';
      case 'suv':
        return 'SUV';
      case 'vip':
        return 'VIP';
      case 'minibus':
        return 'ميني باص';
      default:
        return vehicle.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: vehicle.isActive
                    ? AppTheme.onlineColor.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_car,
                color: vehicle.isActive ? AppTheme.onlineColor : Colors.grey,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.plateNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _typeLabel,
                      if (vehicle.model != null) vehicle.model!,
                      if (vehicle.year != null) vehicle.year.toString(),
                      if (vehicle.color != null) vehicle.color!,
                    ].join(' · '),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: vehicle.isActive,
                  onChanged: onToggle,
                  activeColor: AppTheme.onlineColor,
                ),
                Text(
                  vehicle.isActive ? 'نشطة' : 'متوقفة',
                  style: TextStyle(
                    fontSize: 10,
                    color: vehicle.isActive ? AppTheme.onlineColor : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add vehicle bottom sheet
// ---------------------------------------------------------------------------

class _AddVehicleSheet extends StatefulWidget {
  final Future<void> Function(String plate, String type, String model, int year, String color) onSubmit;

  const _AddVehicleSheet({required this.onSubmit});

  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  String _selectedType = 'sedan';
  bool _isLoading = false;

  static const _vehicleTypes = [
    ('sedan', 'سيدان'),
    ('suv', 'SUV'),
    ('vip', 'VIP'),
    ('minibus', 'ميني باص'),
  ];

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'إضافة مركبة جديدة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Plate number
            TextFormField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: 'رقم اللوحة',
                prefixIcon: Icon(Icons.credit_card),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'رقم اللوحة مطلوب' : null,
            ),
            const SizedBox(height: 12),

            // Type dropdown
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'نوع المركبة',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _vehicleTypes
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 12),

            // Model
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'الموديل',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الموديل مطلوب' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Year
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سنة الصنع',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'السنة مطلوبة';
                      final year = int.tryParse(v.trim());
                      if (year == null || year < 1990 || year > 2030) return 'سنة غير صحيحة';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Color
                Expanded(
                  child: TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'اللون',
                      prefixIcon: Icon(Icons.color_lens_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'اللون مطلوب' : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _isLoading = true);
                      await widget.onSubmit(
                        _plateController.text.trim(),
                        _selectedType,
                        _modelController.text.trim(),
                        int.parse(_yearController.text.trim()),
                        _colorController.text.trim(),
                      );
                      if (mounted) setState(() => _isLoading = false);
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إضافة المركبة'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
