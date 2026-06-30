import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/admin_provider.dart';

class AdminScaffold extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const AdminScaffold({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;
    final isTablet = width >= 700 && width < 1100;

    if (isDesktop) {
      return _DesktopLayout(child: child, currentPath: currentPath);
    } else if (isTablet) {
      return _TabletLayout(child: child, currentPath: currentPath);
    } else {
      return _MobileLayout(child: child, currentPath: currentPath);
    }
  }
}

// ─── Nav items definition ──────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final String badgeKey;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.badgeKey = '',
  });
}

const _navItems = [
  _NavItem(
    label: 'لوحة التحكم',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    route: '/dashboard',
  ),
  _NavItem(
    label: 'السائقون',
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    route: '/dashboard/drivers',
    badgeKey: 'pending_drivers',
  ),
  _NavItem(
    label: 'الرحلات',
    icon: Icons.directions_car_outlined,
    activeIcon: Icons.directions_car,
    route: '/dashboard/rides',
  ),
  _NavItem(
    label: 'الاشتراكات',
    icon: Icons.card_membership_outlined,
    activeIcon: Icons.card_membership,
    route: '/dashboard/subscriptions',
    badgeKey: 'pending_transfers',
  ),
  _NavItem(
    label: 'المدفوعات',
    icon: Icons.payment_outlined,
    activeIcon: Icons.payment,
    route: '/dashboard/payments',
  ),
  _NavItem(
    label: 'الشكاوى',
    icon: Icons.report_problem_outlined,
    activeIcon: Icons.report_problem,
    route: '/dashboard/complaints',
    badgeKey: 'open_complaints',
  ),
  _NavItem(
    label: 'الإشعارات',
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    route: '/dashboard/notifications',
  ),
  _NavItem(
    label: 'المسابقات',
    icon: Icons.emoji_events_outlined,
    activeIcon: Icons.emoji_events,
    route: '/dashboard/competitions',
  ),
  _NavItem(
    label: 'الإحالات',
    icon: Icons.share_outlined,
    activeIcon: Icons.share,
    route: '/dashboard/referrals',
  ),
  _NavItem(
    label: 'التقارير',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    route: '/dashboard/reports',
  ),
  _NavItem(
    label: 'الإعدادات',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    route: '/dashboard/settings',
  ),
  _NavItem(
    label: 'الكول سنتر',
    icon: Icons.headset_mic_outlined,
    activeIcon: Icons.headset_mic,
    route: '/dashboard/call-center',
  ),
  _NavItem(
    label: 'المساعد الصوتي',
    icon: Icons.record_voice_over_outlined,
    activeIcon: Icons.record_voice_over,
    route: '/dashboard/ai-call-logs',
  ),
];

// ─── Top Bar ──────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  final String currentPath;
  final VoidCallback? onMenuTap;

  const _TopBar({required this.currentPath, this.onMenuTap});

  String get _pageTitle {
    final item = _navItems.firstWhere(
      (n) => n.route == currentPath,
      orElse: () => _navItems.first,
    );
    return item.label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (onMenuTap != null)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuTap,
            ),
          Text(
            _pageTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          // Admin info
          _AdminAvatar(ref: ref),
        ],
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  final WidgetRef ref;
  const _AdminAvatar({required this.ref});

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(currentAdminProvider);

    return adminAsync.when(
      data: (admin) => PopupMenuButton(
        offset: const Offset(0, 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Text(
                (admin?['full_name'] as String? ?? 'A').substring(0, 1),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin?['full_name'] as String? ?? 'Admin',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'مدير النظام',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text('تسجيل الخروج',
                    style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
        onSelected: (value) async {
          if (value == 'logout') {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go('/login');
          }
        },
      ),
      loading: () => const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.person),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  final String currentPath;
  final bool expanded;

  const _Sidebar({required this.currentPath, this.expanded = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingCountsProvider);
    final counts = pendingAsync.valueOrNull ?? {};

    return Container(
      width: expanded ? 240 : 72,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            alignment: Alignment.center,
            child: expanded
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'W',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'wedit Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'W',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
          ),
          const Divider(color: Color(0xFF2D2D45), height: 1),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = currentPath == item.route ||
                    (item.route != '/dashboard' &&
                        currentPath.startsWith(item.route));
                final badgeCount = item.badgeKey.isNotEmpty
                    ? (counts[item.badgeKey] ?? 0)
                    : 0;

                return _SidebarItem(
                  item: item,
                  isSelected: isSelected,
                  expanded: expanded,
                  badgeCount: badgeCount,
                  onTap: () => context.go(item.route),
                );
              },
            ),
          ),
          const Divider(color: Color(0xFF2D2D45), height: 1),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool expanded;
  final int badgeCount;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.expanded,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 14 : 0,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.9)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                      size: 22,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF9E9E9E),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Layout variants ──────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const _DesktopLayout({required this.child, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(currentPath: currentPath, expanded: true),
          Expanded(
            child: Column(
              children: [
                _TopBar(currentPath: currentPath),
                Expanded(
                  child: ClipRect(child: child),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletLayout extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const _TabletLayout({required this.child, required this.currentPath});

  @override
  State<_TabletLayout> createState() => _TabletLayoutState();
}

class _TabletLayoutState extends State<_TabletLayout> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(currentPath: widget.currentPath, expanded: _expanded),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  currentPath: widget.currentPath,
                  onMenuTap: () => setState(() => _expanded = !_expanded),
                ),
                Expanded(child: ClipRect(child: widget.child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLayout extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const _MobileLayout({required this.child, required this.currentPath});

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: _Sidebar(currentPath: widget.currentPath, expanded: true),
      ),
      body: Column(
        children: [
          _TopBar(
            currentPath: widget.currentPath,
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
