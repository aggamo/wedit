import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/registration/presentation/screens/driver_registration_screen.dart';
import '../../features/registration/presentation/screens/documents_upload_screen.dart';
import '../../features/registration/presentation/screens/vehicle_info_screen.dart';
import '../../features/registration/presentation/screens/pending_approval_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/ride/presentation/screens/home_screen.dart';
import '../../features/earnings/presentation/screens/earnings_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/ride/presentation/screens/navigation_screen.dart';
import '../../features/ride/presentation/screens/ride_in_progress_screen.dart';
import '../../features/preferred_destination/presentation/screens/preferred_destination_screen.dart';
import '../../features/ride/presentation/screens/street_hail_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.value?.session != null;
      final currentPath = state.uri.path;

      if (currentPath == '/splash') return null;

      if (!isAuthenticated) {
        if (currentPath.startsWith('/auth')) return null;
        return '/auth';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            name: 'otp',
            builder: (context, state) {
              final phone = state.extra as String? ?? '';
              return OtpScreen(phone: phone);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/registration',
        name: 'registration',
        builder: (context, state) => const DriverRegistrationScreen(),
        routes: [
          GoRoute(
            path: 'documents',
            name: 'documents',
            builder: (context, state) => const DocumentsUploadScreen(),
          ),
          GoRoute(
            path: 'vehicle',
            name: 'vehicle',
            builder: (context, state) => const VehicleInfoScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/pending-approval',
        name: 'pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/subscription',
        name: 'subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/home/earnings',
            name: 'earnings',
            builder: (context, state) => const EarningsScreen(),
          ),
          GoRoute(
            path: '/home/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/home/leaderboard',
            name: 'leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: '/home/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsPlaceholderScreen(),
          ),
          GoRoute(
            path: '/home/preferred-destination',
            name: 'preferred-destination',
            builder: (context, state) => const PreferredDestinationScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/ride/:id/navigate',
        name: 'navigate',
        builder: (context, state) {
          final rideId = state.pathParameters['id']!;
          return NavigationScreen(rideId: rideId);
        },
      ),
      GoRoute(
        path: '/ride/:id/in-progress',
        name: 'in-progress',
        builder: (context, state) {
          final rideId = state.pathParameters['id']!;
          return RideInProgressScreen(rideId: rideId);
        },
      ),
      GoRoute(
        path: '/street-hail/:id',
        name: 'street-hail',
        builder: (context, state) {
          final rideId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>;
          return StreetHailScreen(
            rideId: rideId,
            passengerPhone: extra['passengerPhone'] as String,
            vehicleType: extra['vehicleType'] as String,
            startLat: extra['startLat'] as double,
            startLng: extra['startLng'] as double,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<({String path, String label, IconData icon})> _tabs = const [
    (path: '/home', label: 'Home', icon: Icons.home_rounded),
    (path: '/home/earnings', label: 'Earnings', icon: Icons.account_balance_wallet_rounded),
    (path: '/home/leaderboard', label: 'Leaderboard', icon: Icons.emoji_events_rounded),
    (path: '/home/profile', label: 'Profile', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          context.go(_tabs[index].path);
        },
        destinations: _tabs
            .map((tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}

class NotificationsPlaceholderScreen extends StatelessWidget {
  const NotificationsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Notifications coming soon')),
    );
  }
}
