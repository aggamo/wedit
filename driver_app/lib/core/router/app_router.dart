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
import '../../features/fleet/presentation/screens/fleet_home_screen.dart';
import '../../features/fleet/presentation/screens/fleet_vehicles_screen.dart';
import '../../features/fleet/presentation/screens/fleet_drivers_screen.dart';
import '../../features/fleet/presentation/screens/fleet_settlements_screen.dart';
import '../../features/legal/presentation/screens/fleet_terms_screen.dart';

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
      // Fleet owner shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => FleetShell(child: child),
        routes: [
          GoRoute(
            path: '/fleet/home',
            name: 'fleet-home',
            builder: (context, state) => const FleetHomeScreen(),
          ),
          GoRoute(
            path: '/fleet/vehicles',
            name: 'fleet-vehicles',
            builder: (context, state) => const FleetVehiclesScreen(),
          ),
          GoRoute(
            path: '/fleet/drivers',
            name: 'fleet-drivers',
            builder: (context, state) => const FleetDriversScreen(),
          ),
          GoRoute(
            path: '/fleet/settlements',
            name: 'fleet-settlements',
            builder: (context, state) => const FleetSettlementsScreen(),
          ),
          GoRoute(
            path: '/fleet/profile',
            name: 'fleet-profile',
            builder: (context, state) => const FleetProfilePlaceholderScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/fleet/subscription',
        name: 'fleet-subscription',
        builder: (context, state) => const FleetSubscriptionScreen(),
      ),
      GoRoute(
        path: '/fleet/terms',
        name: 'fleet-terms',
        builder: (context, state) => const FleetTermsScreen(readOnly: true),
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

// ---------------------------------------------------------------------------
// Fleet Shell
// ---------------------------------------------------------------------------

class FleetShell extends StatefulWidget {
  final Widget child;
  const FleetShell({super.key, required this.child});

  @override
  State<FleetShell> createState() => _FleetShellState();
}

class _FleetShellState extends State<FleetShell> {
  int _selectedIndex = 0;

  final List<({String path, String label, IconData icon})> _tabs = const [
    (path: '/fleet/home', label: 'الأسطول', icon: Icons.dashboard_rounded),
    (path: '/fleet/vehicles', label: 'المركبات', icon: Icons.directions_car_rounded),
    (path: '/fleet/drivers', label: 'السائقون', icon: Icons.people_rounded),
    (path: '/fleet/settlements', label: 'التسويات', icon: Icons.receipt_long_rounded),
    (path: '/fleet/profile', label: 'الملف', icon: Icons.person_rounded),
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

// ---------------------------------------------------------------------------
// Fleet placeholder screens
// ---------------------------------------------------------------------------

class FleetVehiclesPlaceholderScreen extends StatelessWidget {
  const FleetVehiclesPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('المركبات', style: TextStyle(fontFamily: 'Cairo'))),
    );
  }
}

class FleetDriversPlaceholderScreen extends StatelessWidget {
  const FleetDriversPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('السائقون', style: TextStyle(fontFamily: 'Cairo'))),
    );
  }
}

class FleetSettlementsPlaceholderScreen extends StatelessWidget {
  const FleetSettlementsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('التسويات', style: TextStyle(fontFamily: 'Cairo'))),
    );
  }
}

class FleetProfilePlaceholderScreen extends StatelessWidget {
  const FleetProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('الملف الشخصي', style: TextStyle(fontFamily: 'Cairo'))),
    );
  }
}

// ---------------------------------------------------------------------------
// Fleet Subscription Screen
// ---------------------------------------------------------------------------

class FleetSubscriptionScreen extends StatelessWidget {
  const FleetSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const plans = [
      (name: 'أساسي', vehicles: '1–3 مركبات', price: '149 ر.س/شهر'),
      (name: 'متوسط', vehicles: '4–10 مركبات', price: '349 ر.س/شهر'),
      (name: 'متقدم', vehicles: '11–25 مركبة', price: '699 ر.س/شهر'),
      (name: 'مؤسسي', vehicles: '26+ مركبة', price: 'تواصل معنا'),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'اختر خطة اشتراك',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final plan = plans[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                title: Text(
                  plan.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  plan.vehicles,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                ),
                trailing: Text(
                  plan.price,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFFa41c28),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
