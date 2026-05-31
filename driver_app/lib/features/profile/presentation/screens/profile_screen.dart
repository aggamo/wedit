import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLanguageDialog(BuildContext context) {
    const languages = [
      ('ar', 'العربية', '🇸🇦'),
      ('am', 'አማርኛ', '🇪🇹'),
      ('en', 'English', '🇬🇧'),
      ('om', 'Afaan Oromo', '🇪🇹'),
      ('ti', 'ትግርኛ', '🇪🇹'),
      ('so', 'Soomaali', '🇸🇴'),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اختر اللغة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) => ListTile(
            leading: Text(lang.$3, style: const TextStyle(fontSize: 24)),
            title: Text(lang.$2),
            onTap: () => Navigator.pop(context),
          )).toList(),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/auth');
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(currentDriverProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي الشخصي'), elevation: 0),
      body: driverAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (user) {
          final name = user?.name ?? 'السائق';
          final phone = user?.phone ?? '';
          final referralCode = user?.referralCode ?? '------';

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white24,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(5, (i) {
                            final r = user?.rating ?? 0;
                            return Icon(
                              i < r.floor() ? Icons.star : (i < r && r - i >= 0.5) ? Icons.star_half : Icons.star_border,
                              color: Colors.amber,
                              size: 18,
                            );
                          }),
                          const SizedBox(width: 6),
                          Text('${(user?.rating ?? 0).toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _StatCard(icon: Icons.directions_car, label: 'الرحلات', value: '${user?.totalRides ?? 0}'),
                      const SizedBox(width: 12),
                      _StatCard(icon: Icons.calendar_today, label: 'عضو منذ', value: '${user?.createdAt.year ?? 2024}'),
                      const SizedBox(width: 12),
                      _StatCard(icon: Icons.star, label: 'التقييم', value: '${(user?.rating ?? 0).toStringAsFixed(1)}'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Menu items
                _MenuSection(title: 'الحساب', items: [
                  _MenuItem(icon: Icons.monetization_on_outlined, title: 'أرباحي', onTap: () => context.push('/home/earnings')),
                  _MenuItem(icon: Icons.card_membership, title: 'الاشتراك', onTap: () => context.push('/subscription')),
                  _MenuItem(icon: Icons.location_on_outlined, title: 'وجهتي المفضلة', onTap: () => context.push('/preferred-destination')),
                  _MenuItem(icon: Icons.emoji_events_outlined, title: 'الترتيب والجوائز', onTap: () => context.push('/home/leaderboard')),
                ]),

                const SizedBox(height: 8),

                _MenuSection(title: 'مشاركة', items: [
                  _MenuItem(
                    icon: Icons.share_outlined,
                    title: 'كودي للإحالة: $referralCode',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: referralCode));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, size: 18),
                          onPressed: () => Share.share('انضم لـ wedit باستخدام كودي: $referralCode'),
                        ),
                      ],
                    ),
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 8),

                _MenuSection(title: 'الإعدادات', items: [
                  _MenuItem(icon: Icons.language, title: 'اللغة', onTap: () => _showLanguageDialog(context)),
                  _MenuItem(icon: Icons.notifications_outlined, title: 'الإشعارات', onTap: () {}),
                  _MenuItem(icon: Icons.help_outline, title: 'المساعدة والدعم', onTap: () {}),
                  if (user != null && (user.isFleetOwner || user.isFleetDriver))
                    _MenuItem(
                      icon: Icons.gavel_outlined,
                      title: 'القواعد والشروط — أسطول Wedit',
                      onTap: () => context.push('/fleet/terms'),
                    ),
                  _MenuItem(
                    icon: Icons.logout,
                    title: 'تسجيل الخروج',
                    color: Colors.red,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ]),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatCard({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 4),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    e.value,
                    if (!isLast) Divider(height: 1, indent: 52, endIndent: 16, color: Colors.grey.shade100),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, required this.onTap, this.color, this.trailing});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey.shade700, size: 22),
      title: Text(title, style: TextStyle(fontSize: 14, color: color)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
      dense: true,
    );
  }
}
