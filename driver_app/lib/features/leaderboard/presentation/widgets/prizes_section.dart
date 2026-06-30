import 'package:flutter/material.dart';
import '../../domain/entities/competition_settings_entity.dart';

class PrizesSection extends StatelessWidget {
  final List<PrizeConfig> prizes;
  const PrizesSection({super.key, required this.prizes});

  Color _medalColor(int rank) {
    if (rank == 1) return const Color(0xFFf9a825);
    if (rank == 2) return Colors.grey;
    return const Color(0xFFa1480b);
  }

  String _rankLabel(int rank) => rank == 1 ? 'المركز الأول' : rank == 2 ? 'المركز الثاني' : 'المركز الثالث';
  String _medalEmoji(int rank) => rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';

  @override
  Widget build(BuildContext context) {
    final topPrizes = prizes.where((p) => p.rank <= 3).toList()..sort((a, b) => a.rank.compareTo(b.rank));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('الجوائز', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: topPrizes.map((prize) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _medalColor(prize.rank).withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: _medalColor(prize.rank).withOpacity(0.15), blurRadius: 6)],
                ),
                child: Column(children: [
                  Text(_medalEmoji(prize.rank), style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(_rankLabel(prize.rank), style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('${prize.cash.toStringAsFixed(0)} ب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _medalColor(prize.rank))),
                  if (prize.freeDays > 0) Text('+${prize.freeDays} يوم', style: const TextStyle(fontSize: 11, color: Colors.green)),
                ]),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
