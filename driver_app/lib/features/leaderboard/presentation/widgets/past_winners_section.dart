import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/winner_entity.dart';

class PastWinnersSection extends StatelessWidget {
  final List<WinnerEntity> winners;

  const PastWinnersSection({super.key, required this.winners});

  @override
  Widget build(BuildContext context) {
    if (winners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.history, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              const Text(
                'الفائزون السابقون',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: winners.take(4).length,
          itemBuilder: (context, index) {
            final winner = winners[index];
            return _WinnerCard(winner: winner);
          },
        ),
      ],
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final WinnerEntity winner;

  const _WinnerCard({required this.winner});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: winner.isRaffle
                    ? Colors.purple.shade50
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  winner.isRaffle ? '🎰' : '🏆',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    winner.periodLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    winner.maskedName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: winner.isRaffle
                              ? Colors.purple.shade50
                              : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          winner.isRaffle ? 'سحب' : 'مركز ${winner.rank}',
                          style: TextStyle(
                            fontSize: 10,
                            color: winner.isRaffle
                                ? Colors.purple.shade700
                                : Colors.amber.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Prize
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${winner.cashPrize.toStringAsFixed(0)} ب',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.onlineColor,
                  ),
                ),
                if (winner.freeDays > 0)
                  Text(
                    '+ ${winner.freeDays} أيام',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
