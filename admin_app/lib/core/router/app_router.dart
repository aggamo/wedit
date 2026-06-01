import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_overview_page.dart';
import '../../features/drivers/presentation/pages/drivers_page.dart';
import '../../features/drivers/presentation/pages/driver_detail_page.dart';
import '../../features/rides/presentation/pages/rides_page.dart';
import '../../features/subscriptions/presentation/pages/subscriptions_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';
import '../../features/complaints/presentation/pages/complaints_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/competitions/presentation/pages/competitions_page.dart';
import '../../features/referrals/presentation/pages/referrals_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/call_center/presentation/pages/call_center_page.dart';
import '../../features/ai_call_center/presentation/pages/ai_call_logs_page.dart';
import '../widgets/admin_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) {
        // Check admin role
        try {
          await Supabase.instance.client
              .from('admins')
              .select('id')
              .eq('user_id', user.id)
              .single();
          return '/dashboard';
        } catch (_) {
          await Supabase.instance.client.auth.signOut();
          return '/login';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminScaffold(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardOverviewPage(),
            routes: [
              GoRoute(
                path: 'drivers',
                builder: (context, state) => const DriversPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => DriverDetailPage(
                      driverId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'rides',
                builder: (context, state) => const RidesPage(),
              ),
              GoRoute(
                path: 'subscriptions',
                builder: (context, state) => const SubscriptionsPage(),
              ),
              GoRoute(
                path: 'payments',
                builder: (context, state) => const PaymentsPage(),
              ),
              GoRoute(
                path: 'complaints',
                builder: (context, state) => const ComplaintsPage(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsPage(),
              ),
              GoRoute(
                path: 'competitions',
                builder: (context, state) => const CompetitionsPage(),
              ),
              GoRoute(
                path: 'referrals',
                builder: (context, state) => const ReferralsPage(),
              ),
              GoRoute(
                path: 'reports',
                builder: (context, state) => const ReportsPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsPage(),
              ),
              GoRoute(
                path: 'call-center',
                builder: (context, state) => const CallCenterPage(),
              ),
              GoRoute(
                path: 'ai-call-logs',
                builder: (context, state) => const AiCallLogsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'الصفحة غير موجودة',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.error?.message ?? ''),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    ),
  );
});
