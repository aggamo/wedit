import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardHomeWidget extends ConsumerWidget {
  const LeaderboardHomeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRankAsync = ref.watch(myRankProvider('weekly'));

    return GestureDetector(
      onTap: () => context.push('/home/leaderboard'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: myRankAsync.when(
          loading: () => const SizedBox(
            height: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('جاري التحميل...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          error: (_, __) => const Text('الترتيب غير متاح', style: TextStyle(fontSize: 12, color: Colors.grey)),
          data: (myRank) {
            if (myRank.rank == 0) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('غير مصنّف بعد', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.shade400),
                ],
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'مركزك: #${myRank.rank}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (myRank.gapToFirst > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '← ينقصك ${myRank.gapToFirst} رحلة',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  const Text('🎉 المركز الأول!', style: TextStyle(fontSize: 11, color: Colors.amber)),
                ],
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.shade400),
              ],
            );
          },
        ),
      ),
    );
  }
}
