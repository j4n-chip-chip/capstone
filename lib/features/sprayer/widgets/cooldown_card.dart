import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class CooldownCard extends StatelessWidget {
  const CooldownCard({super.key, required this.remainingSec});

  final int remainingSec;

  String get formattedTime {
    final minutes = remainingSec ~/ 60;
    final seconds = remainingSec % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.timer_outlined,
              color: AppColors.warning,
              size: 32,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cooldown Active',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Sprayer temporarily locked to prevent over-spraying.',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            ),

            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
