import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/fleet_provider.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _InvitedDriver {
  final String id;
  final String phone;
  final String status;
  final DateTime createdAt;

  const _InvitedDriver({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdAt,
  });
}

class _ActiveDriver {
  final String id;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final double? sharePercent;

  const _ActiveDriver({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.sharePercent,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _invitationsProvider = FutureProvider<List<_InvitedDriver>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ownerId = ref.watch(fleetOwnerIdProvider);
  if (ownerId.isEmpty) return [];

  final data = await supabase
      .from('fleet_driver_invitations')
      .select('id, phone, status, created_at')
      .eq('fleet_owner_id', ownerId)
      .order('created_at', ascending: false);

  return (data as List).map((row) => _InvitedDriver(
        id: row['id'] as String,
        phone: row['phone'] as String? ?? '',
        status: row['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      )).toList();
});

final _activeDriversProvider = FutureProvider<List<_ActiveDriver>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final ownerId = ref.watch(fleetOwnerIdProvider);
  if (ownerId.isEmpty) return [];

  final data = await supabase
      .from('drivers')
      .select('id, driver_share_percent, profiles(full_name, avatar_url, phone)')
      .eq('fleet_owner_id', ownerId)
      .order('created_at');

  return (data as List).map((row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return _ActiveDriver(
      id: row['id'] as String,
      name: (profile?['full_name'] as String?) ?? 'سائق',
      phone: profile?['phone'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      sharePercent: (row['driver_share_percent'] as num?)?.toDouble(),
    );
  }).toList();
});

// ---------------------------------------------------------------------------
// Helper: generate temp password
// ---------------------------------------------------------------------------

String _generateTempPassword() {
  final rng = Random();
  final digits = List.generate(6, (_) => rng.nextInt(10)).join();
  return 'WD$digits';
}

// ---------------------------------------------------------------------------
// FleetDriversScreen
// ---------------------------------------------------------------------------

class FleetDriversScreen extends ConsumerWidget {
  const FleetDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سائقو الأسطول'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'نشطون'),
              Tab(text: 'الدعوات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActiveDriversTab(),
            _InvitationsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('دعوة سائق'),
          onPressed: () => _showInviteSheet(context, ref),
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _InviteDriverSheet(
        onSubmit: (phone) async {
          final tempPassword = _generateTempPassword();
          final result = await ref.read(fleetNotifierProvider.notifier).inviteDriver(
            phone: phone,
            tempPassword: tempPassword,
          );

          if (result != null) {
            ref.invalidate(_invitationsProvider);
            if (context.mounted) {
              Navigator.pop(context);
              _showPasswordDialog(context, phone, result);
            }
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

  void _showPasswordDialog(BuildContext context, String phone, String password) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تمت الدعوة بنجاح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تم إرسال دعوة إلى $phone'),
            const SizedBox(height: 16),
            const Text(
              'كلمة المرور المؤقتة:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      password,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ كلمة المرور')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'شارك هذه الكلمة مع السائق ليتمكن من تسجيل الدخول.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active drivers tab
// ---------------------------------------------------------------------------

class _ActiveDriversTab extends ConsumerWidget {
  const _ActiveDriversTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(_activeDriversProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_activeDriversProvider),
      child: driversAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: ${e.toString()}')),
        data: (drivers) {
          if (drivers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا يوجد سائقون نشطون', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (_, i) => _ActiveDriverTile(
              driver: drivers[i],
              onEditShare: () => _showEditShareDialog(context, ref, drivers[i]),
              onRemove: () => _confirmRemove(context, ref, drivers[i]),
            ),
          );
        },
      ),
    );
  }

  void _showEditShareDialog(BuildContext context, WidgetRef ref, _ActiveDriver driver) {
    final controller = TextEditingController(
      text: driver.sharePercent?.toStringAsFixed(0) ?? '70',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تعديل نسبة ${driver.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'نسبة حصة السائق (%)',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val == null || val < 0 || val > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('قيمة غير صحيحة')),
                );
                return;
              }
              Navigator.pop(context);
              await ref.read(fleetNotifierProvider.notifier).updateDriverShare(driver.id, val);
              ref.invalidate(_activeDriversProvider);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, _ActiveDriver driver) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فصل السائق'),
        content: Text('هل أنت متأكد من فصل ${driver.name} من الأسطول؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(fleetNotifierProvider.notifier).removeDriver(driver.id);
              ref.invalidate(_activeDriversProvider);
            },
            child: const Text('فصل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ActiveDriverTile extends StatelessWidget {
  final _ActiveDriver driver;
  final VoidCallback onEditShare;
  final VoidCallback onRemove;

  const _ActiveDriverTile({
    required this.driver,
    required this.onEditShare,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final initial = driver.name.isNotEmpty ? driver.name[0] : 'S';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            initial,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        title: Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(driver.phone ?? '', style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'share') onEditShare();
            if (action == 'remove') onRemove();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Text('عرض التفاصيل'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.percent, size: 18),
                  SizedBox(width: 8),
                  Text('تعديل نسبة الأرباح'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove_outlined, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('فصل السائق', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitations tab
// ---------------------------------------------------------------------------

class _InvitationsTab extends ConsumerWidget {
  const _InvitationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(_invitationsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_invitationsProvider),
      child: invitationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: ${e.toString()}')),
        data: (invitations) {
          if (invitations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد دعوات بعد', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invitations.length,
            itemBuilder: (_, i) => _InvitationTile(invitation: invitations[i]),
          );
        },
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final _InvitedDriver invitation;
  const _InvitationTile({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final isPending = invitation.status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPending
              ? Colors.orange.withOpacity(0.1)
              : AppTheme.onlineColor.withOpacity(0.1),
          child: Icon(
            isPending ? Icons.hourglass_empty : Icons.check_circle_outline,
            color: isPending ? Colors.orange : AppTheme.onlineColor,
            size: 22,
          ),
        ),
        title: Text(invitation.phone, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isPending ? 'في انتظار القبول' : 'تم القبول',
          style: TextStyle(
            fontSize: 12,
            color: isPending ? Colors.orange : AppTheme.onlineColor,
          ),
        ),
        trailing: Text(
          '${invitation.createdAt.day}/${invitation.createdAt.month}/${invitation.createdAt.year}',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite driver bottom sheet
// ---------------------------------------------------------------------------

class _InviteDriverSheet extends StatefulWidget {
  final Future<void> Function(String phone) onSubmit;

  const _InviteDriverSheet({required this.onSubmit});

  @override
  State<_InviteDriverSheet> createState() => _InviteDriverSheetState();
}

class _InviteDriverSheetState extends State<_InviteDriverSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
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
              'دعوة سائق جديد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتلقى السائق كلمة مرور مؤقتة للدخول إلى التطبيق',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+966XXXXXXXXX',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'رقم الهاتف مطلوب';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _isLoading = true);
                      await widget.onSubmit(_phoneController.text.trim());
                      if (mounted) setState(() => _isLoading = false);
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إرسال الدعوة'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
