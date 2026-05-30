import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FleetOwnersPage extends StatefulWidget {
  const FleetOwnersPage({super.key});

  @override
  State<FleetOwnersPage> createState() => _FleetOwnersPageState();
}

class _FleetOwnersPageState extends State<FleetOwnersPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _owners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase.from('fleet_owners').select('''
        id, company_name, is_active, subscription_expiry,
        profiles!id(full_name, phone),
        fleet_owner_subscription_plans(name, max_vehicles),
        fleet_vehicles(count)
      ''').order('created_at', ascending: false);
      if (mounted) setState(() => _owners = List<Map<String, dynamic>>.from(data as List));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(String ownerId, bool current) async {
    try {
      await _supabase
          .from('fleet_owners')
          .update({'is_active': !current})
          .eq('id', ownerId);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('مالكو الأساطيل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _owners.isEmpty
              ? const Center(child: Text('لا يوجد مالكو أساطيل بعد'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _owners.length,
                    itemBuilder: (context, index) {
                      final o = _owners[index];
                      final profile = o['profiles'] as Map<String, dynamic>?;
                      final plan = o['fleet_owner_subscription_plans']
                          as Map<String, dynamic>?;
                      final isActive = o['is_active'] as bool? ?? false;
                      final expiry = o['subscription_expiry'] != null
                          ? DateTime.tryParse(
                              o['subscription_expiry'] as String)
                          : null;
                      final isExpired =
                          expiry != null && expiry.isBefore(DateTime.now());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive && !isExpired
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            child: Icon(
                              Icons.business_rounded,
                              color: isActive && !isExpired
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          title: Text(
                            o['company_name'] as String? ??
                                profile?['full_name'] as String? ??
                                'غير محدد',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile?['phone'] as String? ?? ''),
                              Text(
                                plan?['name'] as String? ?? 'بدون خطة',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (isExpired)
                                const Text('منتهي الصلاحية',
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 12)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: (_) =>
                                    _toggleActive(o['id'] as String, isActive),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => context
                                    .push('/dashboard/fleet-owners/${o['id']}'),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
