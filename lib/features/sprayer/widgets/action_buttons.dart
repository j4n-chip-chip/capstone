import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ActionButtons extends StatelessWidget {
  const ActionButtons({
    super.key,
    required this.isSpraying,
    required this.isEmergencyStop,
    required this.cooldownActive,
    required this.onManualSpray,
    required this.onTestSprayer,
    required this.onResetSystem,
  });

  final bool isSpraying;
  final bool isEmergencyStop;

  final bool cooldownActive;

  final VoidCallback? onManualSpray;
  final VoidCallback? onTestSprayer;

  final VoidCallback? onResetSystem;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isEmergencyStop) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger),
            ),
            child: const Text(
              'Emergency stop active. Reset system before spraying.',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: onResetSystem,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset System'),
          ),

          const SizedBox(height: 12),
        ],

        ElevatedButton.icon(
          onPressed: (isSpraying || isEmergencyStop) ? null : onTestSprayer,

          icon: const Icon(Icons.science_outlined),
          label: const Text('Test Sprayer'),
        ),

        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: onManualSpray,
          icon: const Icon(Icons.water_drop),
          label: const Text('Manual Start Sprayer'),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
