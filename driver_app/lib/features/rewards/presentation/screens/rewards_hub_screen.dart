import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/rewards_provider.dart';
import '../widgets/level_badge_widget.dart';
import '../widgets/streak_widget.dart';
import '../widgets/subscription_status_widget.dart';

class RewardsHubScreen extends ConsumerWidget {
  const RewardsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(gamificationSummaryProvider);
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final pendingBoxAsync = ref.watch(pendingBoxProvider);
    final driverAchievementsAsync = ref.watch(driverAchievementsProvider);
    final pointsTxAsync = ref.watch(recentPointsTransactionsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            'مكافآتي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(gamificationSummaryProvider);
                ref.invalidate(currentSubscriptionProvider);
                ref.invalidate(pendingBoxProvider);
                ref.invalidate(driverAchievementsProvider);
                ref.invalidate(recentPointsTransactionsProvider);
              },
            ),
          ],
        ),
        body: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: 'خطأ في تحميل البيانات: $e',
              onRetry: () => ref.invalidate(gamificationSummaryProvider)),
          data: (summary) => _HubBody(
            summary: summary ?? {},
            subscriptionAsync: subscriptionAsync,
            pendingBoxAsync: pendingBoxAsync,
            driverAchievementsAsync: driverAchievementsAsync,
            pointsTxAsync: pointsTxAsync,
            onFreeze: () => _showFreezeSheet(context, ref),
            onUnfreeze: () => _confirmUnfreeze(context, ref),
            ref: ref,
          ),
        ),
      ),
    );
  }

  void _showFreezeSheet(BuildContext context, WidgetRef ref) {
    final reasonsAsync = ref.read(freezeReasonsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FreezeBottomSheet(reasonsAsync: reasonsAsync, ref: ref),
    );
  }

  void _confirmUnfreeze(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء التجميد', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text(
          'هل تريد إلغاء تجميد اشتراكك؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final ds = ref.read(rewardsDatasourceProvider);
                await ds.unfreezeSubscription();
                ref.invalidate(currentSubscriptionProvider);
                ref.invalidate(gamificationSummaryProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إلغاء التجميد بنجاح')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main body
// ---------------------------------------------------------------------------

class _HubBody extends StatelessWidget {
  final Map<String, dynamic> summary;
  final AsyncValue<Map<String, dynamic>?> subscriptionAsync;
  final AsyncValue<Map<String, dynamic>?> pendingBoxAsync;
  final AsyncValue<List<Map<String, dynamic>>> driverAchievementsAsync;
  final AsyncValue<List<Map<String, dynamic>>> pointsTxAsync;
  final VoidCallback onFreeze;
  final VoidCallback onUnfreeze;
  final WidgetRef ref;

  const _HubBody({
    required this.summary,
    required this.subscriptionAsync,
    required this.pendingBoxAsync,
    required this.driverAchievementsAsync,
    required this.pointsTxAsync,
    required this.onFreeze,
    required this.onUnfreeze,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final levelKey = summary['level_key'] as String? ?? 'bronze';
    final levelNameAr = summary['level_name_ar'] as String? ?? 'برونزي';
    final driverName = summary['driver_name'] as String? ??
        Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
        'السائق';
    final xp = (summary['xp'] as num?)?.toInt() ?? 0;
    final xpToNext = (summary['xp_to_next_level'] as num?)?.toInt() ?? 100;
    final levelXpStart = (summary['level_xp_start'] as num?)?.toInt() ?? 0;
    final points = (summary['points_balance'] as num?)?.toInt() ?? 0;
    final currentStreak = (summary['current_streak'] as num?)?.toInt() ?? 0;
    final longestStreak = (summary['longest_streak'] as num?)?.toInt() ?? 0;
    final streakFrozen = summary['streak_frozen'] == true;
    final todayRides = (summary['today_rides'] as num?)?.toInt() ?? 0;
    final dailyGoal = (summary['daily_goal'] as num?)?.toInt() ?? 0;
    final todayEarnings = (summary['today_earnings'] as num?)?.toDouble() ?? 0;
    final earningsGoal = (summary['earnings_goal'] as num?)?.toDouble() ?? 0;
    final pendingBoxes = (summary['pending_boxes'] as num?)?.toInt() ?? 0;
    final todayBonus = (summary['today_bonus_points'] as num?)?.toInt() ?? 0;

    final xpProgress = xpToNext > 0
        ? ((xp - levelXpStart) / xpToNext).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status Card ──────────────────────────────────────────────────
          _StatusCard(
            driverName: driverName,
            levelKey: levelKey,
            levelNameAr: levelNameAr,
            xp: xp,
            xpToNext: xpToNext,
            xpProgress: xpProgress.toDouble(),
            todayRides: todayRides,
            dailyGoal: dailyGoal,
            todayEarnings: todayEarnings,
            earningsGoal: earningsGoal,
            todayBonusPoints: todayBonus,
          ),

          const SizedBox(height: 16),

          // ── Subscription Card ─────────────────────────────────────────
          subscriptionAsync.when(
            loading: () => const _LoadingCard(),
            error: (_, __) => const SizedBox.shrink(),
            data: (sub) {
              final plan = sub?['subscription_plans'] as Map<String, dynamic>?;
              return SubscriptionStatusWidget(
                subscription: sub,
                planInfo: plan,
                todayRides: todayRides,
                dailyGoal: dailyGoal,
                onFreezeTap: onFreeze,
                onUnfreezeTap: onUnfreeze,
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Streak Card ───────────────────────────────────────────────
          StreakWidget(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            isFrozen: streakFrozen,
          ),

          const SizedBox(height: 16),

          // ── Points Card ───────────────────────────────────────────────
          _PointsCard(
            points: points,
            pointsTxAsync: pointsTxAsync,
            onRedeem: () => context.push('/home/rewards/redemption'),
          ),

          const SizedBox(height: 16),

          // ── Pending Box Card ──────────────────────────────────────────
          pendingBoxAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (box) {
              if (box == null && pendingBoxes == 0) return const SizedBox.shrink();
              final boxId = box?['id'] as String? ?? '';
              return _PendingBoxCard(
                boxId: boxId,
                onOpen: () => context.push('/home/rewards/box/$boxId'),
              );
            },
          ),

          if (pendingBoxAsync.valueOrNull != null ||
              pendingBoxAsync.valueOrNull == null && pendingBoxes > 0)
            const SizedBox(height: 16),

          // ── Achievements Preview ──────────────────────────────────────
          _AchievementsPreview(
            driverAchievementsAsync: driverAchievementsAsync,
            onViewAll: () => context.push('/home/rewards/achievements'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Card
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  final String driverName;
  final String levelKey;
  final String levelNameAr;
  final int xp;
  final int xpToNext;
  final double xpProgress;
  final int todayRides;
  final int dailyGoal;
  final double todayEarnings;
  final double earningsGoal;
  final int todayBonusPoints;

  const _StatusCard({
    required this.driverName,
    required this.levelKey,
    required this.levelNameAr,
    required this.xp,
    required this.xpToNext,
    required this.xpProgress,
    required this.todayRides,
    required this.dailyGoal,
    required this.todayEarnings,
    required this.earningsGoal,
    required this.todayBonusPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFa41c28), Color(0xFF7b1520)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFa41c28).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver name + level
          Row(
            children: [
              LevelBadgeWidget(levelKey: levelKey, nameAr: levelNameAr, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'المستوى: $levelNameAr',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // XP progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP: $xp',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'الهدف: $xpToNext',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: xpProgress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),

          const SizedBox(height: 16),

          // Today stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'اليوم: $todayRides رحلات  |  هدفك: $dailyGoal',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (todayBonusPoints > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+${todayBonusPoints}pt',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ),
                  ],
                ),
                if (earningsGoal > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        'اليوم: ${todayEarnings.toStringAsFixed(0)} ETB  |  هدفك: ${earningsGoal.toStringAsFixed(0)} ETB',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Points Card
// ---------------------------------------------------------------------------

class _PointsCard extends StatelessWidget {
  final int points;
  final AsyncValue<List<Map<String, dynamic>>> pointsTxAsync;
  final VoidCallback onRedeem;

  const _PointsCard({
    required this.points,
    required this.pointsTxAsync,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
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
                const Text('🪙', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نقاط المكافآت',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '$points نقطة',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onRedeem,
                  icon: const Icon(Icons.redeem_rounded, size: 16),
                  label: const Text(
                    'استبدال',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text(
              'آخر المعاملات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            pointsTxAsync.when(
              loading: () => const SizedBox(
                height: 40,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (txs) {
                final recent = txs.take(3).toList();
                if (recent.isEmpty) {
                  return const Text(
                    'لا توجد معاملات بعد',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                  );
                }
                return Column(
                  children: recent.map((tx) {
                    final amount = (tx['amount'] as num?)?.toInt() ?? 0;
                    final desc = tx['description_ar'] as String? ??
                        tx['description'] as String? ??
                        '';
                    final isPositive = amount >= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            size: 16,
                            color: isPositive
                                ? AppTheme.secondaryColor
                                : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              desc,
                              style: const TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${isPositive ? '+' : ''}$amount',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPositive
                                  ? AppTheme.secondaryColor
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending Box Card
// ---------------------------------------------------------------------------

class _PendingBoxCard extends StatelessWidget {
  final String boxId;
  final VoidCallback onOpen;

  const _PendingBoxCard({required this.boxId, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لديك صندوق مكافآت!',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'افتح صندوقك لاكتشاف مفاجأتك',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF8C00),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'افتح',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Achievements Preview
// ---------------------------------------------------------------------------

class _AchievementsPreview extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> driverAchievementsAsync;
  final VoidCallback onViewAll;

  const _AchievementsPreview({
    required this.driverAchievementsAsync,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        color: AppTheme.tertiaryColor, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'إنجازاتك الأخيرة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text(
                    'عرض الكل',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                ),
              ],
            ),
            driverAchievementsAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (achievements) {
                if (achievements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'لم تحصل على إنجازات بعد — ابدأ الآن!',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.grey),
                      ),
                    ),
                  );
                }
                final recent = achievements.take(3).toList();
                return Column(
                  children: recent.map((a) {
                    final ach = a['achievements'] as Map<String, dynamic>? ?? a;
                    final name = ach['name_ar'] as String? ?? 'إنجاز';
                    final icon = ach['badge_icon'] as String? ?? '🏅';
                    final earnedAt = a['earned_at'] as String? ?? '';
                    String dateStr = '';
                    if (earnedAt.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(earnedAt).toLocal();
                        dateStr =
                            '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
                      } catch (_) {}
                    }
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(icon, style: const TextStyle(fontSize: 28)),
                      title: Text(name,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      trailing: Text(dateStr,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 1,
      child: SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Freeze bottom sheet
// ---------------------------------------------------------------------------

class _FreezeBottomSheet extends StatefulWidget {
  final AsyncValue<List<Map<String, dynamic>>> reasonsAsync;
  final WidgetRef ref;

  const _FreezeBottomSheet({required this.reasonsAsync, required this.ref});

  @override
  State<_FreezeBottomSheet> createState() => _FreezeBottomSheetState();
}

class _FreezeBottomSheetState extends State<_FreezeBottomSheet> {
  String? _selectedReasonId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final reasons = widget.reasonsAsync.valueOrNull ?? [];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تجميد الاشتراك',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'اختر سبب التجميد',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (reasons.isEmpty)
              const Text('لا توجد أسباب متاحة',
                  style: TextStyle(fontFamily: 'Cairo'),
                  textAlign: TextAlign.center)
            else
              ...reasons.map((r) {
                final id = r['id'] as String? ?? '';
                final name = r['name_ar'] as String? ?? r['name'] as String? ?? '';
                return RadioListTile<String>(
                  value: id,
                  groupValue: _selectedReasonId,
                  onChanged: (v) => setState(() => _selectedReasonId = v),
                  title: Text(name,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  activeColor: AppTheme.primaryColor,
                );
              }),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _selectedReasonId == null || _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      try {
                        final ds = widget.ref.read(rewardsDatasourceProvider);
                        await ds.freezeSubscription(
                            reasonId: _selectedReasonId);
                        widget.ref.invalidate(currentSubscriptionProvider);
                        widget.ref.invalidate(gamificationSummaryProvider);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تم تجميد الاشتراك بنجاح')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('تأكيد التجميد',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
