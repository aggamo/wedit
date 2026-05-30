import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/fleet_provider.dart';

class FleetDashboardScreen extends ConsumerWidget {
  const FleetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = Supabase.instance.client.auth.currentUser!.id;
    final statsAsync = ref.watch(fleetDashboardProvider(ownerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        automaticallyImplyLeading: false,
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(fleetDashboardProvider(ownerId).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                icon: Icons.directions_car_rounded,
                label: 'إجمالي السيارات',
                value: '${stats['total_vehicles']}',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.person_rounded,
                label: 'السائقون النشطون',
                value: '${stats['active_drivers']}',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.today_rounded,
                label: 'رحلات اليوم',
                value: '${stats['today_rides']}',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.attach_money_rounded,
                label: 'إيرادات اليوم (بر)',
                value: (stats['today_fare'] as double).toStringAsFixed(0),
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.calendar_month_rounded,
                label: 'إيرادات الشهر (بر)',
                value: (stats['month_fare'] as double).toStringAsFixed(0),
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
