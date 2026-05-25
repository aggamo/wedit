import 'package:flutter/material.dart';
import '../../domain/entities/leaderboard_entry_entity.dart';

class LeaderboardListItem extends StatelessWidget {
  final LeaderboardEntryEntity entry;
  const LeaderboardListItem({super.key, required this.entry});

  Widget _rankBadge() {
    if (entry.rank == 1) return const Text('🥇', style: TextStyle(fontSize: 24));
    if (entry.rank == 2) return const Text('🥈', style: TextStyle(fontSize: 24));
    if (entry.rank == 3) return const Text('🥉', style: TextStyle(fontSize: 24));
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(18)),
      alignment: Alignment.center,
      child: Text('${entry.rank}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: entry.isCurrentDriver ? theme.colorScheme.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isCurrentDriver ? theme.colorScheme.primary : Colors.grey.shade200,
          width: entry.isCurrentDriver ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 40, child: Center(child: _rankBadge())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(entry.maskedName, style: TextStyle(fontWeight: entry.isCurrentDriver ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
                    if (entry.isCurrentDriver) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                        child: const Text('أنت', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text('★ ${entry.avgRating.toStringAsFixed(1)}', style: TextStyle(color: Colors.amber.shade700, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${entry.ridesCount} رحلة', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(entry.maskedPlate, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace')),
                if (entry.cashPrize > 0) ...[
                  const SizedBox(height: 2),
                  Text('${entry.cashPrize.toStringAsFixed(0)} ب', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
