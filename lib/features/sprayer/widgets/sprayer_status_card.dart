import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'info_row.dart';

class SprayerStatusCard extends StatelessWidget {
  const SprayerStatusCard({
    super.key,
    required this.statusText,
    required this.statusColor,
    required this.isSpraying,
    required this.currentCycle,
    required this.totalCycles,
    required this.remainingSec,
    required this.triggerType,
    required this.latestMessage,
  });

  final String statusText;
  final Color statusColor;
  final bool isSpraying;
  final int currentCycle;
  final int totalCycles;
  final int remainingSec;
  final String triggerType;
  final String latestMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              child: Icon(
                isSpraying ? Icons.water_drop : Icons.water_drop_outlined,
                size: 44,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              latestMessage,
              style: const TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: isSpraying && totalCycles > 0
                  ? (currentCycle / totalCycles).clamp(0.0, 1.0)
                  : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
              backgroundColor: AppColors.background,
              color: statusColor,
            ),
            const SizedBox(height: 16),
            InfoRow('Trigger', triggerType),
            InfoRow(
              'Cycle',
              totalCycles > 0 ? '$currentCycle of $totalCycles' : 'None',
            ),

            InfoRow(
              'Remaining Time',
              remainingSec > 0 ? '$remainingSec seconds' : '0 seconds',
            ),
          ],
        ),
      ),
    );
  }
}