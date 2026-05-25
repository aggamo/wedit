import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_provider.dart';
import '../../../../core/services/supabase_admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/data_table_widget.dart';

final _adminSvcProvider = Provider<SupabaseAdminService>((ref) {
  return SupabaseAdminService(ref.watch(supabaseClientProvider));
});

final competitionSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final result = await ref.watch(_adminSvcProvider).getCompetitionSettings();
  return result ??
      {
        // Default settings
        'weekly_prize_1_cash': 500,
        'weekly_prize_1_free_days': 3,
        'weekly_prize_2_cash': 300,
        'weekly_prize_2_free_days': 2,
        'weekly_prize_3_cash': 150,
        'weekly_prize_3_free_days': 1,
        'monthly_prize_1_cash': 2000,
        'monthly_prize_1_free_days': 14,
        'monthly_prize_2_cash': 1200,
        'monthly_prize_2_free_days': 7,
        'monthly_prize_3_cash': 600,
        'monthly_prize_3_free_days': 3,
        'raffle_enabled': true,
        'raffle_rides_required': 30,
        'raffle_passenger_referrals': 0,
        'raffle_driver_referrals': 0,
        'raffle_logic': 'OR',
        'raffle_prize_cash': 1000,
        'raffle_prize_free_days': 7,
        'raffle_winners_count': 1,
        'ranking_criteria': 'rides_count',
        'week_start_day': 'monday',
        'plate_visible_digits': 2,
      };
});

final _leaderboardPeriodProvider = StateProvider<String>((ref) => 'weekly');

final leaderboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final period = ref.watch(_leaderboardPeriodProvider);
  return ref.watch(_adminSvcProvider).getLeaderboard(period);
});

final competitionWinnersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(_adminSvcProvider).getCompetitionWinners();
});

// Countdown timer provider
final _countdownProvider = StreamProvider<Duration>((ref) {
  final period = ref.watch(_leaderboardPeriodProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) {
    final now = DateTime.now();
    if (period == 'weekly') {
      // Calculate time until next Monday midnight
      final daysUntilMonday = (8 - now.weekday) % 7;
      final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday);
      return nextMonday.difference(now);
    } else {
      // Monthly: end of current month
      final nextMonth =
          DateTime(now.year, now.month + 1, 1);
      return nextMonth.difference(now);
    }
  });
});

class CompetitionsPage extends ConsumerWidget {
  const CompetitionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: AppColors.tertiary, size: 28),
              const SizedBox(width: 10),
              Text(
                'إدارة المسابقات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section A: Leaderboard Preview
          _SectionA_Leaderboard(),
          const SizedBox(height: 24),

          // Section B + C side by side on wide screens
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _SectionB_PrizeSettings()),
                      const SizedBox(width: 16),
                      Expanded(child: _SectionC_RaffleSettings()),
                    ],
                  )
                : Column(
                    children: [
                      _SectionB_PrizeSettings(),
                      const SizedBox(height: 16),
                      _SectionC_RaffleSettings(),
                    ],
                  );
          }),
          const SizedBox(height: 24),

          // Section D + E side by side
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _SectionD_RankingCriteria()),
                      const SizedBox(width: 16),
                      Expanded(child: _SectionE_PrivacySettings()),
                    ],
                  )
                : Column(
                    children: [
                      _SectionD_RankingCriteria(),
                      const SizedBox(height: 16),
                      _SectionE_PrivacySettings(),
                    ],
                  );
          }),
          const SizedBox(height: 24),

          // Section F: Winners History
          _SectionF_WinnersHistory(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── SECTION A: Leaderboard Preview ───────────────────────────────────────────
class _SectionA_Leaderboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_leaderboardPeriodProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final countdownAsync = ref.watch(_countdownProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'معاينة المتصدرين',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                // Countdown
                countdownAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (remaining) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(remaining),
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Period tabs
            Row(
              children: [
                _PeriodTab(
                  label: 'أسبوعي',
                  isSelected: period == 'weekly',
                  onTap: () => ref
                      .read(_leaderboardPeriodProvider.notifier)
                      .state = 'weekly',
                ),
                const SizedBox(width: 8),
                _PeriodTab(
                  label: 'شهري',
                  isSelected: period == 'monthly',
                  onTap: () => ref
                      .read(_leaderboardPeriodProvider.notifier)
                      .state = 'monthly',
                ),
                const Spacer(),
                // Driver view toggle info
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 14, color: AppColors.info),
                      SizedBox(width: 4),
                      Text('معاينة كما يراها السائق',
                          style: TextStyle(
                              color: AppColors.info, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Leaderboard
            leaderboardAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                  child: Text('تعذر تحميل المتصدرين')),
              data: (entries) => entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('لا توجد بيانات للمتصدرين'),
                      ),
                    )
                  : _LeaderboardTable(entries: entries),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (days > 0) return '$days يوم $hours:$minutes:$seconds';
    return '$hours:$minutes:$seconds';
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTable extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _LeaderboardTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(entries.length, (i) {
        final entry = entries[i];
        final rank = (entry['rank'] as num?)?.toInt() ?? (i + 1);
        final driver = entry['driver'] as Map? ?? {};
        final name = _maskName(driver['full_name'] as String? ?? '—');
        final plate =
            _maskPlate(driver['vehicle_plate_number'] as String? ?? '—', 2);
        final score = entry['score'] ?? entry['rides_count'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: rank <= 3
                ? _rankColor(rank).withOpacity(0.06)
                : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: rank <= 3
                  ? _rankColor(rank).withOpacity(0.2)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              // Rank badge
              SizedBox(
                width: 40,
                child: rank <= 3
                    ? Text(
                        _rankEmoji(rank),
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                      )
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: _rankColor(rank).withOpacity(0.15),
                child: Text(
                  name.isNotEmpty ? name[0] : '؟',
                  style: TextStyle(
                      color: _rankColor(rank),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),

              // Name + plate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'لوحة: $plate',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Score
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _rankColor(rank).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score رحلة',
                  style: TextStyle(
                    color: _rankColor(rank),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _maskName(String name) {
    if (name.length <= 2) return name;
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0]} ${parts[1].replaceAll(RegExp(r'.'), '*')}';
    }
    return '${name.substring(0, 2)}${'*' * (name.length - 2)}';
  }

  String _maskPlate(String plate, int visibleDigits) {
    if (plate.length <= visibleDigits) return plate;
    final visible = plate.substring(plate.length - visibleDigits);
    final masked = '*' * (plate.length - visibleDigits);
    return '$masked$visible';
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.primary;
    }
  }

  String _rankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }
}

// ─── SECTION B: Prize Settings ────────────────────────────────────────────────
class _SectionB_PrizeSettings extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SectionB_PrizeSettings> createState() =>
      _SectionB_PrizeSettingsState();
}

class _SectionB_PrizeSettingsState
    extends ConsumerState<_SectionB_PrizeSettings> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key, Map<String, dynamic> settings) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(
          text: '${settings[key] ?? 0}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(competitionSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.military_tech, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Text(
                  'إعدادات الجوائز',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            settingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (settings) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekly prizes
                  _PrizeSection(
                    title: 'جوائز أسبوعية',
                    icon: Icons.calendar_view_week,
                    color: AppColors.primary,
                    prizes: [
                      _PrizeRow(
                        rank: 1,
                        cashCtrl: _ctrl('weekly_prize_1_cash', settings),
                        freeDaysCtrl:
                            _ctrl('weekly_prize_1_free_days', settings),
                      ),
                      _PrizeRow(
                        rank: 2,
                        cashCtrl: _ctrl('weekly_prize_2_cash', settings),
                        freeDaysCtrl:
                            _ctrl('weekly_prize_2_free_days', settings),
                      ),
                      _PrizeRow(
                        rank: 3,
                        cashCtrl: _ctrl('weekly_prize_3_cash', settings),
                        freeDaysCtrl:
                            _ctrl('weekly_prize_3_free_days', settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Monthly prizes
                  _PrizeSection(
                    title: 'جوائز شهرية',
                    icon: Icons.calendar_month,
                    color: AppColors.secondary,
                    prizes: [
                      _PrizeRow(
                        rank: 1,
                        cashCtrl:
                            _ctrl('monthly_prize_1_cash', settings),
                        freeDaysCtrl:
                            _ctrl('monthly_prize_1_free_days', settings),
                      ),
                      _PrizeRow(
                        rank: 2,
                        cashCtrl:
                            _ctrl('monthly_prize_2_cash', settings),
                        freeDaysCtrl:
                            _ctrl('monthly_prize_2_free_days', settings),
                      ),
                      _PrizeRow(
                        rank: 3,
                        cashCtrl:
                            _ctrl('monthly_prize_3_cash', settings),
                        freeDaysCtrl:
                            _ctrl('monthly_prize_3_free_days', settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _savePrizes(settings),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              _saved ? Icons.check : Icons.save,
                              size: 18,
                            ),
                      label: Text(_saved ? 'تم الحفظ ✓' : 'حفظ الجوائز'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saved
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePrizes(Map<String, dynamic> current) async {
    setState(() => _saving = true);
    try {
      final service = ref.read(_adminSvcProvider);
      final updated = Map<String, dynamic>.from(current);
      _controllers.forEach((key, ctrl) {
        updated[key] = int.tryParse(ctrl.text) ?? 0;
      });
      await service.upsertCompetitionSettings(updated);
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
      ref.refresh(competitionSettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PrizeSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_PrizeRow> prizes;

  const _PrizeSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.prizes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Header
        Row(
          children: [
            const SizedBox(width: 80),
            Expanded(
              child: Text('المبلغ (ETB)',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('أيام مجانية',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...prizes,
      ],
    );
  }
}

class _PrizeRow extends StatelessWidget {
  final int rank;
  final TextEditingController cashCtrl;
  final TextEditingController freeDaysCtrl;

  const _PrizeRow({
    required this.rank,
    required this.cashCtrl,
    required this.freeDaysCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = switch (rank) {
      1 => ('🥇', const Color(0xFFFFD700)),
      2 => ('🥈', const Color(0xFFC0C0C0)),
      3 => ('🥉', const Color(0xFFCD7F32)),
      _ => ('$rank', AppColors.textSecondary),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(
                  'المركز $rank',
                  style: TextStyle(
                      fontSize: 12,
                      color: color == AppColors.textSecondary
                          ? color
                          : AppColors.textPrimary),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                suffixText: 'ETB',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: freeDaysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                suffixText: 'يوم',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION C: Raffle Settings ───────────────────────────────────────────────
class _SectionC_RaffleSettings extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SectionC_RaffleSettings> createState() =>
      _SectionC_RaffleSettingsState();
}

class _SectionC_RaffleSettingsState
    extends ConsumerState<_SectionC_RaffleSettings> {
  bool? _raffleEnabled;
  final _ridesCtrl = TextEditingController();
  final _passengerRefCtrl = TextEditingController();
  final _driverRefCtrl = TextEditingController();
  String? _raffleLogic;
  final _prizeCashCtrl = TextEditingController();
  final _prizeFreeDaysCtrl = TextEditingController();
  final _winnersCountCtrl = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  bool _initialized = false;

  @override
  void dispose() {
    _ridesCtrl.dispose();
    _passengerRefCtrl.dispose();
    _driverRefCtrl.dispose();
    _prizeCashCtrl.dispose();
    _prizeFreeDaysCtrl.dispose();
    _winnersCountCtrl.dispose();
    super.dispose();
  }

  void _init(Map<String, dynamic> settings) {
    if (_initialized) return;
    _initialized = true;
    _raffleEnabled = settings['raffle_enabled'] as bool? ?? true;
    _ridesCtrl.text = '${settings['raffle_rides_required'] ?? 30}';
    _passengerRefCtrl.text =
        '${settings['raffle_passenger_referrals'] ?? 0}';
    _driverRefCtrl.text =
        '${settings['raffle_driver_referrals'] ?? 0}';
    _raffleLogic = settings['raffle_logic'] as String? ?? 'OR';
    _prizeCashCtrl.text = '${settings['raffle_prize_cash'] ?? 1000}';
    _prizeFreeDaysCtrl.text =
        '${settings['raffle_prize_free_days'] ?? 7}';
    _winnersCountCtrl.text =
        '${settings['raffle_winners_count'] ?? 1}';
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(competitionSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.casino, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  'إعدادات السحب بالقرعة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            settingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (settings) {
                _init(settings);
                return StatefulBuilder(
                  builder: (context, setLocal) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enable toggle
                      SwitchListTile(
                        value: _raffleEnabled ?? true,
                        onChanged: (v) =>
                            setLocal(() => _raffleEnabled = v),
                        title: const Text(
                          'تفعيل السحب بالقرعة',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                            'سيتم إجراء السحب تلقائياً في نهاية كل فترة'),
                        activeColor: AppColors.secondary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 24),

                      if (_raffleEnabled == true) ...[
                        // Criteria section
                        const Text(
                          'شروط المشاركة في السحب',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 12),

                        _LabeledField(
                          label: 'عدد الرحلات المطلوبة',
                          controller: _ridesCtrl,
                          suffix: 'رحلة',
                          icon: Icons.directions_car,
                        ),
                        const SizedBox(height: 10),
                        _LabeledField(
                          label: 'إحالات ركاب مطلوبة',
                          controller: _passengerRefCtrl,
                          suffix: 'إحالة',
                          icon: Icons.person_add,
                        ),
                        const SizedBox(height: 10),
                        _LabeledField(
                          label: 'إحالات سائقين مطلوبة',
                          controller: _driverRefCtrl,
                          suffix: 'إحالة',
                          icon: Icons.drive_eta,
                        ),
                        const SizedBox(height: 16),

                        // Logic selector
                        const Text(
                          'منطق الشروط',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            RadioListTile<String>(
                              value: 'OR',
                              groupValue: _raffleLogic,
                              onChanged: (v) =>
                                  setLocal(() => _raffleLogic = v),
                              title: const Text('يكفي شرط واحد (OR)'),
                              subtitle: const Text(
                                  'السائق مؤهل إذا استوفى أي شرط'),
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            RadioListTile<String>(
                              value: 'AND',
                              groupValue: _raffleLogic,
                              onChanged: (v) =>
                                  setLocal(() => _raffleLogic = v),
                              title: const Text('جميع الشروط مطلوبة (AND)'),
                              subtitle: const Text(
                                  'السائق مؤهل فقط إذا استوفى كل الشروط'),
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Prize settings
                        const Text(
                          'جائزة السحب',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledField(
                                label: 'المبلغ النقدي',
                                controller: _prizeCashCtrl,
                                suffix: 'ETB',
                                icon: Icons.attach_money,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LabeledField(
                                label: 'أيام مجانية',
                                controller: _prizeFreeDaysCtrl,
                                suffix: 'يوم',
                                icon: Icons.calendar_today,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _LabeledField(
                          label: 'عدد الفائزين',
                          controller: _winnersCountCtrl,
                          suffix: 'فائز',
                          icon: Icons.people,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _save(settings),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Icon(
                                  _saved ? Icons.check : Icons.save,
                                  size: 18),
                          label: Text(
                              _saved ? 'تم الحفظ ✓' : 'حفظ إعدادات السحب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _saved
                                ? AppColors.success
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(Map<String, dynamic> current) async {
    setState(() => _saving = true);
    try {
      final service = ref.read(_adminSvcProvider);
      final updated = Map<String, dynamic>.from(current);
      updated['raffle_enabled'] = _raffleEnabled;
      updated['raffle_rides_required'] =
          int.tryParse(_ridesCtrl.text) ?? 30;
      updated['raffle_passenger_referrals'] =
          int.tryParse(_passengerRefCtrl.text) ?? 0;
      updated['raffle_driver_referrals'] =
          int.tryParse(_driverRefCtrl.text) ?? 0;
      updated['raffle_logic'] = _raffleLogic;
      updated['raffle_prize_cash'] =
          int.tryParse(_prizeCashCtrl.text) ?? 1000;
      updated['raffle_prize_free_days'] =
          int.tryParse(_prizeFreeDaysCtrl.text) ?? 7;
      updated['raffle_winners_count'] =
          int.tryParse(_winnersCountCtrl.text) ?? 1;
      await service.upsertCompetitionSettings(updated);
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
      ref.refresh(competitionSettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffix;
  final IconData? icon;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.suffix,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        isDense: true,
      ),
    );
  }
}

// ─── SECTION D: Ranking Criteria ─────────────────────────────────────────────
class _SectionD_RankingCriteria extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SectionD_RankingCriteria> createState() =>
      _SectionD_RankingCriteriaState();
}

class _SectionD_RankingCriteriaState
    extends ConsumerState<_SectionD_RankingCriteria> {
  String? _criteria;
  String? _weekStartDay;
  bool _saving = false;
  bool _initialized = false;

  final _criteriaOptions = const [
    (
      'rides_count',
      'عدد الرحلات',
      'الترتيب حسب عدد الرحلات المكتملة',
      Icons.directions_car
    ),
    (
      'points',
      'النقاط',
      'الترتيب حسب النقاط المتراكمة',
      Icons.star
    ),
    (
      'rating',
      'التقييم',
      'الترتيب حسب متوسط تقييم الرحلات',
      Icons.thumbs_up_down
    ),
    (
      'composite',
      'مركّب',
      'مزيج من الرحلات والنقاط والتقييم',
      Icons.auto_graph
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(competitionSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sort, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'معيار الترتيب',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            settingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (settings) {
                if (!_initialized) {
                  _initialized = true;
                  _criteria =
                      settings['ranking_criteria'] as String? ??
                          'rides_count';
                  _weekStartDay =
                      settings['week_start_day'] as String? ?? 'monday';
                }
                return StatefulBuilder(
                  builder: (context, setLocal) => Column(
                    children: [
                      ..._criteriaOptions.map((opt) {
                        final isSelected = _criteria == opt.$1;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.06)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: RadioListTile<String>(
                            value: opt.$1,
                            groupValue: _criteria,
                            onChanged: (v) =>
                                setLocal(() => _criteria = v),
                            title: Row(
                              children: [
                                Icon(opt.$4,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(opt.$2,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            subtitle: Text(opt.$3,
                                style: const TextStyle(fontSize: 12)),
                            activeColor: AppColors.primary,
                            dense: true,
                          ),
                        );
                      }),

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Week start day
                      DropdownButtonFormField<String>(
                        value: _weekStartDay,
                        decoration: const InputDecoration(
                          labelText: 'يوم بداية الأسبوع',
                          prefixIcon:
                              Icon(Icons.calendar_today, size: 18),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'saturday', child: Text('السبت')),
                          DropdownMenuItem(
                              value: 'sunday', child: Text('الأحد')),
                          DropdownMenuItem(
                              value: 'monday', child: Text('الاثنين')),
                        ],
                        onChanged: (v) =>
                            setLocal(() => _weekStartDay = v),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () async {
                                  setState(() => _saving = true);
                                  try {
                                    final updated =
                                        Map<String, dynamic>.from(
                                            settings);
                                    updated['ranking_criteria'] = _criteria;
                                    updated['week_start_day'] =
                                        _weekStartDay;
                                    await ref
                                        .read(_adminSvcProvider)
                                        .upsertCompetitionSettings(updated);
                                    ref.refresh(
                                        competitionSettingsProvider);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('تم الحفظ بنجاح')));
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _saving = false);
                                  }
                                },
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save, size: 18),
                          label: const Text('حفظ معيار الترتيب'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION E: Privacy Settings ─────────────────────────────────────────────
class _SectionE_PrivacySettings extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SectionE_PrivacySettings> createState() =>
      _SectionE_PrivacySettingsState();
}

class _SectionE_PrivacySettingsState
    extends ConsumerState<_SectionE_PrivacySettings> {
  int _visibleDigits = 2;
  bool _saving = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(competitionSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.privacy_tip, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'إعدادات الخصوصية',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            settingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (settings) {
                if (!_initialized) {
                  _initialized = true;
                  _visibleDigits =
                      (settings['plate_visible_digits'] as num?)?.toInt() ??
                          2;
                }
                return StatefulBuilder(
                  builder: (context, setLocal) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'عدد أرقام اللوحة الظاهرة',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'تحديد عدد أرقام لوحة المركبة التي تظهر للسائقين في القائمة',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Slider
                      Slider(
                        value: _visibleDigits.toDouble(),
                        min: 1,
                        max: 4,
                        divisions: 3,
                        label: '$_visibleDigits أرقام',
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setLocal(() => _visibleDigits = v.toInt()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (int i = 1; i <= 4; i++)
                            Text(
                              '$i',
                              style: TextStyle(
                                fontWeight: i == _visibleDigits
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: i == _visibleDigits
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Preview section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.preview,
                                    size: 16, color: AppColors.info),
                                SizedBox(width: 6),
                                Text(
                                  'معاينة',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.info),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _PlatePreview(
                                plate: 'AA12345',
                                visibleDigits: _visibleDigits),
                            const SizedBox(height: 8),
                            _PlatePreview(
                                plate: 'ET98765',
                                visibleDigits: _visibleDigits),
                            const SizedBox(height: 8),
                            _PlatePreview(
                                plate: '3A45678',
                                visibleDigits: _visibleDigits),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () async {
                                  setState(() => _saving = true);
                                  try {
                                    final updated =
                                        Map<String, dynamic>.from(
                                            settings);
                                    updated['plate_visible_digits'] =
                                        _visibleDigits;
                                    await ref
                                        .read(_adminSvcProvider)
                                        .upsertCompetitionSettings(updated);
                                    ref.refresh(
                                        competitionSettingsProvider);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('تم الحفظ بنجاح')));
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _saving = false);
                                  }
                                },
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save, size: 18),
                          label: const Text('حفظ إعدادات الخصوصية'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatePreview extends StatelessWidget {
  final String plate;
  final int visibleDigits;

  const _PlatePreview({required this.plate, required this.visibleDigits});

  @override
  Widget build(BuildContext context) {
    final masked = _maskPlate(plate, visibleDigits);
    return Row(
      children: [
        Text(
          'الأصلي: ',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            plate,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_forward, size: 16),
        const SizedBox(width: 16),
        Text(
          'المُقنَّع: ',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            masked,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _maskPlate(String plate, int visibleDigits) {
    if (plate.length <= visibleDigits) return plate;
    final visible = plate.substring(plate.length - visibleDigits);
    final masked = '*' * (plate.length - visibleDigits);
    return '$masked$visible';
  }
}

// ─── SECTION F: Winners History ────────────────────────────────────────────────
class _SectionF_WinnersHistory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final winnersAsync = ref.watch(competitionWinnersProvider);
    final dateFormat = DateFormat('yyyy/MM/dd');
    final currency = NumberFormat.currency(locale: 'am_ET', symbol: 'ETB ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'سجل الفائزين',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                // Emergency raffle button
                ElevatedButton.icon(
                  onPressed: () => _runRaffleManually(context, ref),
                  icon: const Icon(Icons.casino, size: 18),
                  label: const Text('تشغيل السحب يدوياً'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            winnersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (winners) => winners.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.history,
                                size: 48,
                                color: AppColors.textSecondary),
                            SizedBox(height: 12),
                            Text('لا يوجد فائزون بعد',
                                style: TextStyle(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 350,
                      child: DataTable2(
                        columnSpacing: 12,
                        horizontalMargin: 16,
                        headingRowHeight: 48,
                        dataRowHeight: 56,
                        border: TableBorder(
                          horizontalInside:
                              BorderSide(color: Colors.grey.shade100),
                        ),
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.primary.withOpacity(0.04),
                        ),
                        columns: const [
                          DataColumn2(
                              label: Text('الفترة'), size: ColumnSize.M),
                          DataColumn2(
                              label: Text('الفائز'), size: ColumnSize.L),
                          DataColumn2(
                              label: Text('نوع الفوز'),
                              size: ColumnSize.M),
                          DataColumn2(
                              label: Text('الجائزة'),
                              size: ColumnSize.M,
                              numeric: true),
                          DataColumn2(
                              label: Text('حالة الدفع'),
                              size: ColumnSize.S),
                          DataColumn2(
                              label: Text('إجراء'), size: ColumnSize.M),
                        ],
                        rows: winners.map((winner) {
                          final driver = winner['driver'] as Map? ?? {};
                          final isPaid = winner['prize_paid'] as bool? ?? false;
                          final cashAmount = (winner['cash_prize'] ?? 0) as num;
                          final freeDays = (winner['free_days'] ?? 0) as num;
                          final winType =
                              winner['win_type'] as String? ?? 'rank';
                          final period = winner['period_label'] as String? ??
                              (winner['created_at'] != null
                                  ? dateFormat.format(
                                      DateTime.parse(winner['created_at']))
                                  : '—');

                          return DataRow2(
                            cells: [
                              DataCell(Text(period)),
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.tertiary
                                          .withOpacity(0.15),
                                      child: const Icon(Icons.person,
                                          size: 16,
                                          color: AppColors.tertiary),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      driver['full_name'] as String? ?? '—',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: winType == 'rank'
                                        ? AppColors.tertiary.withOpacity(0.1)
                                        : AppColors.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    winType == 'rank'
                                        ? 'مركز'
                                        : 'قرعة',
                                    style: TextStyle(
                                      color: winType == 'rank'
                                          ? AppColors.tertiary
                                          : AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (cashAmount > 0)
                                      Text(
                                        currency.format(cashAmount),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                    if (freeDays > 0)
                                      Text(
                                        '$freeDays يوم مجاني',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                isPaid
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: AppColors.success,
                                              size: 16),
                                          SizedBox(width: 4),
                                          Text('مدفوع',
                                              style: TextStyle(
                                                  color: AppColors.success,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.pending,
                                              color: AppColors.warning,
                                              size: 16),
                                          SizedBox(width: 4),
                                          Text('معلق',
                                              style: TextStyle(
                                                  color: AppColors.warning,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ],
                                      ),
                              ),
                              DataCell(
                                isPaid
                                    ? const SizedBox.shrink()
                                    : TextButton(
                                        onPressed: () => _confirmPayment(
                                            context, ref, winner),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.success,
                                        ),
                                        child:
                                            const Text('تأكيد الدفع'),
                                      ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPayment(
      BuildContext context, WidgetRef ref, Map<String, dynamic> winner) {
    final driver = winner['driver'] as Map? ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد دفع الجائزة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الفائز: ${driver['full_name'] ?? '—'}'),
            const SizedBox(height: 8),
            Text(
              'الجائزة: ${winner['cash_prize'] ?? 0} ETB + ${winner['free_days'] ?? 0} يوم مجاني',
            ),
            const SizedBox(height: 8),
            const Text(
              'هل تأكد من دفع الجائزة للسائق؟',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(_adminSvcProvider);
              await service.markPrizePaid(winner['id'] as String);
              ref.refresh(competitionWinnersProvider);
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('تأكيد الدفع'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
          ),
        ],
      ),
    );
  }

  void _runRaffleManually(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning),
            SizedBox(width: 8),
            Text('تشغيل السحب يدوياً'),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من تشغيل السحب بالقرعة الآن؟\n'
          'سيتم اختيار الفائزين وإرسال إشعارات لهم.\n\n'
          'هذه العملية لا يمكن التراجع عنها.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(_adminSvcProvider).runRaffleManually();
                ref.refresh(competitionWinnersProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تشغيل السحب بنجاح!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.casino, size: 16),
            label: const Text('تشغيل الآن'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
          ),
        ],
      ),
    );
  }
}
