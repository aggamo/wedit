import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';

final _approvalStatusProvider = StreamProvider<String>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value('unknown');

  // Poll every 30 seconds
  return Stream.periodic(const Duration(seconds: 30), (_) => userId)
      .asyncMap(
        (id) async {
          try {
            final data = await supabase
                .from('drivers')
                .select('status, rejection_reason')
                .eq('id', id)
                .single();
            return '${data['status']}|${data['rejection_reason'] ?? ''}';
          } catch (_) {
            return 'pending|';
          }
        },
      )
      .startWith('pending|');
});

class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _checkAndNavigate(String statusWithReason) {
    final parts = statusWithReason.split('|');
    final status = parts[0];

    if (status == 'approved') {
      // Check subscription
      Future.microtask(() {
        if (mounted) context.go('/subscription');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(_approvalStatusProvider);

    return statusAsync.when(
      data: (statusWithReason) {
        final parts = statusWithReason.split('|');
        final status = parts[0];
        final rejectionReason = parts.length > 1 ? parts[1] : '';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndNavigate(statusWithReason);
        });

        return _buildScreen(theme, status, rejectionReason);
      },
      loading: () => _buildScreen(theme, 'pending', ''),
      error: (_, __) => _buildScreen(theme, 'pending', ''),
    );
  }

  Widget _buildScreen(ThemeData theme, String status, String rejectionReason) {
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';
    final isPending = status == 'pending';

    Color statusColor = isPending
        ? AppTheme.tertiaryColor
        : isApproved
            ? AppTheme.secondaryColor
            : Colors.red;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isPending ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 3),
                      ),
                      child: Center(
                        child: Icon(
                          isPending
                              ? Icons.hourglass_empty_rounded
                              : isApproved
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                          size: 72,
                          color: statusColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                isPending
                    ? 'طلبك قيد المراجعة'
                    : isApproved
                        ? 'تمت الموافقة على طلبك!'
                        : 'تم رفض طلبك',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isPending
                    ? 'نقوم بمراجعة مستنداتك. عادةً ما تستغرق المراجعة من 24 إلى 48 ساعة.'
                    : isApproved
                        ? 'يمكنك الآن الاشتراك والبدء في استقبال الطلبات.'
                        : 'للأسف، تم رفض طلبك. يمكنك إعادة التقديم بعد مراجعة المستندات.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              if (isRejected && rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سبب الرفض:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(rejectionReason),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              if (isPending) ...[
                // Status timeline
                _buildTimeline(theme),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'يتم التحقق تلقائياً كل 30 ثانية',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
              if (isApproved)
                CustomButton(
                  label: 'اشترك الآن',
                  onPressed: () => context.go('/subscription'),
                ),
              if (isRejected)
                CustomButton(
                  label: 'إعادة التقديم',
                  onPressed: () => context.go('/registration'),
                  color: Colors.red,
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/auth');
                },
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme) {
    final steps = [
      ('تم استلام الطلب', true),
      ('مراجعة المستندات', false),
      ('الموافقة النهائية', false),
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = step.$2;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.secondaryColor
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? AppTheme.secondaryColor
                          : theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 32,
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                step.$1,
                style: TextStyle(
                  color: isCompleted
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
