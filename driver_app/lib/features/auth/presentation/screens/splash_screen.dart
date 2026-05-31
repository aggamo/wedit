import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../legal/presentation/screens/fleet_terms_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5)),
    );

    _animController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _navigate();
  }

  void _navigate() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go('/auth');
      return;
    }

    ref.read(currentDriverProvider.future).then((driver) {
      if (!mounted) return;

      if (driver == null) {
        context.go('/registration');
        return;
      }

      // Fleet owner flow
      if (driver.isFleetOwner) {
        if (!driver.hasActiveSubscription) {
          context.go('/fleet/subscription');
        } else {
          // Check T&C acceptance
          _checkFleetTermsAndNavigate(driver.id, 'fleet_owner', '/fleet/home');
        }
        return;
      }

      // Regular driver flow
      if (!driver.isRegistrationComplete) {
        context.go('/registration');
      } else if (driver.isPending) {
        context.go('/pending-approval');
      } else if (driver.isApproved && !driver.hasActiveSubscription) {
        context.go('/subscription');
      } else if (driver.isFleetDriver && driver.isApproved) {
        // Check T&C for fleet-employed drivers
        _checkFleetTermsAndNavigate(driver.id, 'driver', '/home');
      } else {
        context.go('/home');
      }
    });
  }

  Future<void> _checkFleetTermsAndNavigate(
      String userId, String userRole, String destination) async {
    try {
      final supabase = Supabase.instance.client;
      // Get active fleet_terms document
      final doc = await supabase
          .from('legal_documents')
          .select('id')
          .eq('doc_type', 'fleet_terms')
          .eq('is_active', true)
          .maybeSingle();

      if (doc == null) {
        if (mounted) context.go(destination);
        return;
      }

      final docId = doc['id'] as String;

      // Check if user already accepted
      final acceptance = await supabase
          .from('legal_document_acceptances')
          .select('id')
          .eq('user_id', userId)
          .eq('document_id', docId)
          .maybeSingle();

      if (!mounted) return;

      if (acceptance != null) {
        context.go(destination);
      } else {
        // Show T&C screen, then navigate to destination
        final accepted = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => FleetTermsScreen(userRole: userRole),
          ),
        );
        if (mounted) {
          if (accepted == true) {
            context.go(destination);
          }
          // If rejected, stay on splash (user must accept to continue)
        }
      }
    } catch (_) {
      if (mounted) context.go(destination);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'W',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'wedit',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'للسائق',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
