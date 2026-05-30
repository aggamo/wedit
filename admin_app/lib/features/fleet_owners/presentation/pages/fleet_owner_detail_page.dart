import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FleetOwnerDetailPage extends StatefulWidget {
  final String ownerId;

  const FleetOwnerDetailPage({super.key, required this.ownerId});

  @override
  State<FleetOwnerDetailPage> createState() => _FleetOwnerDetailPageState();
}

class _FleetOwnerDetailPageState extends State<FleetOwnerDetailPage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _owner;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final owner = await _supabase.from('fleet_owners').select('''
        *,
        profiles!id(full_name, phone, email),
        fleet_owner_subscription_plans(id, name, max_vehicles, monthly_fee_etb)
      ''').eq('id', widget.ownerId).single();

      final plans = await _supabase
          .from('fleet_owner_subscription_plans')
          .select()
          .eq('is_active', true);

      final vehicles = await _supabase
          .from('fleet_vehicles')
          .select('''
            *, fleet_driver_assignments(
              driver_id, revenue_share_type, revenue_share_value, is_active,
              profiles!driver_id(full_name, phone)
            )
          ''')
          .eq('fleet_owner_id', widget.ownerId);

      if (mounted) {
        setState(() {
          _owner = owner as Map<String, dynamic>;
          _plans = List<Map<String, dynamic>>.from(plans as List);
          _vehicles = List<Map<String, dynamic>>.from(vehicles as List);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePlan(String planId) async {
    try {
      await _supabase.from('fleet_owners').update({
        'subscription_plan_id': planId,
        'subscription_expiry':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      }).eq('id', widget.ownerId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_owner == null) {
      return const Scaffold(body: Center(child: Text('لم يتم العثور على المالك')));
    }

    final profile = _owner!['profiles'] as Map<String, dynamic>?;
    final currentPlan = _owner!['fleet_owner_subscription_plans']
        as Map<String, dynamic>?;
    final isActive = _owner!['is_active'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_owner!['company_name'] as String? ?? profile?['full_name'] as String? ?? ''),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Owner info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('معلومات المالك',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _info('الاسم', profile?['full_name'] ?? '—'),
                  _info('الهاتف', profile?['phone'] ?? '—'),
                  _info('الخطة الحالية', currentPlan?['name'] ?? 'بدون خطة'),
                  _info(
                    'انتهاء الاشتراك',
                    _owner!['subscription_expiry'] != null
                        ? (_owner!['subscription_expiry'] as String).split('T')[0]
                        : '—',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('الحساب مفعّل: '),
                      Switch(
                        value: isActive,
                        onChanged: (_) async {
                          await _supabase
                              .from('fleet_owners')
                              .update({'is_active': !isActive})
                              .eq('id', widget.ownerId);
                          _load();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Change plan
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تغيير خطة الاشتراك',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ..._plans.map(
                    (plan) => ListTile(
                      title: Text(plan['name'] as String),
                      subtitle: Text(
                          '${plan['max_vehicles']} سيارة - ${plan['monthly_fee_etb']} بر/شهر'),
                      trailing: currentPlan?['id'] == plan['id']
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : FilledButton(
                              onPressed: () => _changePlan(plan['id'] as String),
                              child: const Text('تطبيق'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Vehicles list
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('السيارات (${_vehicles.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ..._vehicles.map((v) {
                    final assignments =
                        v['fleet_driver_assignments'] as List? ?? [];
                    final activeAssignment = assignments.firstWhere(
                      (a) => a['is_active'] == true,
                      orElse: () => null,
                    );
                    final driverProfile = activeAssignment != null
                        ? activeAssignment['profiles'] as Map<String, dynamic>?
                        : null;

                    return ListTile(
                      leading: const Icon(Icons.directions_car_rounded),
                      title: Text(v['plate_number'] as String),
                      subtitle: Text(driverProfile != null
                          ? 'السائق: ${driverProfile['full_name'] ?? driverProfile['phone']}'
                          : 'بدون سائق'),
                      trailing: Icon(
                        v['is_car_active'] == true
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: v['is_car_active'] == true
                            ? Colors.green
                            : Colors.red,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
