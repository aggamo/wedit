import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/leaderboard_provider.dart';
import '../widgets/leaderboard_list_item.dart';
import '../widgets/my_rank_card.dart';
import '../widgets/past_winners_section.dart';
import '../widgets/prizes_section.dart';
import '../widgets/raffle_progress_card.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() =>
      _LeaderboardScreenState();
}

class _LeaderboardScreenState
    extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScreenshotController _screenshotController =
      ScreenshotController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _share(String periodType) async {
    try {
      final imageBytes = await _screenshotController.capture();
      if (imageBytes == null) return;

      final rank = ref.read(myRankProvider(periodType)).value?.rank ?? 0;
      final text = rank > 0
          ? 'مركزي في منافسة wedit هذا ${periodType == 'weekly' ? 'الأسبوع' : 'الشهر'}: #$rank! 🏆'
          : 'أنا أشارك في منافسة wedit! 🏆';

      await Share.shareXFiles(
        [XFile.fromData(imageBytes, mimeType: 'image/png')],
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر المشاركة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPeriod = ref.watch(selectedPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 سباق الجوائز'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'مشاركة ترتيبي',
            onPressed: () => _share(selectedPeriod),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            ref.read(selectedPeriodProvider.notifier).state =
                index == 0 ? 'weekly' : 'monthly';
          },
          tabs: const [
            Tab(text: 'أسبوعي'),
            Tab(text: 'شهري'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeaderboardTabView(
            periodType: 'weekly',
            screenshotController: _screenshotController,
          ),
          _LeaderboardTabView(
            periodType: 'monthly',
            screenshotController: _screenshotController,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab view
// ---------------------------------------------------------------------------

class _LeaderboardTabView extends ConsumerStatefulWidget {
  final String periodType;
  final ScreenshotController screenshotController;

  const _LeaderboardTabView({
    required this.periodType,
    required this.screenshotController,
  });

  @override
  ConsumerState<_LeaderboardTabView> createState() =>
      _LeaderboardTabViewState();
}

class _LeaderboardTabViewState
    extends ConsumerState<_LeaderboardTabView> {
  int _topN = 10;

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync =
        ref.watch(leaderboardProvider(widget.periodType));
    final myRankAsync =
        ref.watch(myRankProvider(widget.periodType));
    final settingsAsync =
        ref.watch(competitionSettingsProvider(widget.periodType));
    final pastWinnersAsync =
        ref.watch(pastWinnersProvider(widget.periodType));
    final endTimeAsync =
        ref.watch(periodEndTimeProvider(widget.periodType));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider(widget.periodType));
        ref.invalidate(myRankProvider(widget.periodType));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Countdown timer
            endTimeAsync.when(
              data: (endTime) =>
                  _CountdownTimer(endTime: endTime),
              loading: () => const SizedBox(height: 48),
              error: (_, __) => const SizedBox(height: 8),
            ),

            // My rank card (wrapped for screenshot)
            Screenshot(
              controller: widget.screenshotController,
              child: myRankAsync.when(
                data: (myRank) => settingsAsync.when(
                  data: (settings) => MyRankCard(
                    myRank: myRank,
                    settings: settings,
                  ),
                  loading: () => const _ShimmerBox(height: 140),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                loading: () => const _ShimmerBox(height: 140),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Top 10 / Top 50 toggle
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'قائمة المتصدرين',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 10, label: Text('أفضل 10')),
                      ButtonSegment(
                          value: 50, label: Text('أفضل 50')),
                    ],
                    selected: {_topN},
                    onSelectionChanged: (set) {
                      setState(() => _topN = set.first);
                    },
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Leaderboard list
            leaderboardAsync.when(
              data: (entries) {
                final displayed = entries.take(_topN).toList();
                if (displayed.isEmpty) {
                  return const _EmptyState(
                      message: 'لا توجد بيانات متاحة بعد');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayed.length,
                  itemBuilder: (context, index) => LeaderboardListItem(
                    entry: displayed[index],
                  ),
                );
              },
              loading: () => Column(
                children: List.generate(
                    5, (_) => const _ShimmerBox(height: 68)),
              ),
              error: (e, _) => _EmptyState(
                  message: 'تعذّر تحميل البيانات'),
            ),

            const SizedBox(height: 16),

            // Prizes
            settingsAsync.when(
              data: (settings) => PrizesSection(prizes: settings.prizes),
              loading: () => const _ShimmerBox(height: 120),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Raffle progress
            settingsAsync.when(
              data: (settings) => settings.raffleEnabled
                  ? myRankAsync.when(
                      data: (myRank) => RaffleProgressCard(
                        myRank: myRank,
                        settings: settings,
                      ),
                      loading: () => const _ShimmerBox(height: 160),
                      error: (_, __) => const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Past winners
            pastWinnersAsync.when(
              data: (winners) => PastWinnersSection(winners: winners),
              loading: () => const _ShimmerBox(height: 100),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown timer widget
// ---------------------------------------------------------------------------

class _CountdownTimer extends StatefulWidget {
  final DateTime endTime;

  const _CountdownTimer({required this.endTime});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.endTime.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remaining = widget.endTime.difference(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('انتهت المنافسة',
            style: TextStyle(color: Colors.red)),
      );
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined,
              color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          const Text(
            'ينتهي بعد: ',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 13,
            ),
          ),
          Text(
            '${days > 0 ? "${days}ي " : ""}${hours}س ${minutes}د ${seconds}ث',
            style: const TextStyle(
              color: Colors.deepOrange,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _ShimmerBox extends StatelessWidget {
  final double height;

  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.leaderboard_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
