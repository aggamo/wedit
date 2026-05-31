import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class SurgeToggleCard extends ConsumerWidget {
  const SurgeToggleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surgeEnabled = ref.watch(surgeModeProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: surgeEnabled
            ? Colors.orange.shade50
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: surgeEnabled ? Colors.orange.shade300 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            '🔥',
            style: TextStyle(
              fontSize: surgeEnabled ? 22 : 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضع الذروة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: surgeEnabled
                        ? Colors.orange.shade800
                        : Colors.grey.shade700,
                  ),
                ),
                Text(
                  surgeEnabled
                      ? 'أسعارك مضاعفة — الركاب يرون ذلك'
                      : 'اضغط لتطبيق سعر الذروة على عروضك',
                  style: TextStyle(
                    fontSize: 11,
                    color: surgeEnabled
                        ? Colors.orange.shade600
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: surgeEnabled,
            activeColor: Colors.orange,
            onChanged: (val) async {
              ref.read(surgeModeProvider.notifier).state = val;
              await ref.read(rideNotifierProvider.notifier).toggleSurge(val);
            },
          ),
        ],
      ),
    );
  }
}
