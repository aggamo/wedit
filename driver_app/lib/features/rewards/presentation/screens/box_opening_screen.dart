import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/rewards_provider.dart';

class BoxOpeningScreen extends ConsumerStatefulWidget {
  final String boxId;

  const BoxOpeningScreen({super.key, required this.boxId});

  @override
  ConsumerState<BoxOpeningScreen> createState() => _BoxOpeningScreenState();
}

class _BoxOpeningScreenState extends ConsumerState<BoxOpeningScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _pulseController;
  late final AnimationController _revealController;

  late final Animation<double> _spinAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _revealAnimation;

  _BoxState _boxState = _BoxState.idle;
  Map<String, dynamic>? _prize;
  String? _error;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _spinAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _openBox() async {
    if (_boxState != _BoxState.idle) return;
    setState(() => _boxState = _BoxState.opening);

    // Start spin animation
    _pulseController.stop();
    _spinController.forward();

    try {
      final ds = ref.read(rewardsDatasourceProvider);
      final result = await ds.openBox(widget.boxId);

      // Wait for animation to finish
      await _spinController.forward(from: 0).orCancel;

      if (mounted) {
        setState(() {
          _prize = result;
          _boxState = _BoxState.revealed;
        });
        _revealController.forward();

        // Invalidate pending box so hub updates
        ref.invalidate(pendingBoxProvider);
        ref.invalidate(gamificationSummaryProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _boxState = _BoxState.error;
        });
        _spinController.reset();
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'صندوق المكافآت',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: _boxState == _BoxState.revealed
            ? _buildRevealView(context)
            : _buildOpeningView(context),
      ),
    );
  }

  Widget _buildOpeningView(BuildContext context) {
    final isOpening = _boxState == _BoxState.opening;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative stars
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✨', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text('🌟', style: TextStyle(fontSize: 28)),
                SizedBox(width: 8),
                Text('✨', style: TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 24),

            // Box icon with animation
            isOpening
                ? RotationTransition(
                    turns: _spinAnimation,
                    child: const Text('🎁', style: TextStyle(fontSize: 100)),
                  )
                : ScaleTransition(
                    scale: _pulseAnimation,
                    child: const Text('🎁', style: TextStyle(fontSize: 100)),
                  ),

            const SizedBox(height: 32),

            Text(
              isOpening ? 'جارٍ فتح الصندوق...' : 'لديك مفاجأة!',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOpening
                  ? 'انتظر لحظة...'
                  : 'اضغط لفتح الصندوق واكتشف مكافأتك',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            if (_boxState == _BoxState.error && _error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'خطأ: $_error',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (!isOpening)
              GestureDetector(
                onTap: _openBox,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🎉', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 10),
                      Text(
                        'اضغط لفتح الصندوق',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (isOpening)
              const CircularProgressIndicator(color: Color(0xFFFFD700)),
          ],
        ),
      ),
    );
  }

  Widget _buildRevealView(BuildContext context) {
    final prize = _prize ?? {};
    final prizeType = prize['prize_type'] as String? ?? 'points';
    final value = prize['value'];
    final descriptionAr = prize['description_ar'] as String? ??
        prize['description'] as String? ??
        'مكافأة خاصة';

    final prizeIcon = _prizeIcon(prizeType);
    final prizeColor = _prizeColor(prizeType);
    final prizeTitle = _prizeTitleAr(prizeType, value);

    return ScaleTransition(
      scale: _revealAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Confetti-like decoration
              const Text('🎊', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 20),

              // Prize icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: prizeColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: prizeColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: prizeColor.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(prizeIcon, style: const TextStyle(fontSize: 52)),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'مبروك!',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                prizeTitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: prizeColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  descriptionAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'رائع! ← العودة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: prizeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _prizeIcon(String type) {
    switch (type) {
      case 'points':
        return '🪙';
      case 'xp':
        return '⭐';
      case 'subscription_days':
        return '📅';
      case 'discount':
        return '🎫';
      case 'cash':
        return '💵';
      default:
        return '🎁';
    }
  }

  Color _prizeColor(String type) {
    switch (type) {
      case 'points':
        return const Color(0xFFFFD700);
      case 'xp':
        return const Color(0xFF9B59B6);
      case 'subscription_days':
        return AppTheme.secondaryColor;
      case 'discount':
        return AppTheme.tertiaryColor;
      case 'cash':
        return const Color(0xFF2ECC71);
      default:
        return AppTheme.primaryColor;
    }
  }

  String _prizeTitleAr(String type, dynamic value) {
    final v = value?.toString() ?? '';
    switch (type) {
      case 'points':
        return '$v نقطة مكافأة';
      case 'xp':
        return '$v XP';
      case 'subscription_days':
        return '$v أيام اشتراك مجانية';
      case 'discount':
        return 'خصم $v%';
      case 'cash':
        return '$v ETB نقداً';
      default:
        return 'مكافأة خاصة';
    }
  }
}

enum _BoxState { idle, opening, revealed, error }
