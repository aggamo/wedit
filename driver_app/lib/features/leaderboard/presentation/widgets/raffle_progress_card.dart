import 'package:flutter/material.dart';
import '../../domain/entities/my_rank_entity.dart';
import '../../domain/entities/competition_settings_entity.dart';

class RaffleProgressCard extends StatelessWidget {
  final MyRankEntity myRank;
  final CompetitionSettingsEntity settings;
  const RaffleProgressCard({super.key, required this.myRank, required this.settings});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تفاصيل شروط السحب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ProgressRow(label: 'الرحلات', current: myRank.ridesForRaffle, required: myRank.ridesRequiredForRaffle),
            if (myRank.referralsRequiredForRaffle > 0) ...[
              const SizedBox(height: 12),
              _ProgressRow(label: 'الإحالات', current: myRank.referralsForRaffle, required: myRank.referralsRequiredForRaffle),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  settings.raffleConditions['logic'] == 'OR' ? 'يكفي تحقيق شرط واحد للتأهل' : 'جميع الشروط مطلوبة',
                  style: const TextStyle(fontSize: 13, color: Colors.blue),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: myRank.isRaffleEligible ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: myRank.isRaffleEligible ? Colors.green.shade300 : Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [Text('🎰', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('سحب إضافي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
              if (myRank.isRaffleEligible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(12)),
                  child: const Text('مؤهل ✓', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('الرحلات: ${myRank.ridesForRaffle}/${myRank.ridesRequiredForRaffle}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: myRank.ridesRequiredForRaffle > 0 ? (myRank.ridesForRaffle / myRank.ridesRequiredForRaffle).clamp(0.0, 1.0) : 0,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(myRank.isRaffleEligible ? Colors.green : Colors.blue),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text('الجائزة: ${settings.rafflePrizeCash.toStringAsFixed(0)} ب${settings.rafflePrizeDays > 0 ? " + ${settings.rafflePrizeDays} أيام" : ""}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
          TextButton(onPressed: () => _showDetails(context), child: const Text('كم تبقى لي؟')),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int current, required;
  const _ProgressRow({required this.label, required this.current, required this.required});
  @override
  Widget build(BuildContext context) {
    final progress = required > 0 ? (current / required).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(fontSize: 14)), Text('$current/$required', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))],
      ),
      const SizedBox(height: 4),
      LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? Colors.green : Colors.blue), borderRadius: BorderRadius.circular(4), minHeight: 8),
    ]);
  }
}
