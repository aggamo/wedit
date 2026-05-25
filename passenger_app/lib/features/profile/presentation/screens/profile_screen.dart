import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('خطأ في تحميل البيانات')),
        data: (user) => ListView(
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.primary.withOpacity(0.05),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            user?.fullName?.isNotEmpty == true
                                ? user!.fullName![0].toUpperCase()
                                : 'م',
                            style: const TextStyle(
                              fontSize: 36,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? 'مستخدم wedit',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.phone ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Points balance card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PointsCard(points: user?.points ?? 0),
            ),

            const SizedBox(height: 16),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'إجمالي الرحلات',
                      value: '${user?.totalRides ?? 0}',
                      icon: Icons.directions_car,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'عضو منذ',
                      value: user?.createdAt != null
                          ? '${user!.createdAt!.year}'
                          : '---',
                      icon: Icons.calendar_today,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // Menu items
            _ProfileMenuItem(
              icon: Icons.stars,
              iconColor: AppColors.tertiary,
              title: 'نقاطي ومكافآتي',
              onTap: () => context.push(AppRoutes.loyalty),
            ),
            _ProfileMenuItem(
              icon: Icons.people,
              iconColor: AppColors.secondary,
              title: 'الإحالات',
              onTap: () => context.push(AppRoutes.referral),
            ),
            _ProfileMenuItem(
              icon: Icons.notifications,
              iconColor: AppColors.statusAccepted,
              title: 'الإشعارات',
              onTap: () => context.go(AppRoutes.notifications),
            ),
            _ProfileMenuItem(
              icon: Icons.support_agent,
              iconColor: AppColors.primary,
              title: 'الدعم والشكاوى',
              onTap: () => context.push(AppRoutes.support),
            ),
            _ProfileMenuItem(
              icon: Icons.language,
              iconColor: AppColors.textSecondary,
              title: 'اللغة',
              onTap: () => _showLanguageDialog(context, ref),
            ),

            const Divider(),

            _ProfileMenuItem(
              icon: Icons.logout,
              iconColor: AppColors.error,
              title: 'تسجيل الخروج',
              titleColor: AppColors.error,
              onTap: () => _confirmSignOut(context, ref),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر اللغة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppConstants.languageNames.entries.map((entry) {
            final selectedLang = ref.read(selectedLanguageProvider);
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: selectedLang,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(selectedLanguageProvider.notifier)
                      .state = val;
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final int points;

  const _PointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final etbEquivalent =
        (points * AppConstants.pointsToEtbRate).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.tertiary, AppColors.tertiaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.tertiary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$points نقطة',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                '≈ $etbEquivalent ب',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 16, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
