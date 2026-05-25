import 'package:flutter/material.dart';
import '../../domain/entities/my_rank_entity.dart';
import '../../domain/entities/competition_settings_entity.dart';

class MyRankCard extends StatelessWidget {
  final MyRankEntity myRank;
  final CompetitionSettingsEntity settings;

  const MyRankCard({super.key, required this.myRank, required this.settings});

  LinearGradient _getGradient() {
    if (myRank.rank == 1) return const LinearGradient(colors: [Color(0xFFf9a825), Color(0xFFf57f17)]);
    if (myRank.rank <= 3) return const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]);
    return const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF263238)]);
  }

  String _rankDisplay() {
    if (myRank.rank == 1) return '🥇';
    if (myRank.rank == 2) return '🥈';
    if (myRank.rank == 3) return '🥉';
    return '#${myRank.rank}';
  }

  @override
  Widget build(BuildContext context) {
    final prize = settings.prizes.where((p) => p.rank == 1).firstOrNull;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('مركزك الحالي', style: TextStyle(color: Colors.white70, fontSize: 13)),
              if (myRank.isRaffleEligible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('مؤهل للسحب', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                myRank.rank == 0 ? 'غير مصنّف' : _rankDisplay(),
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
              ),
              if (myRank.rank > 0) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('من ${myRank.totalDrivers} سائقاً', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ],
            ],
          ),
          if (myRank.rank > 1)
            Text('ينقصك ${myRank.gapToFirst} رحلة للمركز الأول 🏆', style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (myRank.rank == 1)
            const Text('أنت في المركز الأول! 🎉', style: TextStyle(color: Colors.white, fontSize: 14)),
          if (prize != null) ...[
            const SizedBox(height: 8),
            Text(
              'جائزة المركز الأول: ${prize.cash.toStringAsFixed(0)} ب${prize.freeDays > 0 ? " + ${prize.freeDays} أيام مجانية" : ""}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
          if (settings.raffleEnabled && myRank.ridesRequiredForRaffle > 0) ...[
            const SizedBox(height: 12),
            const Text('التقدم نحو السحب:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (myRank.ridesForRaffle / myRank.ridesRequiredForRaffle).clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(myRank.isRaffleEligible ? Colors.green.shade400 : Colors.white),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${myRank.ridesForRaffle}/${myRank.ridesRequiredForRaffle} رحلة', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
