import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/loyalty/presentation/screens/loyalty_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/referral/presentation/screens/referral_screen.dart';
import '../../features/ride/presentation/screens/destination_screen.dart';
import '../../features/ride/presentation/screens/history_screen.dart';
import '../../features/ride/presentation/screens/home_screen.dart';
import '../../features/ride/presentation/screens/rating_screen.dart';
import '../../features/ride/presentation/screens/ride_completed_screen.dart';
import '../../features/ride/presentation/screens/ride_offers_screen.dart';
import '../../features/ride/presentation/screens/tracking_screen.dart';
import '../../features/support/presentation/screens/support_screen.dart';

part 'app_router.g.dart';

// Named route constants
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const otp = '/auth/otp';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
  static const destination = '/home/destination';
  static const history = '/home/history';
  static const profile = '/home/profile';
  static const notifications = '/home/notifications';
  static const loyalty = '/home/loyalty';
  static const referral = '/home/referral';
  static const rideOffers = '/ride/:id/offers';
  static const tracking = '/ride/:id/tracking';
  static const rideCompleted = '/ride/:id/completed';
  static const rating = '/ride/:id/rate';
  static const support = '/support';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final currentPath = state.uri.path;

      // Skip redirect for splash and onboarding
      if (currentPath == AppRoutes.splash ||
          currentPath == AppRoutes.onboarding) {
        return null;
      }

      // Auth routes
      final isOnAuthRoute = currentPath.startsWith('/auth');
      final isOnProfileSetup = currentPath == AppRoutes.profileSetup;

      if (!isAuthenticated && !isOnAuthRoute) {
        return AppRoutes.auth;
      }

      if (isAuthenticated) {
        final user = authState.valueOrNull;
        final isProfileComplete =
            user != null && user.fullName != null && user.fullName!.isNotEmpty;

        if (!isProfileComplete && !isOnProfileSetup && !isOnAuthRoute) {
          return AppRoutes.profileSetup;
        }

        if (isOnAuthRoute || isOnProfileSetup && isProfileComplete) {
          return AppRoutes.home;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
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
        path: AppRoutes.profileSetup,
        name: 'profileSetup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      // Shell route for main app with bottom nav
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'destination',
                name: 'destination',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const DestinationScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.history,
            name: 'history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'loyalty',
                name: 'loyalty',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const LoyaltyScreen(),
              ),
              GoRoute(
                path: 'referral',
                name: 'referral',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const ReferralScreen(),
              ),
            ],
          ),
        ],
      ),
      // Ride-specific routes (outside shell - full screen)
      GoRoute(
        path: '/ride/:id/offers',
        name: 'rideOffers',
        builder: (context, state) {
          final rideId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          final systemPrice =
              (extra?['systemPrice'] as num?)?.toDouble() ?? 0.0;
          return RideOffersScreen(rideId: rideId, systemPrice: systemPrice);
        },
      ),
      GoRoute(
        path: '/ride/:id/tracking',
        name: 'tracking',
        builder: (context, state) {
          final rideId = state.pathParameters['id']!;
          return TrackingScreen(rideId: rideId);
        },
      ),
      GoRoute(
        path: '/ride/:id/completed',
        name: 'rideCompleted',
        builder: (context, state) {
          final rideId = state.pathParameters['id']!;
          return RideCompletedScreen(rideId: rideId);
        },
      ),
      GoRoute(
        path: '/ride/:id/rate',
        name: 'rating',
        builder: (context, state) {
          final rideId = state.pathParameters['id']!;
          return RatingScreen(rideId: rideId);
        },
      ),
      GoRoute(
        path: AppRoutes.support,
        name: 'support',
        builder: (context, state) => const SupportScreen(),
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
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shell widget that provides the bottom navigation bar
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  static const _routes = [
    AppRoutes.home,
    AppRoutes.history,
    AppRoutes.notifications,
    AppRoutes.profile,
  ];

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: _labelFor(context, 0),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: _labelFor(context, 1),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: _labelFor(context, 2),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: _labelFor(context, 3),
          ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Rides';
      case 2:
        return 'Alerts';
      case 3:
        return 'Profile';
      default:
        return '';
    }
  }
}

