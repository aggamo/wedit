import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class StreakWidget extends StatefulWidget {
  final int currentStreak;
  final int longestStreak;
  final bool isFrozen;

  const StreakWidget({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    this.isFrozen = false,
  });

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.currentStreak > 0 && !widget.isFrozen) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Milestone thresholds
  int _nextMilestone(int streak) {
    const milestones = [3, 7, 14, 30, 60, 100];
    for (final m in milestones) {
      if (streak < m) return m;
    }
    return ((streak ~/ 100) + 1) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.currentStreak;
    final frozen = widget.isFrozen;
    final next = _nextMilestone(streak);
    final progress = streak / next;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                frozen
                    ? const Text('❄️', style: TextStyle(fontSize: 28))
                    : AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (_, child) => Transform.scale(
                          scale: streak > 0 ? _scaleAnimation.value : 1.0,
                          child: child,
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 28)),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frozen
                            ? 'متوقف مؤقتاً ❄️'
                            : streak > 0
                                ? '$streak يوم متواصل'
                                : 'ابدأ سلسلة جديدة!',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'أطول سلسلة: ${widget.longestStreak} يوم',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: frozen
                        ? Colors.blue.shade50
                        : AppTheme.tertiaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    frozen ? 'مجمد' : 'الهدف: $next',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: frozen ? Colors.blue : AppTheme.tertiaryColor,
                    ),
                  ),
                ),
              ],
            ),
            if (!frozen) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    streak >= 7
                        ? AppTheme.tertiaryColor
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تبقى ${next - streak} يوم للوصول لـ $next',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
