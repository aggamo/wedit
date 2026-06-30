import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/rewards_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAchievementsAsync = ref.watch(achievementsProvider);
    final driverAchievementsAsync = ref.watch(driverAchievementsProvider);
    final summaryAsync = ref.watch(gamificationSummaryProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'الإنجازات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(achievementsProvider);
                ref.invalidate(driverAchievementsProvider);
                ref.invalidate(gamificationSummaryProvider);
              },
            ),
          ],
        ),
        body: _buildBody(
          context,
          allAchievementsAsync,
          driverAchievementsAsync,
          summaryAsync,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> allAsync,
    AsyncValue<List<Map<String, dynamic>>> driverAsync,
    AsyncValue<Map<String, dynamic>?> summaryAsync,
  ) {
    if (allAsync.isLoading || driverAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (allAsync.hasError) {
      return Center(
        child: Text(
          'خطأ: ${allAsync.error}',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }

    final all = allAsync.valueOrNull ?? [];
    final earned = driverAsync.valueOrNull ?? [];
    final summary = summaryAsync.valueOrNull ?? {};

    // Build set of earned achievement IDs
    final earnedIds = <String>{};
    for (final e in earned) {
      final id = e['achievement_id'] as String? ??
          (e['achievements'] as Map?)?['id'] as String? ??
          '';
      if (id.isNotEmpty) earnedIds.add(id);
    }

    // Current driver progress counters
    final rideCount = (summary['total_rides'] as num?)?.toInt() ?? 0;
    final currentStreak = (summary['current_streak'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Earned achievements ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.emoji_events_rounded,
            title: 'إنجازاتي',
            count: earned.length,
          ),
          const SizedBox(height: 8),
          if (earned.isEmpty)
            _EmptyState(
              icon: Icons.emoji_events_outlined,
              message: 'لم تحصل على أي إنجازات بعد\nابدأ رحلاتك لتكسب الإنجازات!',
            )
          else
            ...earned.map((e) {
              final ach = e['achievements'] as Map<String, dynamic>? ?? e;
              return _EarnedAchievementTile(achievement: ach, earnedData: e);
            }),

          const SizedBox(height: 24),

          // ── Available achievements ─────────────────────────────────────
          _SectionHeader(
            icon: Icons.flag_outlined,
            title: 'المتاحة',
            count: all
                .where((a) =>
                    a['is_hidden'] != true && !earnedIds.contains(a['id']))
                .length,
          ),
          const SizedBox(height: 8),
          ...all
              .where((a) =>
                  a['is_hidden'] != true &&
                  !earnedIds.contains(a['id'] as String? ?? ''))
              .map((a) => _AvailableAchievementTile(
                    achievement: a,
                    rideCount: rideCount,
                    currentStreak: currentStreak,
                  )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.tertiaryColor, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.tertiaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.tertiaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Earned achievement tile
// ---------------------------------------------------------------------------

class _EarnedAchievementTile extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final Map<String, dynamic> earnedData;

  const _EarnedAchievementTile({
    required this.achievement,
    required this.earnedData,
  });

  @override
  Widget build(BuildContext context) {
    final name = achievement['name_ar'] as String? ?? 'إنجاز';
    final desc = achievement['description_ar'] as String? ?? '';
    final icon = achievement['badge_icon'] as String? ?? '🏅';
    final earnedAt = earnedData['earned_at'] as String? ?? '';

    String dateStr = '';
    if (earnedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(earnedAt).toLocal();
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.tertiaryColor.withOpacity(0.4),
          ),
        ),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.tertiaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (desc.isNotEmpty)
                Text(
                  desc,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  maxLines: 2,
                ),
              if (dateStr.isNotEmpty)
                Text(
                  'تم الحصول عليه: $dateStr',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600),
                ),
            ],
          ),
          trailing: const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.secondaryColor,
            size: 22,
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Available achievement tile
// ---------------------------------------------------------------------------

class _AvailableAchievementTile extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final int rideCount;
  final int currentStreak;

  const _AvailableAchievementTile({
    required this.achievement,
    required this.rideCount,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    final name = achievement['name_ar'] as String? ?? 'إنجاز';
    final desc = achievement['description_ar'] as String? ?? '';
    final icon = achievement['badge_icon'] as String? ?? '🎯';
    final triggerType = achievement['trigger_type'] as String? ?? '';
    final triggerValue = (achievement['trigger_value'] as num?)?.toInt() ?? 0;
    final rewardPoints = (achievement['reward_points'] as num?)?.toInt() ?? 0;
    final rewardXp = (achievement['reward_xp'] as num?)?.toInt() ?? 0;

    int currentValue = 0;
    String progressLabel = '';

    if (triggerType == 'ride_count') {
      currentValue = rideCount;
      progressLabel = '$rideCount / $triggerValue رحلة';
    } else if (triggerType == 'streak_days') {
      currentValue = currentStreak;
      progressLabel = '$currentStreak / $triggerValue يوم';
    }

    final progress = triggerValue > 0
        ? (currentValue / triggerValue).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey.shade600),
                      maxLines: 2,
                    ),
                  if (progressLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          progressLabel,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        // Reward chips
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (rewardPoints > 0)
                              _RewardChip(
                                  label: '+$rewardPoints pt',
                                  color: AppTheme.tertiaryColor),
                            if (rewardXp > 0) ...[
                              const SizedBox(width: 4),
                              _RewardChip(
                                  label: '+$rewardXp XP',
                                  color: AppTheme.primaryColor),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 0.7
                              ? AppTheme.secondaryColor
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  final Color color;

  const _RewardChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
