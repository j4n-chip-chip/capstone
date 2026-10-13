import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'slider_block.dart';

class SpraySettingsCard extends StatelessWidget {
  const SpraySettingsCard({
    super.key,
    required this.cycles,
    required this.durationSec,
    required this.isLocked,
    required this.onCyclesChanged,
    required this.onDurationChanged,
  });

  final int cycles;
  final int durationSec;
  final bool isLocked;
  final ValueChanged<int> onCyclesChanged;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spray Duration & Cycle Control',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            SliderBlock(
              label: 'Spray Cycles',
              valueLabel: '$cycles cycle(s)',
              value: cycles.toDouble(),
              min: 1,
              max: 2,
              divisions: 1,
              onChanged: isLocked
                  ? null
                  : (value) => onCyclesChanged(value.round()),
            ),
            SliderBlock(
              label: 'Duration per Cycle',
              valueLabel: '$durationSec seconds',
              value: durationSec.toDouble(),
              min: 30,
              max: 60,
              divisions: 3,
              onChanged: isLocked
                  ? null
                  : (value) => onDurationChanged(value.round()),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manual settings are locked while spraying. Auto-spray values are calculated from Black Sigatoka risk level.',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}