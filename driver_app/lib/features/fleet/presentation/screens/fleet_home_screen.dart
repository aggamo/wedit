import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/fleet_provider.dart';

// ---------------------------------------------------------------------------
// Local data models
// ---------------------------------------------------------------------------

class _FleetStats {
  final int activeDrivers;
  final int activeVehicles;
  final double todayEarnings;

  const _FleetStats({
    required this.activeDrivers,
    required this.activeVehicles,
    required this.todayEarnings,
  });
}

class _FleetDriver {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? plateNumber;
  final String? vehicleType;
  final bool isOnline;
  final int todayTrips;

  const _FleetDriver({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.plateNumber,
    this.vehicleType,
    required this.isOnline,
    required this.todayTrips,
  });
}

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

final _fleetStatsProvider = FutureProvider<_FleetStats>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ownerId = ref.watch(fleetOwnerIdProvider);
  if (ownerId.isEmpty) return const _FleetStats(activeDrivers: 0, activeVehicles: 0, todayEarnings: 0);

  // Active vehicles count
  final vehiclesRes = await supabase
      .from('fleet_vehicles')
      .select('id')
      .eq('fleet_owner_id', ownerId)
      .eq('is_active', true);

  // Active drivers (is_car_active = true)
  final driversRes = await supabase
      .from('drivers')
      .select('id')
      .eq('fleet_owner_id', ownerId)
      .eq('is_car_active', true);

  // Today's earnings from completed rides
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
  final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

  final driverIds = (driversRes as List).map((d) => d['id'] as String).toList();
  double todayEarnings = 0;
  if (driverIds.isNotEmpty) {
    final ridesRes = await supabase
        .from('rides')
        .select('fare')
        .inFilter('driver_id', driverIds)
        .eq('status', 'completed')
        .gte('completed_at', startOfDay)
        .lte('completed_at', endOfDay);

    for (final ride in (ridesRes as List)) {
      todayEarnings += (ride['fare'] as num?)?.toDouble() ?? 0;
    }
  }

  return _FleetStats(
    activeDrivers: (driversRes as List).length,
    activeVehicles: (vehiclesRes as List).length,
    todayEarnings: todayEarnings,
  );
});

final _fleetDriversListProvider = FutureProvider<List<_FleetDriver>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ownerId = ref.watch(fleetOwnerIdProvider);
  if (ownerId.isEmpty) return [];

  final data = await supabase
      .from('drivers')
      .select('id, fleet_vehicle_id, is_car_active, daily_trips_count, fleet_vehicles(plate_number, type), profiles(full_name, avatar_url)')
      .eq('fleet_owner_id', ownerId)
      .order('created_at');

  return (data as List).map((row) {
    final vehicle = row['fleet_vehicles'] as Map<String, dynamic>?;
    final profile = row['profiles'] as Map<String, dynamic>?;
    return _FleetDriver(
      id: row['id'] as String,
      name: (profile?['full_name'] as String?) ?? 'سائق',
      avatarUrl: profile?['avatar_url'] as String?,
      plateNumber: vehicle?['plate_number'] as String?,
      vehicleType: vehicle?['type'] as String?,
      isOnline: (row['is_car_active'] as bool?) ?? false,
      todayTrips: (row['daily_trips_count'] as int?) ?? 0,
    );
  }).toList();
});

// ---------------------------------------------------------------------------
// FleetHomeScreen
// ---------------------------------------------------------------------------

class FleetHomeScreen extends ConsumerWidget {
  const FleetHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_fleetStatsProvider);
    final driversAsync = ref.watch(_fleetDriversListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الأسطول'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/home/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_fleetStatsProvider);
          ref.invalidate(_fleetDriversListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats row
            statsAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (stats) => _StatsRow(stats: stats),
            ),

            const SizedBox(height: 20),

            // Quick navigation cards
            Row(
              children: [
                Expanded(
                  child: _QuickNavCard(
                    icon: Icons.directions_car_outlined,
                    label: 'المركبات',
                    color: AppTheme.primaryColor,
                    onTap: () => context.push('/fleet/vehicles'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickNavCard(
                    icon: Icons.people_outline,
                    label: 'السائقون',
                    color: AppTheme.onlineColor,
                    onTap: () => context.push('/fleet/drivers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickNavCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'التسويات',
                    color: AppTheme.tertiaryColor,
                    onTap: () => context.push('/fleet/settlements'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Drivers list header
            const Text(
              'سائقو الأسطول',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Drivers list
            driversAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (drivers) {
                if (drivers.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.people_outline,
                    message: 'لا يوجد سائقون في أسطولك بعد',
                  );
                }
                return Column(
                  children: drivers.map((d) => _DriverTile(driver: d)).toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
        onPressed: () => _showQuickActionsSheet(context),
      ),
    );
  }

  void _showQuickActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Icon(Icons.person_add_outlined, color: Colors.white),
              ),
              title: const Text('إضافة سائق'),
              onTap: () {
                Navigator.pop(context);
                context.push('/fleet/drivers');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.onlineColor,
                child: Icon(Icons.directions_car_outlined, color: Colors.white),
              ),
              title: const Text('إضافة مركبة'),
              onTap: () {
                Navigator.pop(context);
                context.push('/fleet/vehicles');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final _FleetStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'سائقون نشطون',
            value: '${stats.activeDrivers}',
            icon: Icons.people_outline,
            color: AppTheme.onlineColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'مركبات نشطة',
            value: '${stats.activeVehicles}',
            icon: Icons.directions_car_outlined,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'أرباح اليوم',
            value: '${stats.todayEarnings.toStringAsFixed(0)} ب',
            icon: Icons.attach_money,
            color: AppTheme.tertiaryColor,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuickNavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickNavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverTile extends StatelessWidget {
  final _FleetDriver driver;
  const _DriverTile({required this.driver});

  @override
  Widget build(BuildContext context) {
    final initial = driver.name.isNotEmpty ? driver.name[0] : 'S';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: driver.isOnline ? AppTheme.onlineColor : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          driver.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          driver.plateNumber != null
              ? '${driver.plateNumber} · ${driver.vehicleType ?? ''}'
              : 'لا توجد مركبة مرتبطة',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${driver.todayTrips} رحلة',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              driver.isOnline ? 'متصل' : 'غير متصل',
              style: TextStyle(
                fontSize: 11,
                color: driver.isOnline ? AppTheme.onlineColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
